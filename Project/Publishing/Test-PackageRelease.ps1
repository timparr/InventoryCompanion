[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$sourceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("InventoryCompanion-package-test-" + [guid]::NewGuid().ToString("N"))
$devRoot = Join-Path $fixtureRoot "InventoryCompanion_DEV"
$candidate = Join-Path $fixtureRoot "InventoryCompanion"
$script = Join-Path $devRoot "Project\Publishing\PackageRelease.ps1"
$manifest = Join-Path $devRoot "InventoryCompanion_DEV.txt"
$passed = 0
$explorerFolders = [System.Collections.Generic.List[string]]::new()

function Start-Process {
    param([string]$FilePath, [string]$ArgumentList)
    if ($FilePath -ne "explorer.exe") { throw "Unexpected process launch: $FilePath" }
    $explorerFolders.Add($ArgumentList.Trim('"'))
}

# Every package action below targets the temporary fixture, not the live installation.
function Get-Process {
    param([string[]]$Name, [string]$ErrorAction)
    return @()
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:passed++
}

function Assert-Fails([scriptblock]$Command, [string]$ExpectedMessage) {
    try {
        & $Command | Out-Null
    } catch {
        Assert ($_.Exception.Message -like "*$ExpectedMessage*") "Unexpected failure: $($_.Exception.Message)"
        return
    }
    throw "Expected failure containing: $ExpectedMessage"
}

function Get-FixtureCandidateHash {
    $fixtureState = Get-Content -LiteralPath (Join-Path $devRoot "Project\Publishing\.release-test\state.json") -Raw | ConvertFrom-Json
    $identity = (@($fixtureState.Candidate | ForEach-Object { "$($_.Path)|$($_.Hash)" } | Sort-Object) -join "`n")
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($identity))).Replace("-", "")
    } finally { $sha.Dispose() }
}

