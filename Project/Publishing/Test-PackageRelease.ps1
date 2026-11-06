[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$sourceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("InventoryCompanion-package-test-" + [guid]::NewGuid().ToString("N"))
$liveRoot = Join-Path $fixtureRoot "live"
$addonsRoot = Join-Path $liveRoot "AddOns"
$devRoot = Join-Path $addonsRoot "InventoryCompanion_DEV"
$candidate = Join-Path $addonsRoot "InventoryCompanion"
$savedVariablesDirectory = Join-Path $liveRoot "SavedVariables"
$savedVariables = Join-Path $savedVariablesDirectory "InventoryCompanion.lua"
$devSavedVariables = Join-Path $savedVariablesDirectory "InventoryCompanion_DEV.lua"
$script = Join-Path $devRoot "Project\Publishing\PackageRelease.ps1"
$manifest = Join-Path $devRoot "InventoryCompanion_DEV.txt"
$currentRelease = Join-Path $devRoot "Project\Publishing\Packages\Reviewed\Current release"
$reviewPath = Join-Path $currentRelease "ReleaseReview.md"
$passed = 0
$explorerFolders = [System.Collections.Generic.List[string]]::new()

function Start-Process {
    param([string]$FilePath, [string]$ArgumentList)
    if ($FilePath -ne "explorer.exe") { throw "Unexpected process launch: $FilePath" }
    $explorerFolders.Add($ArgumentList.Trim('"'))
}

function Get-Process {
    param([string[]]$Name, [string]$ErrorAction)
    throw "Packaging must not require ESO to be closed."
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

function Complete-ReviewTemplate([string]$Template, [string]$Version) {
    $result = $Template.
        Replace("<YYYY-MM-DDTHH:mm:ssZ>", "2000-01-01T00:00:00Z").
        Replace("<AI assistant and model name, if available; do not guess>", "Synthetic fixture").
        Replace("<add-on name>", "InventoryCompanion").
        Replace("<DEV commit or source identity>", "synthetic-source").
        Replace("<approved report location, source/candidate version and identity, review date; NONE for a full review without a baseline>",
            "Synthetic approved baseline report; version 1.0.0; SHA256 fixture; 2000-01-01").
        Replace("<DELTA or FULL>", "DELTA").
        Replace("<agreed major.minor.patch version>", $Version).
        Replace("<COMPLETE - findings present / COMPLETE - no findings / INCOMPLETE>", "COMPLETE - no findings").
        Replace("| See documentation review |", "| PASS: See documentation review |").
        Replace("| Certified by @Tim-P |", "| PASS: Certified by @Tim-P |").
        Replace("<Summary of the report.>", "Synthetic packaging report summary.").
        Replace("- <Finding and evidence, or ""No findings identified in the assessed scope."">",
            "- No findings identified in the assessed scope.").
        Replace("<Recommend the next major.minor.patch version and briefly explain why, based on the cumulative unreleased changes. This is a recommendation for discussion, not an agreed version or authorization to change metadata.>",
            "Recommend version $Version for this synthetic fixture.").
        Replace("- <x>/<y> synthetic tests passed", "- 1/1 synthetic tests passed").
        Replace("- <x>/<y> user driven unit tests passed", "- 1/1 user driven unit tests passed").
        Replace("- In-game UAT: <actual results and observations>", "- In-game UAT: <actual results and observations>").
        Replace("- [ ] Record the reviewed DEV source identity and comparison baseline. Use DELTA for routine reviews with an identifiable approved baseline; explain FULL for a first baseline, unavailable/unverifiable baseline, broad architectural changes, or a specific concern requiring complete inspection. A previous ZIP or test report alone is not an approved source-review baseline.",
            "- [x] Record the reviewed DEV source identity and comparison baseline. Synthetic fixture.").
        Replace('- List the examined `.lua` and `.xml` files and the names of methods changed. Include relevant callers/data flows examined; use an appendix if the list is long. Do not list non-Lua/XML files in this section.',
            "- Synthetic fixture reviewed Core\Init.lua and its release version behavior.").
        Replace("(verbatim): No other code changes were present and so they were not rechecked.",
            "No other code changes were present and so they were not rechecked.")
    $lines = $result -split "\r?\n"
    $section = ""
    $checkHeaderSkipped = $false
    $documentationHeaderSkipped = $false
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^### (.+)$') {
            $section = $Matches[1]
            if ($section -eq "Checks performed and results") { $checkHeaderSkipped = $false }
            if ($section -eq "Documentation review") { $documentationHeaderSkipped = $false }
            continue
        }
        if ($lines[$index] -notmatch '^\| .+ \|$' -or $lines[$index] -match '^\|[-| ]+\|$') {
            continue
        }
        $cells = @($lines[$index].Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($section -eq "Checks performed and results") {
            if (-not $checkHeaderSkipped) {
                $checkHeaderSkipped = $true
                continue
            }
            $cells[1] = "No"
            if ([string]::IsNullOrWhiteSpace($cells[2])) { $cells[2] = "PASS: synthetic fixture" }
            $lines[$index] = "| $($cells[0]) | $($cells[1]) | $($cells[2]) |"
        } elseif ($section -eq "Documentation review") {
            if (-not $documentationHeaderSkipped) {
                $documentationHeaderSkipped = $true
                continue
            }
            $cells[2] = "PASS: synthetic fixture"
            $lines[$index] = "| $($cells[0]) | $($cells[1]) | $($cells[2]) |"
        }
    }
    return ($lines -join "`r`n")
}

function Get-CandidateIdentity {
    $statePath = Join-Path $devRoot "Project\Publishing\.release-test\state.json"
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $identity = (@($state.Candidate | ForEach-Object { "$($_.Path)|$($_.Hash)" } | Sort-Object) -join "`n")
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($identity))).Replace("-", "")
    } finally { $sha.Dispose() }
}

