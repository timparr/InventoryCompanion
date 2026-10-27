[CmdletBinding()]
param(
    [ValidateSet("Stage", "Finalize", "Cancel")]
    [string]$Action = "Stage",
    [string]$OutputDirectory = "Project\Publishing\Packages",
    [string]$TestResults,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$addonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
if ((Split-Path $addonRoot -Leaf) -ne "InventoryCompanion_DEV") {
    throw "Run this script from the permanent InventoryCompanion_DEV checkout."
}
$candidateRoot = Join-Path (Split-Path $addonRoot -Parent) "InventoryCompanion"
$manifestPath = Join-Path $addonRoot "InventoryCompanion_DEV.txt"
$stateDirectory = Join-Path $PSScriptRoot ".release-test"
$statePath = Join-Path $stateDirectory "state.json"
$reviewPath = Join-Path $addonRoot "ReleaseReview.md"

function Assert-GameClosed {
    if (Get-Process -Name "eso", "eso64" -ErrorAction SilentlyContinue) {
        throw "Exit ESO completely before staging, finalizing, or cancelling a release test."
    }
}

function Assert-NoLinks([string]$Path) {
    $items = @((Get-Item -LiteralPath $Path -Force)) + @(Get-ChildItem -LiteralPath $Path -Force -Recurse)
    foreach ($item in $items) {
        # OneDrive placeholders are reparse points too, but do not redirect paths.
        if ($item.LinkType -in @("Junction", "SymbolicLink")) {
            throw "Release paths must not contain junctions or symbolic links: $($item.FullName)"
        }
    }
}

function Get-FileRecord([string]$Path, [string]$RelativePath) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required release file is missing: $Path"
    }
    [pscustomobject]@{
        Path = $RelativePath
        Hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

function Set-DevelopmentVersion([string]$Version) {
    $initPath = Join-Path $addonRoot "Core\Init.lua"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw
    $init = Get-Content -LiteralPath $initPath -Raw
    if ([regex]::Matches($manifest, '(?m)^## Version: .+$').Count -ne 1 -or
        [regex]::Matches($init, '(?m)^    Version = .+,\r?$').Count -ne 1) {
        throw "Cannot update development version: expected one manifest and runtime version."
    }
    try {
        Set-Content -LiteralPath $manifestPath -Value ([regex]::Replace($manifest, '(?m)^## Version: .+$', "## Version: $Version")) -NoNewline -Encoding UTF8
        Set-Content -LiteralPath $initPath -Value ([regex]::Replace($init, '(?m)^    Version = .+,\r?$', "    Version = `"$Version`",")) -NoNewline -Encoding UTF8
    } catch {
        Set-Content -LiteralPath $manifestPath -Value $manifest -NoNewline -Encoding UTF8
        Set-Content -LiteralPath $initPath -Value $init -NoNewline -Encoding UTF8
        throw
    }
    Write-Output "Development version is now $Version"
}

function Get-CandidateRecords {
    Assert-NoLinks $candidateRoot
    $prefix = $candidateRoot + [System.IO.Path]::DirectorySeparatorChar
    foreach ($file in Get-ChildItem -LiteralPath $candidateRoot -File -Recurse -Force | Sort-Object FullName) {
        Get-FileRecord $file.FullName $file.FullName.Substring($prefix.Length)
    }
}

function Read-TestState {
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        throw "No staged release test exists. Run -Action Stage first."
    }
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ($state.Schema -ne 1 -or $state.SourceRoot -ne $addonRoot -or $state.CandidateRoot -ne $candidateRoot) {
        throw "Release-test state does not belong to this checkout."
    }
    if ($Action -eq "Finalize" -and $state.Completed) {
        throw "This release test is already finalized. Cancel to remove the installed release before staging another."
    }
    if ($Action -eq "Finalize" -and -not (Test-Path -LiteralPath $candidateRoot -PathType Container)) {
        throw "The staged candidate is missing. Restore it before finalizing or cancelling."
    }
    if (Test-Path -LiteralPath $candidateRoot) {
        Assert-NoLinks $candidateRoot
    }
    return $state
}

function Remove-Candidate {
    # Retain ownership state until removal succeeds, allowing recovery after a failure.
    if (Test-Path -LiteralPath $candidateRoot) {
        Assert-NoLinks $candidateRoot
        Remove-Item -LiteralPath $candidateRoot -Recurse -Force
    }
    Remove-Item -LiteralPath $statePath
    Write-Output "Script-owned release installation removed. Development was left unchanged."
}

if ($Action -ne "Finalize") {
    Assert-GameClosed
}
if ($Action -eq "Cancel") {
    $null = Read-TestState
    Remove-Candidate
    return
}

if ($Action -eq "Stage") {
    if (Test-Path -LiteralPath $statePath) {
        throw "A release installation is already managed by this script. Cancel to remove it before staging another."
    }
    if (Test-Path -LiteralPath $candidateRoot) {
        throw "Refusing to overwrite an existing installation: $candidateRoot"
    }
} else {
    $state = Read-TestState
    if ([string]::IsNullOrWhiteSpace($TestResults)) {
        throw "Finalize requires -TestResults describing the human-run in-game tests and their results."
    }
}

if ($Action -eq "Stage") {
$sourceManifestPath = $manifestPath
if (-not (Test-Path -LiteralPath $sourceManifestPath -PathType Leaf)) {
    throw "Development manifest not found: $sourceManifestPath"
}
$manifestLines = @(Get-Content -LiteralPath $sourceManifestPath)
$versionLines = @($manifestLines | Where-Object { $_ -match '^##\s*Version:\s*(.+?)\s*$' })
if ($versionLines.Count -ne 1) {
    throw "The manifest must define exactly one ## Version."
}
$version = [regex]::Match($versionLines[0], '^##\s*Version:\s*(.+?)\s*$').Groups[1].Value
if ($version -notmatch '^[A-Za-z0-9._-]+$') {
    throw "Invalid package version: $version"
}
if ($version -notmatch '^(\d+)\.(\d+)(?:\.(\d+))?$') {
    throw "Expected major.minor.build version (legacy major.minor is accepted as build zero)."
}
$nextBuildVersion = "{0}.{1}.{2}" -f [int]$Matches[1], [int]$Matches[2], (1 + [int]$Matches[3])

$manifestFiles = [System.Collections.Generic.List[string]]::new()
$seenPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$rootPrefix = $addonRoot + [System.IO.Path]::DirectorySeparatorChar
foreach ($line in $manifestLines) {
    $relativePath = $line.Trim().Replace('/', '\')
    if (-not $relativePath -or $relativePath.StartsWith("#") -or $relativePath.StartsWith("--")) {
        continue
    }
    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $addonRoot $relativePath))
    if ([System.IO.Path]::IsPathRooted($relativePath) -or -not $sourcePath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Manifest entry must stay inside the add-on folder: $relativePath"
    }
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Manifest-listed file does not exist: $relativePath"
    }
    if (-not $seenPaths.Add($sourcePath)) {
        throw "Duplicate manifest entry: $relativePath"
    }
    $manifestFiles.Add($relativePath)
}
if ($manifestFiles.Count -eq 0 -or -not $manifestFiles.Contains("Core\Development.lua")) {
    throw "The development manifest must include runtime files and Core/Development.lua."
}
$runtimeFiles = @($manifestFiles | Where-Object { $_ -ne "Core\Development.lua" })
$sourcePaths = @(
    "InventoryCompanion_DEV.txt"
    "readme.md"
    "Project\Publishing\ReleaseChecklist.md"
    "Project\Publishing\ReleaseReviewTemplate.md"
    "Project\Publishing\PackageRelease.ps1"
) + @($manifestFiles)
$sourceRecords = @(foreach ($relativePath in $sourcePaths) {
    $path = if ($relativePath -eq "InventoryCompanion_DEV.txt") { $sourceManifestPath } else { Join-Path $addonRoot $relativePath }
    Get-FileRecord $path $relativePath
})

    $releaseManifest = @($manifestLines | Where-Object {
        $_.Trim().Replace('/', '\') -ne "Core\Development.lua"
    } | ForEach-Object {
        $_ -replace '^(##\s*Title:.*?) \[DEV\]', '$1'
    })
    $null = New-Item -ItemType Directory -Path $stateDirectory -Force
    $null = New-Item -ItemType Directory -Path $candidateRoot
    try {
        Set-Content -LiteralPath (Join-Path $candidateRoot "InventoryCompanion.txt") -Value $releaseManifest -Encoding UTF8
        foreach ($relativePath in $runtimeFiles) {
            $destination = Join-Path $candidateRoot $relativePath
            $null = New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force
            Copy-Item -LiteralPath (Join-Path $addonRoot $relativePath) -Destination $destination
        }
        $state = [ordered]@{
            Schema = 1
            Completed = $false
            SourceRoot = $addonRoot
            CandidateRoot = $candidateRoot
            Version = $version
            StagedAt = [datetime]::UtcNow.ToString("o")
            Sources = $sourceRecords
            Candidate = @(Get-CandidateRecords)
        }
        $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8
        Set-DevelopmentVersion $nextBuildVersion
    } catch {
        # Do not leave an unrecorded candidate after failed staging.
        Remove-Item -LiteralPath $candidateRoot -Recurse -Force
        if (Test-Path -LiteralPath $statePath) { Remove-Item -LiteralPath $statePath }
        throw
    }
    Write-Output "Staged release $version at $candidateRoot"
    Write-Output "Development remains available. Select only InventoryCompanion in your release-test add-on profile."
    Write-Output "Both versions share saved variables; back them up before testing."
    Write-Output "After testing, exit ESO, complete ReleaseReview.md, then run -Action Finalize -TestResults '<actual results>'."
    Write-Output "To remove this installation, exit ESO and run -Action Cancel."
    return
}

$version = $state.Version
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    $candidateIdentity = (@($state.Candidate | ForEach-Object { "$($_.Path)|$($_.Hash)" } | Sort-Object) -join "`n")
    $candidateHash = [System.BitConverter]::ToString(
        $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($candidateIdentity))
    ).Replace("-", "")
} finally {
    $sha.Dispose()
}
foreach ($comparison in @(
    @{ Name = "candidate files"; Expected = @($state.Candidate); Actual = @(Get-CandidateRecords | Where-Object { $_.Path -ne "ReleaseReview.md" }) }
)) {
    $expected = @($comparison.Expected | ForEach-Object { "$($_.Path)|$($_.Hash)" } | Sort-Object)
    $actual = @($comparison.Actual | ForEach-Object { "$($_.Path)|$($_.Hash)" } | Sort-Object)
    if (@(Compare-Object $expected $actual).Count -gt 0) {
        throw "Release $($comparison.Name) changed since staging. Cancel and stage a fresh candidate for testing."
    }
}

if (-not (Test-Path -LiteralPath $reviewPath -PathType Leaf)) {
    throw "Complete ReleaseReview.md from ReleaseReviewTemplate.md before finalizing."
}
$reviewContent = Get-Content -LiteralPath $reviewPath -Raw
if ($reviewContent -notmatch "(?m)^Candidate SHA256: $candidateHash\s*$") {
    throw "Release review must identify the frozen candidate with 'Candidate SHA256: $candidateHash'."
}
$reviewedAtMatch = [regex]::Match($reviewContent, '(?m)^Reviewed \(UTC\): (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\s*$')
$reviewedAt = [datetime]::MinValue
if (-not $reviewedAtMatch.Success -or -not [datetime]::TryParseExact(
    $reviewedAtMatch.Groups[1].Value, "yyyy-MM-dd'T'HH:mm:ss'Z'",
    [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$reviewedAt
)) {
    throw "Release review must contain a valid 'Reviewed (UTC): YYYY-MM-DDTHH:mm:ssZ'."
}
$reviewedAt = $reviewedAt.ToUniversalTime()
foreach ($field in @("Reviewer", "Checked by")) {
    $match = [regex]::Match($reviewContent, "(?m)^$([regex]::Escape($field)): (.+?)\s*$")
    if (-not $match.Success -or $match.Groups[1].Value -match '^(<|TODO|TBD|Name here)') {
        throw "Release review must identify '$field'."
    }
}
if ($reviewContent -notmatch "(?m)^Release version: $([regex]::Escape($version))\s*$" -or
    $reviewContent -notmatch '(?m)^Review status: APPROVED\s*$') {
    throw "Release review must approve the current version ($version)."
}
$requiredReviewSections = [ordered]@{
    "Release process" = 1
    "Package and installation" = 4
    "Listing, rights, and uploader certifications" = 7
    "Supported functionality" = 8
    "Manifest and dependencies" = 6
    "Initialization, naming, and saved data" = 3
    "Rule matching and inventory scope" = 1
    "Events and lifecycle" = 2
    "Resources, preferences, and messages" = 2
    "Performance and error handling" = 2
    "Human in-game testing" = 9
}
foreach ($section in $requiredReviewSections.Keys) {
    $sectionMatch = [regex]::Match($reviewContent, "(?ms)^#{2,3} $([regex]::Escape($section))\r?\n(?<body>.*?)(?=^#{1,3} |\z)")
    $completedCount = [regex]::Matches($sectionMatch.Groups["body"].Value, '(?m)^- \[x\] ').Count
    if (-not $sectionMatch.Success -or $completedCount -lt $requiredReviewSections[$section]) {
        throw "Release review is incomplete: $section"
    }
}
if ($reviewContent -match '(?m)^- \[ \] ') {
    throw "Release review contains unchecked requirements."
}
$nowUtc = [datetime]::UtcNow

if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    $resolvedOutputDirectory = [System.IO.Path]::GetFullPath((Join-Path $addonRoot $OutputDirectory))
}
if ($resolvedOutputDirectory -eq $candidateRoot -or $resolvedOutputDirectory.StartsWith("$candidateRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Package output must be outside the staged installation."
}
$archiveName = "InventoryCompanion-v$version.zip"
$archivePath = Join-Path $resolvedOutputDirectory $archiveName
if ((Test-Path -LiteralPath $archivePath) -and -not $Force) {
    throw "Package already exists: $archivePath. Use -Force to replace it."
}
$null = New-Item -ItemType Directory -Path $resolvedOutputDirectory -Force
$finalReview = $reviewContent.TrimEnd() + "`r`n`r`n## Staged release test confirmation`r`n`r`n" +
    "Staged (UTC): $($state.StagedAt)`r`nConfirmed (UTC): $($nowUtc.ToString('o'))`r`n`r`n$TestResults`r`n"
$packageRecords = @($state.Candidate) + @(
    [pscustomobject]@{ Path = "ReleaseReview.md"; Hash = "" }
)
$packagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("InventoryCompanion-package-" + [guid]::NewGuid().ToString("N"))
$temporaryArchive = Join-Path ([System.IO.Path]::GetTempPath()) ("InventoryCompanion-" + [guid]::NewGuid().ToString("N") + ".zip")
try {
    $null = New-Item -ItemType Directory -Path $packagingRoot
    $packagingAddon = Join-Path $packagingRoot "InventoryCompanion"
    Copy-Item -LiteralPath $candidateRoot -Destination $packagingAddon -Recurse
    Set-Content -LiteralPath (Join-Path $packagingAddon "ReleaseReview.md") -Value $finalReview -Encoding UTF8
    $packageRecords[-1] = Get-FileRecord (Join-Path $packagingAddon "ReleaseReview.md") "ReleaseReview.md"
    Compress-Archive -LiteralPath $packagingAddon -DestinationPath $temporaryArchive -CompressionLevel Optimal
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($temporaryArchive)
    try {
        $expectedEntries = @{}
        foreach ($record in $packageRecords) {
            $expectedEntries["InventoryCompanion/$($record.Path.Replace('\', '/'))"] = $record.Hash
        }
        foreach ($entry in $archive.Entries) {
            if (-not $expectedEntries.ContainsKey($entry.FullName)) {
                throw "Unexpected or duplicate ZIP entry: $($entry.FullName)"
            }
            $stream = $entry.Open()
            $sha = [System.Security.Cryptography.SHA256]::Create()
            try {
                $hash = [System.BitConverter]::ToString($sha.ComputeHash($stream)).Replace("-", "")
            } finally {
                $sha.Dispose()
                $stream.Dispose()
            }
            if ($hash -ne $expectedEntries[$entry.FullName]) {
                throw "ZIP file differs from the tested candidate: $($entry.FullName)"
            }
            $expectedEntries.Remove($entry.FullName)
        }
        if ($expectedEntries.Count -gt 0) {
            throw "ZIP is missing candidate files."
        }
    } finally {
        $archive.Dispose()
    }
    Copy-Item -LiteralPath (Join-Path $packagingAddon "ReleaseReview.md") -Destination $reviewPath
    Move-Item -LiteralPath $temporaryArchive -Destination $archivePath -Force:$Force
} finally {
    if (Test-Path -LiteralPath $temporaryArchive) {
        Remove-Item -LiteralPath $temporaryArchive
    }
    if (Test-Path -LiteralPath $packagingRoot) {
        Remove-Item -LiteralPath $packagingRoot -Recurse -Force
    }
}
$state.Completed = $true
$state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    $devVersionMatch = [regex]::Match((Get-Content -LiteralPath $manifestPath -Raw), '(?m)^## Version: (\d+)\.(\d+)(?:\.(\d+))?\s*$')
    $releasedVersionMatch = [regex]::Match($version, '^(\d+)\.(\d+)(?:\.(\d+))?$')
    if ($devVersionMatch.Success -and $releasedVersionMatch.Success -and
        $devVersionMatch.Groups[1].Value -eq $releasedVersionMatch.Groups[1].Value -and
        [int]$devVersionMatch.Groups[2].Value -eq [int]$releasedVersionMatch.Groups[2].Value) {
        $nextReleaseVersion = "{0}.{1}.{2}" -f $releasedVersionMatch.Groups[1].Value,
            (1 + [int]$releasedVersionMatch.Groups[2].Value), 0
        Set-DevelopmentVersion $nextReleaseVersion
    }
}
Write-Output "Created verified release package: $archivePath"
Write-Output "Release installation retained for gameplay. Use your add-on profiles to select release OR development."
Start-Process explorer.exe -ArgumentList ('"' + $resolvedOutputDirectory + '"')