try {
    $sourceManifest = Join-Path $sourceRoot "InventoryCompanion_DEV.txt"
    $manifestLines = @(Get-Content -LiteralPath $sourceManifest)
    $paths = @("Project\Publishing\PackageRelease.ps1", "Project\Publishing\ReleaseChecklist.md",
        "Project\Publishing\ReleaseReviewTemplate.md", "readme.md") + @(
        $manifestLines | ForEach-Object { $_.Trim().Replace('/', '\') } |
            Where-Object { $_ -and -not $_.StartsWith("#") -and -not $_.StartsWith("--") }
    )
    foreach ($relativePath in $paths) {
        $destination = Join-Path $devRoot $relativePath
        $null = New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force
        Copy-Item -LiteralPath (Join-Path $sourceRoot $relativePath) -Destination $destination
    }
    Copy-Item -LiteralPath $sourceManifest -Destination $manifest
    $version = [regex]::Match(($manifestLines -join "`n"), '(?m)^## Version: (.+)$').Groups[1].Value.Trim()

    $originalManifest = [System.IO.File]::ReadAllBytes($manifest)
    Add-Content -LiteralPath $manifest -Value "`n..\outside.lua"
    Assert-Fails { & $script -Action Stage } "must stay inside"
    Assert (-not (Test-Path -LiteralPath $candidate)) "Invalid manifest created a candidate."
    [System.IO.File]::WriteAllBytes($manifest, $originalManifest)
    Add-Content -LiteralPath $manifest -Value "`nCore\..\Core\Init.lua"
    Assert-Fails { & $script -Action Stage } "Duplicate manifest entry"
    [System.IO.File]::WriteAllBytes($manifest, $originalManifest)
    Add-Content -LiteralPath $manifest -Value "`nCore\Missing.lua"
    Assert-Fails { & $script -Action Stage } "Manifest-listed file does not exist"
    [System.IO.File]::WriteAllBytes($manifest, $originalManifest)

    $null = New-Item -ItemType Directory -Path $candidate
    Assert-Fails { & $script -Action Stage } "Refusing to overwrite"
    Remove-Item -LiteralPath $candidate
    $stageOutput = @(& $script -Action Stage)
    Assert (($stageOutput -join "`n") -match 'ESO may remain open during finalization') "Staging gives incorrect finalization instructions."
    Assert (Test-Path -LiteralPath $manifest) "Staging disabled the development manifest."
    $parts = $version.Split(".")
    $expectedNextBuild = "{0}.{1}.{2}" -f $parts[0], $parts[1], (1 + $(if ($parts.Count -gt 2) { [int]$parts[2] } else { 0 }))
    Assert ((Get-Content -LiteralPath $manifest -Raw) -match ('## Version: ' + [regex]::Escape($expectedNextBuild))) "Staging did not increment the development build."
    $postCutManifestHash = (Get-FileHash -LiteralPath $manifest).Hash
    Assert (Test-Path -LiteralPath (Join-Path $candidate "InventoryCompanion.txt")) "Release manifest is missing."
    Assert (-not (Test-Path -LiteralPath (Join-Path $candidate "Core\Development.lua"))) "Development bootstrap leaked into candidate."
    $releaseManifest = Get-Content -LiteralPath (Join-Path $candidate "InventoryCompanion.txt") -Raw
    Assert ($releaseManifest -notmatch '\[DEV\]|Development\.lua') "Release manifest contains development markers."
    $releaseFiles = @($releaseManifest -split '\r?\n' | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") -and -not $_.StartsWith("--") })
    Assert ($releaseFiles[0] -eq "Core/LoadCheck.lua") "Duplicate-load warning is not first in release."
    Assert ($manifestLines.IndexOf("Core/LoadCheck.lua") -lt $manifestLines.IndexOf("Core/Development.lua")) "Development bootstrap runs before duplicate detection."
    foreach ($relativePath in $paths | Where-Object { $_ -like "*.lua" -and $_ -ne "Core\Development.lua" }) {
        Assert ((Get-FileHash -LiteralPath (Join-Path $sourceRoot $relativePath)).Hash -eq
            (Get-FileHash -LiteralPath (Join-Path $candidate $relativePath)).Hash) "Runtime changed during staging: $relativePath"
    }
    Assert-Fails { & $script -Action Stage } "already managed"
    Assert-Fails { & $script -Action Finalize } "requires -TestResults"
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "Complete ReleaseReview.md"
    $extraPath = Join-Path $candidate "extra.lua"
    Set-Content -LiteralPath $extraPath -Value "-- unexpected"
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "candidate files changed"
    Remove-Item -LiteralPath $extraPath
    $init = Join-Path $candidate "Core\Init.lua"
    $originalInit = [System.IO.File]::ReadAllBytes($init)
    Add-Content -LiteralPath $init -Value "-- changed"
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "candidate files changed"
    [System.IO.File]::WriteAllBytes($init, $originalInit)
    $readme = Join-Path $devRoot "readme.md"
    $originalReadme = [System.IO.File]::ReadAllBytes($readme)
    Add-Content -LiteralPath $readme -Value "Changed description"
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "Complete ReleaseReview.md"
    [System.IO.File]::WriteAllBytes($readme, $originalReadme)
    $junctionTarget = Join-Path $fixtureRoot "junction-target"
    $null = New-Item -ItemType Directory -Path $junctionTarget
    $junction = Join-Path $candidate "junction"
    $null = New-Item -ItemType Junction -Path $junction -Target $junctionTarget
    Assert-Fails { & $script -Action Cancel } "junctions or symbolic links"
    Assert (Test-Path -LiteralPath $junctionTarget) "Junction target was removed."
    Remove-Item -LiteralPath $junction
    & $script -Action Cancel | Out-Null
    Assert ((Get-FileHash -LiteralPath $manifest).Hash -eq $postCutManifestHash) "Cancellation changed development."
    Assert (-not (Test-Path -LiteralPath $candidate)) "Cancellation left the candidate installed."

    & $script -Action Stage | Out-Null
    $version = [regex]::Match((Get-Content -LiteralPath (Join-Path $candidate "InventoryCompanion.txt") -Raw), '(?m)^## Version: (.+)$').Groups[1].Value.Trim()
    $testedFiles = @(Get-ChildItem -LiteralPath $candidate -Recurse -File | ForEach-Object {
        [pscustomobject]@{ Path = $_.FullName.Substring($candidate.Length + 1); Hash = (Get-FileHash -LiteralPath $_.FullName).Hash }
    })
    $template = Get-Content -LiteralPath (Join-Path $devRoot "Project\Publishing\ReleaseReviewTemplate.md") -Raw
    Assert ($template -notmatch 'InventoryCompanion|Tim-P|/ictest|/icclean|PackageRelease\.ps1|bag scan|craft-bag|Currency messages:') "Generic review template contains project-specific assumptions."
    Assert ($template -match 'state explicitly when no suite exists') "Template must account for add-ons without automated tests."
    Assert ($template -match 'specific code comment as the author''s assertion') "Template must allow attributed mitigation rationale."
    $review = $template.Replace("<AI assistant and model name, if available; do not guess>", "Synthetic fixture").
        Replace("<human author/checker>", "Synthetic fixture").
        Replace("<manifest version>", $version).
        Replace("<PENDING or APPROVED>", "APPROVED").Replace("- [ ]", "- [x]")
    $candidateHash = Get-FixtureCandidateHash
    $review = $review.Replace("<candidate SHA256>", $candidateHash)
    $reviewPath = Join-Path $devRoot "ReleaseReview.md"
    Set-Content -LiteralPath $reviewPath -Value ($review.Replace("<YYYY-MM-DDTHH:mm:ssZ>", "invalid"))
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "valid 'Reviewed"
    Set-Content -LiteralPath $reviewPath -Value ($review.Replace("<YYYY-MM-DDTHH:mm:ssZ>", [datetime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")))
    Set-Content -LiteralPath $reviewPath -Value ((Get-Content -LiteralPath $reviewPath -Raw).Replace($candidateHash, "WRONG"))
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "identify the frozen candidate"
    Set-Content -LiteralPath $reviewPath -Value ($review.Replace("<YYYY-MM-DDTHH:mm:ssZ>", "2000-01-01T00:00:00Z"))
    $completeReview = Get-Content -LiteralPath $reviewPath -Raw
    Set-Content -LiteralPath $reviewPath -Value ($completeReview.Replace("### Events and lifecycle", "### Missing section"))
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "Release review is incomplete: Events and lifecycle"
    Set-Content -LiteralPath $reviewPath -Value ($completeReview + "`n- [ ] Unfinished requirement")
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "unchecked requirements"
    Set-Content -LiteralPath $reviewPath -Value ([regex]::Replace($completeReview, '(?m)^- \[x\] \*\*AI \+ TEST\*\* For frequently firing events,.*\r?\n', ""))
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "Release review is incomplete: Events and lifecycle"
    Set-Content -LiteralPath $reviewPath -Value ($completeReview.Replace("### Test discovery and coverage", "### Missing section"))
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "Release review is incomplete: Test discovery and coverage"
    Set-Content -LiteralPath $reviewPath -Value ($completeReview.Replace("### Performance and queued operations", "### Missing section"))
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "Release review is incomplete: Performance and queued operations"
    Set-Content -LiteralPath $reviewPath -Value $completeReview
    # Development changes and old source timestamps cannot invalidate a frozen candidate.
    Add-Content -LiteralPath (Join-Path $devRoot "Core\Tests.lua") -Value "`n-- development-only change"
    Remove-Item -LiteralPath $readme
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" -OutputDirectory $candidate } "outside the staged installation"
    $packageDirectory = Join-Path $devRoot "Project\Publishing\Packages"
    $null = New-Item -ItemType Directory -Path $packageDirectory -Force
    $zip = Join-Path $packageDirectory "InventoryCompanion-v$version.zip"
    Set-Content -LiteralPath $zip -Value "existing package"
    $oldArchiveHash = (Get-FileHash -LiteralPath $zip).Hash
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "Package already exists"
    Assert ((Get-FileHash -LiteralPath $zip).Hash -eq $oldArchiveHash) "Existing package was overwritten."
    Assert (Test-Path -LiteralPath $candidate) "Failed finalization removed the candidate."
    $finalizeOutput = @(& $script -Action Finalize -TestResults "Synthetic packaging fixture only; no in-game test claimed." -Force)
    Assert (Test-Path -LiteralPath $zip) "Finalization did not create the ZIP."
    $zipHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    Assert ($finalizeOutput -contains "Archive SHA256: $zipHash") "Finalization did not report the actual ZIP hash."
    Assert ($finalizeOutput -contains "Candidate file-set SHA256: $candidateHash") "Finalization did not distinguish the candidate hash."
    Assert ($explorerFolders.Count -eq 1 -and $explorerFolders[0] -eq $packageDirectory) "Finalization did not open the package output folder."
    $parts = $version.Split(".")
    $expectedNextRelease = "{0}.{1}.0" -f $parts[0], (1 + [int]$parts[1])
    Assert ((Get-Content -LiteralPath $manifest -Raw) -match ('## Version: ' + [regex]::Escape($expectedNextRelease))) "Finalization did not advance the development minor version."
    Assert ((Get-Content -LiteralPath (Join-Path $devRoot "Core\Init.lua") -Raw) -match ('Version = "' + [regex]::Escape($expectedNextRelease) + '"')) "Runtime and manifest versions diverged."
    [System.IO.File]::WriteAllBytes($readme, $originalReadme)
    Assert (Test-Path -LiteralPath $candidate) "Finalization removed the gameplay release installation."
    Assert (@(Get-ChildItem -LiteralPath $candidate -Recurse -File).Count -eq $testedFiles.Count) "Finalization modified the installed candidate."
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "already finalized"
    Assert-Fails { & $script -Action Stage } "already managed"
    $extracted = Join-Path $fixtureRoot "extracted"
    Expand-Archive -LiteralPath $zip -DestinationPath $extracted
    $extractedAddon = Join-Path $extracted "InventoryCompanion"
    foreach ($file in $testedFiles) {
        Assert ((Get-FileHash -LiteralPath (Join-Path $extractedAddon $file.Path)).Hash -eq $file.Hash) "ZIP differs from tested bytes: $($file.Path)"
    }
    Assert (@(Get-ChildItem -LiteralPath $extractedAddon -Recurse -File).Count -eq ($testedFiles.Count + 1)) "ZIP has unexpected contents."
    Assert ((Get-Content -LiteralPath (Join-Path $extractedAddon "ReleaseReview.md") -Raw) -match "Synthetic packaging fixture only") "Test confirmation is missing."
    Assert ((Get-Content -LiteralPath $reviewPath -Raw) -match "Staged release test confirmation") "Final review was not persisted."

    & $script -Action Cancel | Out-Null
    & $script -Action Stage | Out-Null
    $housekeepingVersion = [regex]::Match((Get-Content -LiteralPath (Join-Path $candidate "InventoryCompanion.txt") -Raw), '(?m)^## Version: (.+)$').Groups[1].Value.Trim()
    $housekeepingHash = Get-FixtureCandidateHash
    $housekeepingReview = $completeReview.Replace("Release version: $version", "Release version: $housekeepingVersion").
        Replace($candidateHash, $housekeepingHash)
    Set-Content -LiteralPath $reviewPath -Value $housekeepingReview
    $devInit = Join-Path $devRoot "Core\Init.lua"
    $validDevInit = [System.IO.File]::ReadAllBytes($devInit)
    $devManifestBeforeFailure = (Get-FileHash -LiteralPath $manifest).Hash
    $candidateInitBeforeFailure = (Get-FileHash -LiteralPath (Join-Path $candidate "Core\Init.lua")).Hash
    Set-Content -LiteralPath $devInit -Value ([regex]::Replace((Get-Content -LiteralPath $devInit -Raw), '(?m)^    Version = .+,\r?\n', ""))
    Assert-Fails { & $script -Action Finalize -TestResults "Fixture housekeeping failure; no in-game run." } "development-version housekeeping failed"
    $housekeepingZip = Join-Path $packageDirectory "InventoryCompanion-v$housekeepingVersion.zip"
    Assert (Test-Path -LiteralPath $housekeepingZip) "Housekeeping failure lost the verified ZIP."
    $completedState = Get-Content -LiteralPath (Join-Path $devRoot "Project\Publishing\.release-test\state.json") -Raw | ConvertFrom-Json
    Assert $completedState.Completed "Housekeeping failure did not preserve completed finalization."
    Assert ((Get-FileHash -LiteralPath $manifest).Hash -eq $devManifestBeforeFailure) "Failed housekeeping partially changed the DEV manifest."
    Assert ((Get-FileHash -LiteralPath (Join-Path $candidate "Core\Init.lua")).Hash -eq $candidateInitBeforeFailure) "Housekeeping failure modified installed runtime bytes."
    Assert-Fails { & $script -Action Finalize -TestResults "Do not repeat" } "already finalized"
    $failureExtracted = Join-Path $fixtureRoot "housekeeping-extracted"
    Expand-Archive -LiteralPath $housekeepingZip -DestinationPath $failureExtracted
    Assert ((Get-FileHash -LiteralPath (Join-Path $failureExtracted "InventoryCompanion\Core\Init.lua")).Hash -eq $candidateInitBeforeFailure) "Verified ZIP used changed DEV bytes."
    [System.IO.File]::WriteAllBytes($devInit, $validDevInit)
    & $script -Action Cancel | Out-Null

    & $script -Action Stage | Out-Null
    $stateFailureVersion = [regex]::Match((Get-Content -LiteralPath (Join-Path $candidate "InventoryCompanion.txt") -Raw), '(?m)^## Version: (.+)$').Groups[1].Value.Trim()
    $stateFailureHash = Get-FixtureCandidateHash
    Set-Content -LiteralPath $reviewPath -Value ($completeReview.Replace("Release version: $version", "Release version: $stateFailureVersion").
        Replace($candidateHash, $stateFailureHash))
    $fixtureStatePath = Join-Path $devRoot "Project\Publishing\.release-test\state.json"
    $stateLock = [System.IO.File]::Open($fixtureStatePath, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try {
        Assert-Fails { & $script -Action Finalize -TestResults "Fixture completion-state failure; no in-game run." } "completion-state recording failed"
    } finally { $stateLock.Dispose() }
    $stateFailureZip = Join-Path $packageDirectory "InventoryCompanion-v$stateFailureVersion.zip"
    Assert (Test-Path -LiteralPath $stateFailureZip) "Completion-state failure lost the verified ZIP."
    $uncompletedState = Get-Content -LiteralPath $fixtureStatePath -Raw | ConvertFrom-Json
    Assert (-not $uncompletedState.Completed) "Locked completion state should remain unchanged."
    Assert (Test-Path -LiteralPath (Join-Path $candidate "Core\Init.lua")) "Completion-state failure removed the installed candidate."
    Assert-Fails { & $script -Action Finalize -TestResults "Do not overwrite existing ZIP" } "Package already exists"
    & $script -Action Cancel | Out-Null

    & $script -Action Stage | Out-Null
    Assert-Fails { & $script -Action Finalize -TestResults "fixture only" } "identify the frozen candidate"
    # Simulate cleanup interrupted after removing the candidate.
    Remove-Item -LiteralPath $candidate -Recurse -Force
    & $script -Action Cancel | Out-Null
    Assert (Test-Path -LiteralPath $manifest) "Interrupted cleanup affected development."
    & $script -Action Stage | Out-Null
    Add-Content -LiteralPath $manifest -Value "`n-- development work during release testing"
    & $script -Action Cancel | Out-Null
    Assert (-not (Test-Path -LiteralPath $candidate)) "Cancellation failed after development changed."
    Assert ((Get-Content -LiteralPath $manifest -Raw) -match "development work during release testing") "Cancellation reverted development work."
    Write-Output "PASS: $passed packaging assertions. No live installation or saved variables were modified."
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}
