[CmdletBinding()]
param(
    [string]$OutputDirectory = "Project\Publishing\Packages",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$addonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$manifestPath = Join-Path $addonRoot "InventoryCompanion.txt"
$addonName = [System.IO.Path]::GetFileNameWithoutExtension($manifestPath)

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Add-on manifest not found: $manifestPath"
}

$manifestLines = Get-Content -LiteralPath $manifestPath
$versionLine = $manifestLines | Where-Object { $_ -match '^##\s*Version:\s*(.+?)\s*$' } | Select-Object -First 1
if (-not $versionLine) {
    throw "The manifest does not define ## Version."
}

$version = [regex]::Match($versionLine, '^##\s*Version:\s*(.+?)\s*$').Groups[1].Value
if ($version -notmatch '^[A-Za-z0-9._-]+$') {
    throw "The manifest version contains characters that cannot be used in a package filename: $version"
}

$reviewPath = Join-Path $PSScriptRoot "ReleaseReview.md"
$reviewChecklistPath = Join-Path $PSScriptRoot "ReleaseChecklist.md"
$reviewTemplatePath = Join-Path $PSScriptRoot "ReleaseReviewTemplate.md"
$readmePath = Join-Path $addonRoot "readme.md"
foreach ($requiredPath in @($reviewPath, $reviewChecklistPath, $reviewTemplatePath, $readmePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required release review input is missing: $requiredPath"
    }
}

$reviewContent = Get-Content -LiteralPath $reviewPath -Raw
$reviewedAtMatch = [regex]::Match($reviewContent, '(?m)^Reviewed \(UTC\): (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\s*$')
if (-not $reviewedAtMatch.Success) {
    throw "Release review must contain 'Reviewed (UTC): YYYY-MM-DDTHH:mm:ssZ'. Start from ReleaseReviewTemplate.md."
}

$reviewedAt = [datetime]::MinValue
if (-not [datetime]::TryParseExact(
    $reviewedAtMatch.Groups[1].Value,
    "yyyy-MM-dd'T'HH:mm:ss'Z'",
    [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::AssumeUniversal,
    [ref]$reviewedAt
)) {
    throw "Release review has an invalid UTC timestamp."
}
$reviewedAt = $reviewedAt.ToUniversalTime()

$reviewerMatch = [regex]::Match($reviewContent, '(?m)^Reviewer: (.+?)\s*$')
if (-not $reviewerMatch.Success -or $reviewerMatch.Groups[1].Value -match '^(<|TODO|TBD|Name here)') {
    throw "Release review must identify the reviewer."
}
if ($reviewContent -notmatch "(?m)^Release version: $([regex]::Escape($version))\s*$") {
    throw "Release review must name the current manifest version ($version)."
}
if ($reviewContent -notmatch '(?m)^Review status: APPROVED\s*$') {
    throw "Release review must have 'Review status: APPROVED'."
}

$requiredReviewItems = @(
    "ESOUI release guidance, upload rules, and linked prohibited-functionality guidance",
    "House-chest transfers follow a player-opened interaction and supported protected APIs; record relevant precedent or unresolved concerns",
    "Addon globals, saved-variable names and scope, UI names, and event filters",
    "Current API versions and every non-optional dependency minimum version",
    "Upload description, AI disclosure, credits, licensing, and install information",
    "Release tests and exact ZIP contents"
)
foreach ($reviewItem in $requiredReviewItems) {
    if ($reviewContent -notmatch "(?m)^- \[x\] $([regex]::Escape($reviewItem))\s*$") {
        throw "Release review is incomplete. Confirm this item after reviewing it: $reviewItem"
    }
}

$reviewTimeLimit = [timespan]::FromHours(24)
$nowUtc = [datetime]::UtcNow
if ($reviewedAt -gt $nowUtc -or ($nowUtc - $reviewedAt) -gt $reviewTimeLimit) {
    throw "Release review must be completed within 24 hours of packaging."
}

$manifestFiles = [System.Collections.Generic.List[string]]::new()
$seenPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$rootPrefix = $addonRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

foreach ($line in $manifestLines) {
    $relativePath = $line.Trim()
    if (-not $relativePath -or $relativePath.StartsWith("#") -or $relativePath.StartsWith("--")) {
        continue
    }

    if ([System.IO.Path]::IsPathRooted($relativePath)) {
        throw "Manifest entries must be relative paths: $relativePath"
    }

    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $addonRoot $relativePath))
    if (-not $sourcePath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Manifest entry resolves outside the add-on folder: $relativePath"
    }
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Manifest-listed file does not exist: $relativePath"
    }
    if (-not $seenPaths.Add($relativePath)) {
        throw "Duplicate manifest entry: $relativePath"
    }

    $manifestFiles.Add($relativePath)
}

