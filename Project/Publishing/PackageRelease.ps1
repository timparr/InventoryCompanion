[CmdletBinding()]
param(
    [ValidateSet("Stage", "Finalize", "Cancel", "Backup")]
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
$releaseDocuments = [ordered]@{
    "readme.md" = "readme.md"
    "Changelog.md" = "Project\Publishing\Packages\Reviewed\Current Documentation\Changelog.md"
}

function Backup-SavedVariables {
    $liveRoot = Split-Path (Split-Path $addonRoot -Parent) -Parent
    $savedVariablesDirectory = Join-Path $liveRoot "SavedVariables"
    $installationNames = @((Split-Path $candidateRoot -Leaf), (Split-Path $addonRoot -Leaf))
    $sourceFiles = @(foreach ($name in $installationNames) {
        $path = Join-Path $savedVariablesDirectory "$name.lua"
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Get-Item -LiteralPath $path
        }
    })
    if ($sourceFiles.Count -eq 0) {
        Write-Warning "No ESO saved variables files found for '$($installationNames -join "', '")' in '$savedVariablesDirectory'; no backup was created. Confirm the active profile before gameplay testing."
        return
    }

    $backupDirectory = Join-Path $addonRoot "SavedVariables"
    $null = New-Item -ItemType Directory -Path $backupDirectory -Force
    $timestamp = [datetime]::UtcNow.ToString("yyyyMMdd-HHmmssfff'Z'")
    foreach ($sourceFile in $sourceFiles) {
        $backupPath = Join-Path $backupDirectory "$($sourceFile.BaseName)-$timestamp.lua"
        $suffix = 1
        while (Test-Path -LiteralPath $backupPath) {
            $backupPath = Join-Path $backupDirectory "$($sourceFile.BaseName)-$timestamp-$suffix.lua"
            $suffix++
        }
        Copy-Item -LiteralPath $sourceFile.FullName -Destination $backupPath
        $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
        $backupHash = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash
        if ($sourceHash -ne $backupHash) {
            throw "SavedVariables backup verification failed: '$backupPath'. Do not begin gameplay testing."
        }
        Write-Output "SavedVariables source: $($sourceFile.FullName)"
        Write-Output "SavedVariables backup: $backupPath"
        Write-Output "SavedVariables backup SHA256: $backupHash"
    }
    Write-Output "Backup is the last-on-disk snapshot, not necessarily ESO's current in-memory settings. Exit ESO before restoring it."
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

function Get-AddOnVersion([string]$Version) {
    if ($Version -notmatch '^(\d+)\.(\d+)(?:\.(\d+))?$') {
        throw "Expected major.minor.build version (legacy major.minor is accepted as build zero)."
    }
    $major = [long]$Matches[1]
    $minor = [long]$Matches[2]
    $build = [long]$Matches[3]
    if ($major -gt 214748 -or $minor -gt 99 -or $build -gt 99) {
        throw "AddOnVersion encoding requires minor/build components from 0 to 99 and a positive 32-bit integer result."
    }
    $integerVersion = $major * 10000 + $minor * 100 + $build
    if ($integerVersion -lt 1 -or $integerVersion -gt [int]::MaxValue) {
        throw "AddOnVersion encoding requires a positive 32-bit integer result."
    }
    return [int]$integerVersion
}

function Set-DevelopmentVersion([string]$Version) {
    $integerVersion = Get-AddOnVersion $Version
    $initPath = Join-Path $addonRoot "Core\Init.lua"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw
    $init = Get-Content -LiteralPath $initPath -Raw
    if ([regex]::Matches($manifest, '(?m)^## Version: .+$').Count -ne 1 -or
        [regex]::Matches($manifest, '(?m)^## AddOnVersion: .+$').Count -ne 1 -or
        [regex]::Matches($init, '(?m)^    Version = .+,\r?$').Count -ne 1) {
        throw "Cannot update development version: expected one manifest Version, AddOnVersion, and runtime version."
    }
    $updatedManifest = [regex]::Replace($manifest, '(?m)^## Version: .+$', "## Version: $Version")
    $updatedManifest = [regex]::Replace($updatedManifest, '(?m)^## AddOnVersion: .+$', "## AddOnVersion: $integerVersion")
    try {
        Set-Content -LiteralPath $manifestPath -Value $updatedManifest -NoNewline -Encoding UTF8
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

if ($Action -eq "Backup") {
    Backup-SavedVariables
    return
}
if ($Action -in @("Stage", "Cancel")) {
    Write-Warning "ESO may remain open. Do not reload the UI or change characters while installed files are being changed."
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
$integerVersion = Get-AddOnVersion $version
$null = Get-AddOnVersion $nextBuildVersion
$integerVersionLines = @($manifestLines | Where-Object { $_ -match '^##\s*AddOnVersion:' })
if ($integerVersionLines.Count -ne 1 -or
    $integerVersionLines[0] -notmatch "^## AddOnVersion: $integerVersion\s*$") {
    throw "The manifest must define exactly one ## AddOnVersion: $integerVersion matching Version $version."
}

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
foreach ($relativePath in $releaseDocuments.Values) {
    $documentPath = Join-Path $addonRoot $relativePath
    if (-not (Test-Path -LiteralPath $documentPath -PathType Leaf) -or
        [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $documentPath -Raw))) {
        throw "Prepare nonempty release documentation before staging: $relativePath"
    }
}
$sourcePaths = @(
    "InventoryCompanion_DEV.txt"
    "Project\Publishing\ReleaseChecklist.md"
    "Project\Publishing\ReleaseReviewTemplate.md"
    "Project\Publishing\PackageRelease.ps1"
) + @($releaseDocuments.Values) + @($manifestFiles)
$sourceRecords = @(foreach ($relativePath in $sourcePaths) {
    $path = if ($relativePath -eq "InventoryCompanion_DEV.txt") { $sourceManifestPath } else { Join-Path $addonRoot $relativePath }
    Get-FileRecord $path $relativePath
})

    Backup-SavedVariables
    $releaseManifest = @($manifestLines | Where-Object {
        $_.Trim().Replace('/', '\') -ne "Core\Development.lua"
    } | ForEach-Object {
        $_ -replace '^(##\s*Title:.*?) \[DEV\]', '$1'
    })
    $null = New-Item -ItemType Directory -Path $stateDirectory -Force
    $null = New-Item -ItemType Directory -Path $candidateRoot
    try {
        Set-Content -LiteralPath (Join-Path $candidateRoot "InventoryCompanion.txt") -Value $releaseManifest -Encoding UTF8
        foreach ($relativePath in @($runtimeFiles) + @($releaseDocuments.Keys)) {
            $destination = Join-Path $candidateRoot $relativePath
            $null = New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force
            $sourcePath = if ($releaseDocuments.Contains($relativePath)) { $releaseDocuments[$relativePath] } else { $relativePath }
            Copy-Item -LiteralPath (Join-Path $addonRoot $sourcePath) -Destination $destination
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
    Write-Output "Staging finished. Select only InventoryCompanion in your release-test add-on profile, then reload the UI."
    Write-Output "Run /ictest verbose copy after reloading. Verify Installation=InventoryCompanion, runtime version=$version, DEV=false, AddOnVersion=$integerVersion, and no enabled DEV copy."
    Write-Output "Both versions share saved variables. Any automatic backup is only the last-on-disk snapshot."
    Write-Output "After review and testing, complete ReleaseReview.md, then run -Action Finalize -TestResults '<actual results>'. ESO may remain open during finalization."
    Write-Output "To remove this installation, run -Action Cancel without reloading during removal; then select DEV only and reload."
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
$formatMatch = [regex]::Match($reviewContent, '(?m)^Review format: ([^\r\n]*)')
if ($formatMatch.Success) {
    if ($formatMatch.Groups[1].Value.Trim() -ne "compact-v1") {
        throw "Release review has an unsupported Review format."
    }
    $modeMatch = [regex]::Match($reviewContent, '(?m)^Review mode: (DELTA|FULL)\s*$')
    if (-not $modeMatch.Success) {
        throw "Release review must specify 'Review mode: DELTA' or 'Review mode: FULL'."
    }
    $baselineMatch = [regex]::Match($reviewContent, '(?m)^Baseline review: ([^\r\n]+)')
    $baseline = $baselineMatch.Groups[1].Value.Trim()
    if (-not $baselineMatch.Success -or -not $baseline -or $baseline -match '^(<|TODO|TBD)' -or
        ($modeMatch.Groups[1].Value -eq "DELTA" -and $baseline -match '^NONE\b')) {
        throw "Release review must identify its approved Baseline review (or NONE for FULL)."
    }
    $requiredReviewSections = [ordered]@{
        "Review scope" = 1
        "Changes reviewed" = 1
        "Release checks" = 1
        "Test evidence" = 1
        "Findings and decision" = 1
    }
} else {
    # Keep previously completed detailed reports valid.
    $requiredReviewSections = [ordered]@{
        "Release process" = 1
        "Package and installation" = 4
        "Listing, rights, and uploader certifications" = 7
        "Supported functionality" = 8
        "Manifest and dependencies" = 6
        "Test discovery and coverage" = 2
        "Initialization, naming, and saved data" = 3
        "Core behavior and correctness" = 2
        "Events and lifecycle" = 2
        "User interface and configuration" = 2
        "Performance and queued operations" = 3
        "Human in-game testing" = 5
    }
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
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
Write-Output "Created verified release package: $archivePath"
Write-Output "Archive SHA256: $archiveHash"
Write-Output "Candidate file-set SHA256: $candidateHash"
try {
    $state.Completed = $true
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8
} catch {
    throw "Package verified at '$archivePath' (archive SHA256: $archiveHash), but completion-state recording failed: $($_.Exception.Message) Do not overwrite or re-finalize the package; repair the managed completion state before further release actions."
}
try {
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Development manifest is missing."
    }
    $devVersionMatch = [regex]::Match((Get-Content -LiteralPath $manifestPath -Raw), '(?m)^## Version: (\d+)\.(\d+)(?:\.(\d+))?\s*$')
    $releasedVersionMatch = [regex]::Match($version, '^(\d+)\.(\d+)(?:\.(\d+))?$')
    if (-not $devVersionMatch.Success -or -not $releasedVersionMatch.Success) {
        throw "Cannot determine development/release version series."
    }
    if ($devVersionMatch.Groups[1].Value -eq $releasedVersionMatch.Groups[1].Value -and
        [int]$devVersionMatch.Groups[2].Value -eq [int]$releasedVersionMatch.Groups[2].Value) {
        $nextReleaseVersion = "{0}.{1}.{2}" -f $releasedVersionMatch.Groups[1].Value,
            (1 + [int]$releasedVersionMatch.Groups[2].Value), 0
        Set-DevelopmentVersion $nextReleaseVersion
    }
} catch {
    throw "Package verified at '$archivePath' (archive SHA256: $archiveHash) and finalization is recorded as completed, but development-version housekeeping failed: $($_.Exception.Message) Do not re-finalize; repair the DEV manifest/runtime versions together before the next stage. The verified package and installed candidate remain valid."
}
Write-Output "Release installation retained for gameplay. Use your add-on profiles to select release OR development."
Start-Process explorer.exe -ArgumentList ('"' + $resolvedOutputDirectory + '"')
