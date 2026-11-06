[CmdletBinding()]
param(
    [ValidateSet("Stage", "Finalize", "Cancel", "Backup")]
    [string]$Action = "Stage"
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
$currentReleaseRoot = Join-Path $PSScriptRoot "Packages\Reviewed\Current release"
$reviewPath = Join-Path $currentReleaseRoot "ReleaseReview.md"
$readmePath = Join-Path $currentReleaseRoot "ReadMe.bbcode"
$changelogPath = Join-Path $currentReleaseRoot "Changelog.bbcode"
$sourceDocumentPaths = @(
    "Project\Publishing\Source Documents\ReadMe-Header.bbcode"
    "Project\Publishing\Source Documents\ReadMe-Body.bbcode"
    "Project\Publishing\Source Documents\Changelog.bbcode"
)
$finalReleaseDocuments = [ordered]@{
    "ReadMe.bbcode" = $readmePath
    "Changelog.bbcode" = $changelogPath
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
        throw "Expected major.minor.patch version (legacy major.minor is accepted as patch zero)."
    }
    $major = [long]$Matches[1]
    $minor = [long]$Matches[2]
    $patch = [long]$Matches[3]
    if ($major -gt 214748 -or $minor -gt 99 -or $patch -gt 99) {
        throw "AddOnVersion encoding requires minor/patch components from 0 to 99 and a positive 32-bit integer result."
    }
    $integerVersion = $major * 10000 + $minor * 100 + $patch
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
    $manifestBytes = [System.IO.File]::ReadAllBytes($manifestPath)
    $initBytes = [System.IO.File]::ReadAllBytes($initPath)
    if ([regex]::Matches($manifest, '(?m)^## Version: [^\r\n]*').Count -ne 1 -or
        [regex]::Matches($manifest, '(?m)^## AddOnVersion: [^\r\n]*').Count -ne 1 -or
        [regex]::Matches($init, '(?m)^    Version = .+,\r?$').Count -ne 1) {
        throw "Cannot update development version: expected one manifest Version, AddOnVersion, and runtime version."
    }
    $updatedManifest = [regex]::Replace($manifest, '(?m)^## Version: [^\r\n]*', "## Version: $Version")
    $updatedManifest = [regex]::Replace($updatedManifest, '(?m)^## AddOnVersion: [^\r\n]*', "## AddOnVersion: $integerVersion")
    try {
        $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($manifestPath, $updatedManifest, $utf8WithoutBom)
        [System.IO.File]::WriteAllText(
            $initPath, ([regex]::Replace($init, '(?m)^    Version = [^\r\n]*', "    Version = `"$Version`",")),
            $utf8WithoutBom
        )
    } catch {
        [System.IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
        [System.IO.File]::WriteAllBytes($initPath, $initBytes)
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

function Assert-ReleaseReview([string]$Content, [string]$Version, [string]$CandidateHash, [bool]$RequireCandidateHash) {
    $requiredStatus = if ($RequireCandidateHash) { "Approved for Release" } else { "Approved to Test" }
    if ($Content -notmatch "(?m)^Status: \[$([regex]::Escape($requiredStatus))\]\s*$") {
        throw "Release review Status must be [$requiredStatus] for this release action."
    }
    foreach ($field in @("Reviewer", "Add-on", "Reviewed source")) {
        $fieldMatch = [regex]::Match($Content, "(?m)^$([regex]::Escape($field)): (.+?)\s*$")
        if (-not $fieldMatch.Success -or $fieldMatch.Groups[1].Value -match '^(<|TODO|TBD)') {
            throw "Release review must identify '$field'."
        }
    }
    $reviewedAtMatch = [regex]::Match($Content, '(?m)^Reviewed \(UTC\): (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\s*$')
    $reviewedAt = [datetime]::MinValue
    if (-not $reviewedAtMatch.Success -or -not [datetime]::TryParseExact(
        $reviewedAtMatch.Groups[1].Value, "yyyy-MM-dd'T'HH:mm:ss'Z'",
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$reviewedAt
    )) {
        throw "Release review must contain a valid 'Reviewed (UTC): YYYY-MM-DDTHH:mm:ssZ'."
    }
    if ($Content -notmatch "(?m)^Release version: $([regex]::Escape($Version))\s*$") {
        throw "Release review must identify the agreed version ($Version)."
    }
    if ($RequireCandidateHash -and $Content -notmatch "(?m)^Candidate SHA256: $([regex]::Escape($CandidateHash))\s*$") {
        throw "Release review must identify the frozen candidate with 'Candidate SHA256: $CandidateHash'."
    }
    if (-not $RequireCandidateHash -and $Content -notmatch '(?m)^Candidate SHA256: <filled after staging>\s*$') {
        throw "Release review must contain the Candidate SHA256 placeholder before staging."
    }
    $reviewStatusMatch = [regex]::Match(
        $Content, '(?m)^Review status: (COMPLETE - no findings|COMPLETE - findings present)\s*$'
    )
    if (-not $reviewStatusMatch.Success) {
        throw "Release review must be complete with no unresolved findings before this release action."
    }
    $modeMatch = [regex]::Match($Content, '(?m)^Review mode: (DELTA|FULL)\s*$')
    if (-not $modeMatch.Success) {
        throw "Release review must specify Review mode as DELTA or FULL."
    }
    $baselineMatch = [regex]::Match($Content, '(?m)^Baseline review: ([^\r\n]+)')
    $baseline = if ($baselineMatch.Success) { $baselineMatch.Groups[1].Value.Trim() } else { "" }
    if (-not $baseline -or $baseline -match '^(<|TODO|TBD)' -or
        ($modeMatch.Groups[1].Value -eq "DELTA" -and $baseline -match '^NONE\b')) {
        throw "Release review must identify its approved Baseline review (or NONE for FULL)."
    }
    foreach ($section in @(
        "Review scope", "Checks performed and results", "Test results", "Summary",
        "Findings", "Documentation review", "Version recommendation", "Changes reviewed"
    )) {
        if ($Content -notmatch "(?m)^#{1,3} $([regex]::Escape($section))\s*$") {
            throw "Release review is incomplete: $section"
        }
    }
    if ($Content -match '(?m)^- \[ \] ') {
        throw "Release review contains unchecked requirements or unresolved/failed checks."
    }
    if ($Content -notmatch '(?m)^- (\d+)/(\d+) synthetic tests passed\s*$' -or
        $Matches[1] -ne $Matches[2]) {
        throw "Release review must record the synthetic unit-test pass/fail rate."
    }
    if ($RequireCandidateHash -and
        ($Content -notmatch '(?m)^- In-game UAT: .+\S' -or
         $Content -match '(?m)^- In-game UAT: (?:<|PENDING\b)')) {
        throw "Release review must record actual in-game UAT results and observations before finalization."
    }
    $hasUserTestRate = $Content -match '(?m)^- (\d+)/(\d+) user driven unit tests passed\s*$'
    if ($hasUserTestRate -and $Matches[1] -ne $Matches[2]) {
        throw "Release review records failing user-driven unit tests."
    }
    $pendingUserTestLines = @($Content -split '\r?\n' | Where-Object { $_ -match '(?i)user.*PENDING' })
    $hasPendingUserTests = $pendingUserTestLines.Count -gt 0
    if (($RequireCandidateHash -and -not $hasUserTestRate) -or
        (-not $RequireCandidateHash -and -not ($hasUserTestRate -or $hasPendingUserTests))) {
        if ($RequireCandidateHash) {
            throw "Release review must record user-driven unit-test pass/fail rates before finalization."
        }
        throw "Release review must record user-driven unit-test results or mark them PENDING before staging."
    }
    $summaryMatch = [regex]::Match($Content, '(?ms)^### Summary\s*\r?\n(?<body>.*?)(?=^### |\z)')
    $findingsMatch = [regex]::Match($Content, '(?ms)^### Findings\s*\r?\n(?<body>.*?)(?=^### |\z)')
    $changesMatch = [regex]::Match($Content, '(?ms)^### Changes reviewed\s*\r?\n(?<body>.*?)(?=^### |\z)')
    $versionMatch = [regex]::Match($Content, '(?ms)^### Version recommendation\s*\r?\n(?<body>.*?)(?=^### |\z)')
    $incompleteSections = [System.Collections.Generic.List[string]]::new()
    if (-not $summaryMatch.Success -or
        [string]::IsNullOrWhiteSpace($summaryMatch.Groups["body"].Value.Trim()) -or
        $summaryMatch.Groups["body"].Value -match '<Summary of the report\.>') {
        $incompleteSections.Add("Summary")
    }
    $findingLines = @($findingsMatch.Groups["body"].Value -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $noFindings = $findingLines.Count -eq 1 -and
        $findingLines[0] -eq "- No findings identified in the assessed scope."
    $resolvedFindings = $findingLines.Count -gt 0 -and
        @($findingLines | Where-Object { $_ -notmatch '^- \*\*F-\d+ — RESOLVED\.' }).Count -eq 0
    $validFindings = if ($reviewStatusMatch.Groups[1].Value -eq "COMPLETE - no findings") {
        $noFindings
    } else {
        $resolvedFindings
    }
    if (-not $findingsMatch.Success -or -not $validFindings) {
        $incompleteSections.Add("Findings")
    }
    if (-not $changesMatch.Success -or $changesMatch.Groups["body"].Value -match 'List the examined') {
        $incompleteSections.Add("Changes reviewed")
    }
    if (-not $versionMatch.Success -or
        [string]::IsNullOrWhiteSpace($versionMatch.Groups["body"].Value.Trim()) -or
        $versionMatch.Groups["body"].Value -match '<Recommend the next') {
        $incompleteSections.Add("Version recommendation")
    }
    if ($incompleteSections.Count) {
        throw "Release review must complete these sections: $($incompleteSections -join ', ')."
    }
    $checkSection = [regex]::Match($Content, '(?ms)^### Checks performed and results\s*\r?\n(?<body>.*?)(?=^### |\z)')
    $checkRows = @($checkSection.Groups["body"].Value -split '\r?\n' | Where-Object { $_ -match '^\| .+ \|$' -and $_ -notmatch '^\|[-| ]+\|$' })
    foreach ($row in $checkRows | Select-Object -Skip 1) {
        $cells = @($row.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        $prefilledResult = $cells.Count -eq 3 -and
            $cells[2] -in @("Certified by @Tim-P", "See documentation review")
        if ($cells.Count -ne 3 -or $cells[1] -notin @("Yes", "No") -or
            (-not $prefilledResult -and
             $cells[2] -notmatch '^(PASS|FAIL|PENDING|UNRESOLVED|N/A)(?:\s|:|$)')) {
            throw "Release review has an incomplete row in Checks performed and results: $row"
        }
        if ($cells[2] -match '^(FAIL|UNRESOLVED)(?:\s|:|$)') {
            throw "Release review contains an unresolved/failed check: $row"
        }
        if ($RequireCandidateHash -and $cells[2] -match '^PENDING(?:\s|:|$)') {
            throw "Release review still contains a pending check before finalization: $row"
        }
    }
    $pendingSection = [regex]::Match($Content, '(?ms)^### Pending items\s*\r?\n(?<body>.*?)(?=^### |\z)')
    if (-not $pendingSection.Success) {
        throw "Release review must contain the Pending items section."
    }
    $pendingItems = @($pendingSection.Groups["body"].Value -split '\r?\n' |
        Where-Object { $_ -match '^- ' -and $_ -notmatch '^- <' -and $_ -notmatch '^- None\.$' })
    if ($RequireCandidateHash -and $pendingItems.Count -gt 0) {
        throw "Release review still has Pending items before finalization."
    }
    $documentationSection = [regex]::Match($Content, '(?ms)^### Documentation review\s*\r?\n(?<body>.*?)(?=^### |\z)')
    $documentationRows = @($documentationSection.Groups["body"].Value -split '\r?\n' |
        Where-Object { $_ -match '^\| .+ \|$' -and $_ -notmatch '^\|[-| ]+\|$' })
    foreach ($row in $documentationRows | Select-Object -Skip 1) {
        $cells = @($row.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -ne 3 -or $cells[2] -notmatch '^PASS(?:\s|:|$)') {
            throw "Release review has an incomplete row in Documentation review: $row"
        }
    }
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
    throw "Expected major.minor.patch version (legacy major.minor is accepted as patch zero)."
}
$nextPatchVersion = "{0}.{1}.{2}" -f [int]$Matches[1], [int]$Matches[2], (1 + [int]$Matches[3])
$integerVersion = Get-AddOnVersion $version
$null = Get-AddOnVersion $nextPatchVersion
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
foreach ($relativePath in $sourceDocumentPaths) {
    $documentPath = Join-Path $addonRoot $relativePath
    if (-not (Test-Path -LiteralPath $documentPath -PathType Leaf) -or
        (Get-Item -LiteralPath $documentPath).Length -eq 0) {
        throw "Prepare nonempty release source files before staging: $relativePath"
    }
    if ([string]::IsNullOrWhiteSpace([System.IO.File]::ReadAllText($documentPath))) {
        throw "Prepare nonempty release source files before staging: $relativePath"
    }
}
foreach ($requiredReleaseFile in @($readmePath, $changelogPath, $reviewPath)) {
    if (-not (Test-Path -LiteralPath $requiredReleaseFile -PathType Leaf) -or
        [string]::IsNullOrWhiteSpace([System.IO.File]::ReadAllText($requiredReleaseFile))) {
        throw "Prepare the current release report, combined readme, and changelog before staging: $requiredReleaseFile"
    }
}
$initialReviewContent = [System.IO.File]::ReadAllText($reviewPath)
Assert-ReleaseReview $initialReviewContent $version "" $false
$sourcePaths = @(
    "InventoryCompanion_DEV.txt"
    "Project\Publishing\ReleaseChecklist.md"
    "Project\Publishing\ReleaseReviewTemplate.md"
    "Project\Publishing\PackageRelease.ps1"
) + $sourceDocumentPaths + @($manifestFiles)
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
        [System.IO.File]::WriteAllLines(
            (Join-Path $candidateRoot "InventoryCompanion.txt"),
            [string[]]$releaseManifest,
            [System.Text.UTF8Encoding]::new($false)
        )
        foreach ($relativePath in $runtimeFiles) {
            $destination = Join-Path $candidateRoot $relativePath
            $null = New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force
            Copy-Item -LiteralPath (Join-Path $addonRoot $relativePath) -Destination $destination
        }
        Copy-Item -LiteralPath $readmePath -Destination (Join-Path $candidateRoot "ReadMe.bbcode")
        $candidateRecords = @(Get-CandidateRecords)
        $candidateIdentity = (@($candidateRecords | ForEach-Object { "$($_.Path)|$($_.Hash)" } | Sort-Object) -join "`n")
        $identitySha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $candidateHash = [System.BitConverter]::ToString(
                $identitySha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($candidateIdentity))
            ).Replace("-", "")
        } finally {
            $identitySha.Dispose()
        }
        $reviewContent = $initialReviewContent
        if ($reviewContent -notmatch '(?m)^Candidate SHA256: <filled after staging>\s*$') {
            throw "Release review template must contain the Candidate SHA256 placeholder."
        }
        $reviewContent = [regex]::Replace($reviewContent, '(?m)^Release version: <agreed major\.minor\.patch version>\s*$', "Release version: $version")
        $reviewContent = [regex]::Replace($reviewContent, '(?m)^Candidate SHA256: <filled after staging>\s*$', "Candidate SHA256: $candidateHash")
        [System.IO.File]::WriteAllText($reviewPath, $reviewContent, [System.Text.UTF8Encoding]::new($false))
        $state = [ordered]@{
            Schema = 1
            Completed = $false
            SourceRoot = $addonRoot
            CandidateRoot = $candidateRoot
            Version = $version
            StagedAt = [datetime]::UtcNow.ToString("o")
            Sources = $sourceRecords
            Candidate = $candidateRecords
        }
        $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8
        Set-DevelopmentVersion $nextPatchVersion
    } catch {
        # Do not leave an unrecorded candidate after failed staging.
        Remove-Item -LiteralPath $candidateRoot -Recurse -Force
        if (Test-Path -LiteralPath $statePath) { Remove-Item -LiteralPath $statePath }
        [System.IO.File]::WriteAllText($reviewPath, $initialReviewContent, [System.Text.UTF8Encoding]::new($false))
        throw
    }
    Write-Output "Staged release $version at $candidateRoot"
    Write-Output "Staging finished. Only runtime files and the prepared combined ReadMe.bbcode were copied into the test installation."
    Write-Output "Select only InventoryCompanion in your release-test add-on profile, then reload the UI. Verify Installation=InventoryCompanion, runtime version=$version, DEV=false, AddOnVersion=$integerVersion, and no enabled DEV copy."
    Write-Output "Verify the candidate identity, then run the agreed in-game diagnostics, feature/transfer checks, and brief load/function smoke. Record actual results; do not infer success from staging."
    Write-Output "Both versions share saved variables. Any automatic backup is only the last-on-disk snapshot."
    Write-Output "After UAT, update the Current release documents and report. Finalize copies the approved documents and report into the test installation and packages its files."
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
$expectedCandidate = @($state.Candidate | ForEach-Object { "$($_.Path)|$($_.Hash)" } | Sort-Object)
$actualCandidate = @(Get-CandidateRecords | ForEach-Object { "$($_.Path)|$($_.Hash)" } | Sort-Object)
if (@(Compare-Object $expectedCandidate $actualCandidate).Count -gt 0) {
    throw "Release candidate files changed since staging. Cancel and stage a fresh candidate for testing."
}
if (-not (Test-Path -LiteralPath $reviewPath -PathType Leaf)) {
    throw "Complete ReleaseReview.md from ReleaseReviewTemplate.md before finalizing."
}
$reviewContent = [System.IO.File]::ReadAllText($reviewPath)
Assert-ReleaseReview $reviewContent $version $candidateHash $true

$archiveName = "InventoryCompanion-v$version.zip"
$archivePath = Join-Path $currentReleaseRoot $archiveName
if (Test-Path -LiteralPath $archivePath) {
    throw "Package already exists: $archivePath. Preserve it and prepare a clean Current release folder before another release."
}
$handoffDirectory = Join-Path (Join-Path $PSScriptRoot "Packages\Reviewed") "InventoryCompanion-v$version"
if (Test-Path -LiteralPath $handoffDirectory) {
    throw "Release handoff folder already exists: $handoffDirectory. Do not overwrite a prior handoff."
}
$packagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("InventoryCompanion-package-" + [guid]::NewGuid().ToString("N"))
$temporaryArchive = Join-Path ([System.IO.Path]::GetTempPath()) ("InventoryCompanion-" + [guid]::NewGuid().ToString("N") + ".zip")
$candidateReadmePath = Join-Path $candidateRoot "ReadMe.bbcode"
$originalReadme = [System.IO.File]::ReadAllBytes($candidateReadmePath)
$candidateDocumentsApplied = $false
$archiveCreated = $false
try {
    $null = New-Item -ItemType Directory -Path $packagingRoot
    $packagingAddon = Join-Path $packagingRoot "InventoryCompanion"
    Copy-Item -LiteralPath $candidateRoot -Destination $packagingAddon -Recurse
    foreach ($relativePath in $finalReleaseDocuments.Keys) {
        $source = $finalReleaseDocuments[$relativePath]
        if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or
            [string]::IsNullOrWhiteSpace([System.IO.File]::ReadAllText($source))) {
            throw "Prepare nonempty final release documentation before finalization: $source"
        }
        Copy-Item -LiteralPath $source -Destination (Join-Path $packagingAddon $relativePath) -Force
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $packagingAddon "ReleaseReview.md"), $reviewContent, [System.Text.UTF8Encoding]::new($false)
    )
    $packageRecords = @(Get-ChildItem -LiteralPath $packagingAddon -File -Recurse -Force | ForEach-Object {
        Get-FileRecord $_.FullName $_.FullName.Substring($packagingAddon.Length + 1)
    })
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
            throw "ZIP is missing finalized release files."
        }
    } finally {
        $archive.Dispose()
    }
    $candidateDocumentsApplied = $true
    foreach ($relativePath in $finalReleaseDocuments.Keys) {
        Copy-Item -LiteralPath $finalReleaseDocuments[$relativePath] `
            -Destination (Join-Path $candidateRoot $relativePath) -Force
    }
    Copy-Item -LiteralPath $reviewPath -Destination (Join-Path $candidateRoot "ReleaseReview.md")
    $candidateFinalRecords = @(Get-CandidateRecords)
    $expectedFinalRecords = @($packageRecords | ForEach-Object { "$($_.Path)|$($_.Hash)" } | Sort-Object)
    $actualFinalRecords = @($candidateFinalRecords | ForEach-Object { "$($_.Path)|$($_.Hash)" } | Sort-Object)
    if (@(Compare-Object $expectedFinalRecords $actualFinalRecords).Count -gt 0) {
        throw "Finalized test-installation files differ from the verified package."
    }
    Move-Item -LiteralPath $temporaryArchive -Destination $archivePath
    $archiveCreated = $true
} catch {
    if ($candidateDocumentsApplied) {
        [System.IO.File]::WriteAllBytes($candidateReadmePath, $originalReadme)
        foreach ($relativePath in @("Changelog.bbcode", "ReleaseReview.md")) {
            $candidateDocumentPath = Join-Path $candidateRoot $relativePath
            if (Test-Path -LiteralPath $candidateDocumentPath) {
                Remove-Item -LiteralPath $candidateDocumentPath
            }
        }
    }
    if ($archiveCreated -and (Test-Path -LiteralPath $archivePath)) {
        Remove-Item -LiteralPath $archivePath
    }
    throw
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
$handoffCreated = $false
try {
    $null = New-Item -ItemType Directory -Path $handoffDirectory
    $handoffCreated = $true
    $handoffArchive = Join-Path $handoffDirectory $archiveName
    Copy-Item -LiteralPath $archivePath -Destination $handoffArchive
    if ((Get-FileHash -LiteralPath $handoffArchive -Algorithm SHA256).Hash -ne $archiveHash) {
        throw "The handoff ZIP copy does not match the finalized archive."
    }
    foreach ($relativePath in @("ReadMe.bbcode", "Changelog.bbcode")) {
        Copy-Item -LiteralPath (Join-Path $candidateRoot $relativePath) -Destination (Join-Path $handoffDirectory $relativePath)
    }
    Copy-Item -LiteralPath (Join-Path $candidateRoot "ReleaseReview.md") -Destination (Join-Path $handoffDirectory "ReleaseReview.md")
} catch {
    if ($handoffCreated -and (Test-Path -LiteralPath $handoffDirectory)) {
        Remove-Item -LiteralPath $handoffDirectory -Recurse -Force
    }
    [System.IO.File]::WriteAllBytes($candidateReadmePath, $originalReadme)
    foreach ($relativePath in @("Changelog.bbcode", "ReleaseReview.md")) {
        $candidateDocumentPath = Join-Path $candidateRoot $relativePath
        if (Test-Path -LiteralPath $candidateDocumentPath) {
            Remove-Item -LiteralPath $candidateDocumentPath
        }
    }
    if ($archiveCreated -and (Test-Path -LiteralPath $archivePath)) {
        Remove-Item -LiteralPath $archivePath
    }
    throw "The ZIP was verified at '$archivePath', but preparing its upload handoff failed: $($_.Exception.Message)"
}
try {
    $state.Completed = $true
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8
} catch {
    throw "Package verified at '$archivePath' (archive SHA256: $archiveHash), but completion-state recording failed: $($_.Exception.Message) Do not overwrite or re-finalize the package; repair the managed completion state before further release actions."
}
Write-Output "Release installation retained for gameplay. Use your add-on profiles to select release OR development."
Write-Output "Prepared upload handoff folder: $handoffDirectory"
Start-Process explorer.exe -ArgumentList ('"' + $handoffDirectory + '"')