if ($manifestFiles.Count -eq 0) {
    throw "The manifest contains no runtime files to package."
}

$releaseInputPaths = [System.Collections.Generic.List[string]]::new()
$releaseInputPaths.Add($manifestPath)
$releaseInputPaths.Add($readmePath)
$releaseInputPaths.Add($reviewChecklistPath)
$releaseInputPaths.Add($reviewTemplatePath)
$releaseInputPaths.Add($PSCommandPath)
foreach ($relativePath in $manifestFiles) {
    $releaseInputPaths.Add((Join-Path $addonRoot $relativePath))
}
$newestInputWriteUtc = [datetime]::MinValue
foreach ($releaseInputPath in $releaseInputPaths) {
    $inputWriteUtc = (Get-Item -LiteralPath $releaseInputPath).LastWriteTimeUtc
    if ($inputWriteUtc -gt $newestInputWriteUtc) {
        $newestInputWriteUtc = $inputWriteUtc
    }
}

$reviewWriteUtc = (Get-Item -LiteralPath $reviewPath).LastWriteTimeUtc
if ($reviewWriteUtc -gt $nowUtc) {
    throw "Release review file timestamp cannot be in the future."
}
if (($nowUtc - $reviewWriteUtc) -gt $reviewTimeLimit) {
    throw "Release review file timestamp is older than 24 hours."
}
if ($reviewedAt -le $newestInputWriteUtc -or $reviewWriteUtc -le $newestInputWriteUtc) {
    throw "Release review must be recorded and saved after the latest change to every release input."
}

if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    $resolvedOutputDirectory = [System.IO.Path]::GetFullPath((Join-Path $addonRoot $OutputDirectory))
}

$archiveName = "$addonName-v$version.zip"
$archivePath = Join-Path $resolvedOutputDirectory $archiveName
if ((Test-Path -LiteralPath $archivePath) -and -not $Force) {
    throw "Package already exists: $archivePath. Use -Force to replace it."
}

$null = New-Item -ItemType Directory -Path $resolvedOutputDirectory -Force
$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("InventoryCompanion-release-" + [guid]::NewGuid().ToString("N"))
$stagedAddonDirectory = Join-Path $stagingRoot $addonName
$stagedReviewPath = Join-Path $stagingRoot "$addonName-ReleaseReview.txt"
$stagedArchivePath = Join-Path $stagingRoot $archiveName

try {
    $null = New-Item -ItemType Directory -Path $stagedAddonDirectory -Force
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $stagedAddonDirectory "InventoryCompanion.txt")
    Copy-Item -LiteralPath $reviewPath -Destination $stagedReviewPath

    foreach ($relativePath in $manifestFiles) {
        $sourcePath = Join-Path $addonRoot $relativePath
        $stagedPath = Join-Path $stagedAddonDirectory $relativePath
        $stagedParent = Split-Path -Parent $stagedPath
        if (-not (Test-Path -LiteralPath $stagedParent -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $stagedParent -Force
        }
        Copy-Item -LiteralPath $sourcePath -Destination $stagedPath
    }

    Compress-Archive -LiteralPath @($stagedAddonDirectory, $stagedReviewPath) -DestinationPath $stagedArchivePath -CompressionLevel Optimal

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($stagedArchivePath)
    try {
        $expectedEntries = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $null = $expectedEntries.Add("$addonName/InventoryCompanion.txt")
        $null = $expectedEntries.Add("$addonName-ReleaseReview.txt")
        foreach ($relativePath in $manifestFiles) {
            $null = $expectedEntries.Add("$addonName/$($relativePath.Replace('\', '/'))")
        }

        foreach ($entry in $archive.Entries) {
            if (-not $expectedEntries.Remove($entry.FullName)) {
                throw "Package validation failed: unexpected or duplicate archive entry '$($entry.FullName)'."
            }
        }
        if ($expectedEntries.Count -gt 0) {
            throw "Package validation failed: missing archive entries: $([string]::Join(', ', $expectedEntries))."
        }
    } finally {
        $archive.Dispose()
    }

    Move-Item -LiteralPath $stagedArchivePath -Destination $archivePath -Force:$Force
    Write-Output "Created release package: $archivePath"
    Write-Output "Included the manifest, $($manifestFiles.Count) manifest-listed runtime files, and the release review sidecar."
} finally {
    if (Test-Path -LiteralPath $stagingRoot -PathType Container) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}