try {
    $sourceManifest = Join-Path $sourceRoot "InventoryCompanion_DEV.txt"
    $manifestLines = @(Get-Content -LiteralPath $sourceManifest)
    $sourceDocuments = @(
        "Project\Publishing\Source Documents\ReadMe-Header.bbcode"
        "Project\Publishing\Source Documents\ReadMe-Body.bbcode"
        "Project\Publishing\Source Documents\Changelog.bbcode"
    )
    $paths = @(
        "Project\Publishing\PackageRelease.ps1"
        "Project\Publishing\ReleaseChecklist.md"
        "Project\Publishing\ReleaseReviewTemplate.md"
    ) + $sourceDocuments + @(
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
    $null = New-Item -ItemType Directory -Path $savedVariablesDirectory -Force
    Set-Content -LiteralPath $savedVariables -Value "Synthetic release settings." -Encoding UTF8
    Set-Content -LiteralPath $devSavedVariables -Value "Synthetic development settings." -Encoding UTF8
    $null = New-Item -ItemType Directory -Path $currentRelease -Force

    $header = [System.IO.File]::ReadAllText((Join-Path $devRoot $sourceDocuments[0])).TrimEnd()
    $body = [System.IO.File]::ReadAllText((Join-Path $devRoot $sourceDocuments[1])).TrimStart()
    [System.IO.File]::WriteAllText((Join-Path $currentRelease "ReadMe.bbcode"), "$header`r`n`r`n$body`r`n")
    Copy-Item -LiteralPath (Join-Path $devRoot $sourceDocuments[2]) -Destination (Join-Path $currentRelease "Changelog.bbcode")
    $template = Get-Content -LiteralPath (Join-Path $devRoot "Project\Publishing\ReleaseReviewTemplate.md") -Raw
    $review = Complete-ReviewTemplate $template $version
    Set-Content -LiteralPath $reviewPath -Value $review -Encoding UTF8

    Set-Content -LiteralPath $reviewPath -Value $review.Replace("PASS: See documentation review", "FAIL: See documentation review") -Encoding UTF8
    Assert-Fails { & $script -Action Stage } "unresolved/failed check"
    Assert (-not (Test-Path -LiteralPath $candidate)) "Failed review created a candidate."
    Set-Content -LiteralPath $reviewPath -Value $review.Replace(
        "- No findings identified in the assessed scope.", "- Synthetic unresolved finding."
    ) -Encoding UTF8
    Assert-Fails { & $script -Action Stage } "complete these sections: Findings"
    Assert (-not (Test-Path -LiteralPath $candidate)) "Unresolved finding created a candidate."
    Set-Content -LiteralPath $reviewPath -Value $review -Encoding UTF8

    $originalManifest = [System.IO.File]::ReadAllBytes($manifest)
    $originalManifestText = Get-Content -LiteralPath $manifest -Raw
    foreach ($invalidVersion in @("1.2.100", "1.100.0", "0.0.0", "214749.0.0", "1.2.99")) {
        Set-Content -LiteralPath $manifest -Value ([regex]::Replace($originalManifestText, '(?m)^## Version: .+$', "## Version: $invalidVersion")) -NoNewline
        Assert-Fails { & $script -Action Stage } "AddOnVersion encoding requires"
        Assert (-not (Test-Path -LiteralPath $candidate)) "Invalid version created a candidate."
    }
    [System.IO.File]::WriteAllBytes($manifest, $originalManifest)

    $null = New-Item -ItemType Directory -Path $candidate
    Assert-Fails { & $script -Action Stage } "Refusing to overwrite"
    Remove-Item -LiteralPath $candidate
    $stageOutput = @(& $script -Action Stage)
    Assert (($stageOutput -join "`n") -match "runtime version=$([regex]::Escape($version)), DEV=false") "Staging did not identify the release version."
    Assert (($stageOutput -join "`n") -match "Only runtime files and the prepared combined ReadMe.bbcode") "Staging did not describe its limited file set."
    $backupDirectory = Join-Path $devRoot "SavedVariables"
    $releaseBackups = @(Get-ChildItem -LiteralPath $backupDirectory -Filter "InventoryCompanion-*.lua" -File)
    $devBackups = @(Get-ChildItem -LiteralPath $backupDirectory -Filter "InventoryCompanion_DEV-*.lua" -File)
    Assert ($releaseBackups.Count -eq 1 -and $devBackups.Count -eq 1) "Staging did not back up both SavedVariables files."
    Assert ((Get-FileHash -LiteralPath $savedVariables).Hash -eq (Get-FileHash -LiteralPath $releaseBackups[0].FullName).Hash) "Release SavedVariables backup differs from its source."
    Assert ((Get-FileHash -LiteralPath $devSavedVariables).Hash -eq (Get-FileHash -LiteralPath $devBackups[0].FullName).Hash) "DEV SavedVariables backup differs from its source."
    Assert (Test-Path -LiteralPath (Join-Path $candidate "ReadMe.bbcode")) "Staged combined README is missing."
    Assert (-not (Test-Path -LiteralPath (Join-Path $candidate "Changelog.bbcode"))) "Changelog was staged before UAT."
    Assert (-not (Test-Path -LiteralPath (Join-Path $candidate "UserManual.bbcode"))) "Obsolete manual was staged."
    Assert (-not (Test-Path -LiteralPath (Join-Path $candidate "currency-panel-settings.svg"))) "Manual resource was staged."
    Assert (-not (Test-Path -LiteralPath (Join-Path $candidate "Core\Development.lua"))) "Development bootstrap leaked into candidate."
    $releaseManifest = Get-Content -LiteralPath (Join-Path $candidate "InventoryCompanion.txt") -Raw
    $releaseManifestBytes = [System.IO.File]::ReadAllBytes((Join-Path $candidate "InventoryCompanion.txt"))
    Assert (-not ($releaseManifestBytes.Length -ge 3 -and $releaseManifestBytes[0] -eq 0xEF -and
        $releaseManifestBytes[1] -eq 0xBB -and $releaseManifestBytes[2] -eq 0xBF)) "Release manifest contains a UTF-8 BOM."
    Assert ($releaseManifest -match "(?m)^## AddOnVersion: $([int]$version.Split('.')[0] * 10000 + [int]$version.Split('.')[1] * 100 + [int]$version.Split('.')[2])\s*$") "Release integer version is incorrect."
    $devManifestBytes = [System.IO.File]::ReadAllBytes($manifest)
    Assert (-not ($devManifestBytes.Length -ge 3 -and $devManifestBytes[0] -eq 0xEF -and
        $devManifestBytes[1] -eq 0xBB -and $devManifestBytes[2] -eq 0xBF)) "Updated DEV manifest contains a UTF-8 BOM."
    $devInitBytes = [System.IO.File]::ReadAllBytes((Join-Path $devRoot "Core\Init.lua"))
    Assert (-not ($devInitBytes.Length -ge 3 -and $devInitBytes[0] -eq 0xEF -and
        $devInitBytes[1] -eq 0xBB -and $devInitBytes[2] -eq 0xBF)) "Updated runtime version file contains a UTF-8 BOM."
    $candidateHash = Get-CandidateIdentity
    $stagedReview = Get-Content -LiteralPath $reviewPath -Raw
    Assert ($stagedReview -match "(?m)^Candidate SHA256: $candidateHash\s*$") "Candidate identity was not written into the review."
    Assert ($stagedReview -match "(?m)^Release version: $([regex]::Escape($version))\s*$") "Agreed release version was not recorded."

    $statePath = Join-Path $devRoot "Project\Publishing\.release-test\state.json"
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $candidateFiles = @(Get-ChildItem -LiteralPath $candidate -File -Recurse | ForEach-Object {
        [pscustomobject]@{ Path = $_.FullName.Substring($candidate.Length + 1); Hash = (Get-FileHash -LiteralPath $_.FullName).Hash }
    })
    $tamperedRuntime = Join-Path $candidate "Core\Init.lua"
    $originalRuntime = [System.IO.File]::ReadAllBytes($tamperedRuntime)
    Add-Content -LiteralPath $tamperedRuntime -Value "`n-- synthetic tamper"
    Assert-Fails { & $script -Action Finalize } "candidate files changed"
    [System.IO.File]::WriteAllBytes($tamperedRuntime, $originalRuntime)

    $changelogPath = Join-Path $currentRelease "Changelog.bbcode"
    [System.IO.File]::WriteAllText($changelogPath, "Final post-UAT changelog.")
    [System.IO.File]::WriteAllText((Join-Path $currentRelease "ReadMe.bbcode"), "Final post-UAT combined readme.")
    Assert-Fails { & $script -Action Finalize } "actual in-game UAT results"
    $review = [regex]::Replace($stagedReview, '(?m)^- In-game UAT:.*$', "- In-game UAT: Synthetic fixture confirmed the expected behavior; no real in-game test claimed.")
    Set-Content -LiteralPath $reviewPath -Value $review -Encoding UTF8

    $devInit = Join-Path $devRoot "Core\Init.lua"
    $devManifestBeforeFinalize = (Get-FileHash -LiteralPath $manifest).Hash
    $devInitBeforeFinalize = (Get-FileHash -LiteralPath $devInit).Hash
    $finalizeOutput = @(& $script -Action Finalize)
    $zip = Join-Path $currentRelease "InventoryCompanion-v$version.zip"
    Assert (Test-Path -LiteralPath $zip) "Finalization did not create the ZIP in Current release."
    $zipHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    $handoffDirectory = Join-Path (Join-Path $devRoot "Project\Publishing\Packages\Reviewed") "InventoryCompanion-v$version"
    Assert (Test-Path -LiteralPath $handoffDirectory -PathType Container) "Finalization did not create the versioned archive folder."
    $handoffZip = Join-Path $handoffDirectory (Split-Path $zip -Leaf)
    Assert ((Get-FileHash -LiteralPath $handoffZip -Algorithm SHA256).Hash -eq $zipHash) "Versioned ZIP copy differs from Current release ZIP."
    foreach ($fileName in @("ReadMe.bbcode", "Changelog.bbcode", "ReleaseReview.md")) {
        Assert ((Get-FileHash -LiteralPath (Join-Path $handoffDirectory $fileName)).Hash -eq
            (Get-FileHash -LiteralPath (Join-Path $candidate $fileName)).Hash) "Versioned documentation differs: $fileName"
    }
    Assert (-not (Test-Path -LiteralPath (Join-Path $handoffDirectory "UserManual.bbcode"))) "Obsolete manual entered the versioned archive."
    Assert ($finalizeOutput -contains "Archive SHA256: $zipHash") "Finalization did not report the archive hash."
    Assert ($finalizeOutput -contains "Candidate file-set SHA256: $candidateHash") "Finalization did not report the staged candidate hash."
    Assert ($explorerFolders.Count -eq 1 -and $explorerFolders[0] -eq $handoffDirectory) "Finalization did not open the versioned archive folder."
    Assert ((Get-FileHash -LiteralPath $manifest).Hash -eq $devManifestBeforeFinalize) "Finalization changed DEV manifest metadata."
    Assert ((Get-FileHash -LiteralPath $devInit).Hash -eq $devInitBeforeFinalize) "Finalization changed DEV runtime metadata."
    Assert ((Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json).Completed) "Finalization did not mark the test complete."
    Assert-Fails { & $script -Action Finalize } "already finalized"

    $extracted = Join-Path $fixtureRoot "extracted"
    Expand-Archive -LiteralPath $zip -DestinationPath $extracted
    $extractedAddon = Join-Path $extracted "InventoryCompanion"
    $packagedFiles = @(Get-ChildItem -LiteralPath $extractedAddon -File -Recurse)
    $expectedPaths = @((Get-ChildItem -LiteralPath $candidate -File -Recurse | ForEach-Object { $_.FullName.Substring($candidate.Length + 1) }) | Sort-Object)
    $actualPaths = @($packagedFiles | ForEach-Object { $_.FullName.Substring($extractedAddon.Length + 1) } | Sort-Object)
    Assert (@(Compare-Object $expectedPaths $actualPaths).Count -eq 0) "ZIP entries do not match the finalized test installation."
    foreach ($file in $packagedFiles) {
        $relativePath = $file.FullName.Substring($extractedAddon.Length + 1)
        Assert ((Get-FileHash -LiteralPath $file.FullName).Hash -eq (Get-FileHash -LiteralPath (Join-Path $candidate $relativePath)).Hash) "ZIP differs from the finalized test file: $relativePath"
    }
    $zipReview = Get-Content -LiteralPath (Join-Path $extractedAddon "ReleaseReview.md") -Raw
    Assert ($zipReview -match '(?m)^### Test results\s*$') "Final report lost the existing Test results section."
    Assert ($zipReview -notmatch '(?m)^## User testing\s*$') "Finalization added an extra report section."
    Assert ($zipReview -match 'Synthetic fixture confirmed the expected behavior') "Final report omitted the UAT result."
    Assert (-not (Test-Path -LiteralPath (Join-Path $extractedAddon "UserManual.bbcode"))) "ZIP included the obsolete manual."
    Assert (-not (Test-Path -LiteralPath (Join-Path $extractedAddon "tracked-items-editor.svg"))) "ZIP included a manual schematic."

    & $script -Action Cancel | Out-Null
    Assert (-not (Test-Path -LiteralPath $candidate)) "Cancellation left the managed test installation."
    Assert (Test-Path -LiteralPath $zip) "Cancellation removed the verified release ZIP."

    Write-Output "PackageRelease regression tests passed: $passed assertions."
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}
