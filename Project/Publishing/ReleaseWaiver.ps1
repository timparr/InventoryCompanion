function Test-HotfixReleaseWaiver([string]$Content) {
    return $Content -match '(?m)^# Hotfix Release Waiver\s*$'
}

function Get-HotfixRuntimeIdentity([object[]]$Records, [string[]]$RuntimeFiles) {
    $identityLines = [System.Collections.Generic.List[string]]::new()
    foreach ($relativePath in $RuntimeFiles) {
        $matches = @($Records | Where-Object { $_.Path -eq $relativePath })
        if ($matches.Count -ne 1) {
            throw "Hotfix runtime identity requires exactly one record for '$relativePath'."
        }
        $identityLines.Add("$relativePath|$($matches[0].Hash)")
    }
    $identity = (@($identityLines | Sort-Object) -join "`n")
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString(
            $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($identity))
        ).Replace("-", "")
    } finally {
        $sha.Dispose()
    }
}

function Assert-HotfixRuntimeIdentity([string]$Content, [object[]]$Records, [string[]]$RuntimeFiles) {
    $expected = Get-HotfixRuntimeIdentity $Records $RuntimeFiles
    if ($Content -notmatch "(?m)^UAT runtime identity: $([regex]::Escape($expected))\s*$") {
        throw "Hotfix UAT runtime identity does not match the runtime files being staged or published."
    }
}

function Assert-HotfixReleaseWaiver(
    [string]$Content,
    [string]$Version,
    [string]$CandidateHash,
    [ValidateSet("Stage", "Finalize", "Publish")]
    [string]$Phase
) {
    if (-not (Test-HotfixReleaseWaiver $Content)) {
        throw "Release document is not a Hotfix Release Waiver."
    }

    $requiredFields = @(
        "Waiver authorized by: @Tim-P"
        "Full standards review: SKIPPED"
        "Waiver scope: Skip the full release standards review for this hotfix only."
        "Publication approval: NOT GRANTED"
    )
    foreach ($field in $requiredFields) {
        if ($Content -notmatch "(?m)^$([regex]::Escape($field))\s*$") {
            throw "Hotfix waiver must contain '$field'."
        }
    }
    foreach ($field in @("Hotfix reason", "Source identity")) {
        $fieldMatch = [regex]::Match(
            $Content,
            "(?m)^$([regex]::Escape($field)): (?<value>.+\S)\s*$"
        )
        if (-not $fieldMatch.Success -or $fieldMatch.Groups["value"].Value -match '<[^>]+>') {
            throw "Hotfix waiver must identify '$field'."
        }
    }
    if ($Content -notmatch "(?m)^Release version: $([regex]::Escape($Version))\s*$") {
        throw "Hotfix waiver must identify release version $Version."
    }
    $authorizedAt = [regex]::Match($Content, '(?m)^Waiver authorized \(UTC\): (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\s*$')
    $parsedAuthorization = [datetime]::MinValue
    if (-not $authorizedAt.Success -or -not [datetime]::TryParseExact(
        $authorizedAt.Groups[1].Value, "yyyy-MM-dd'T'HH:mm:ss'Z'",
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$parsedAuthorization
    )) {
        throw "Hotfix waiver must contain a valid authorization timestamp in UTC."
    }

    $requiredStatus = if ($Phase -eq "Publish") {
        "Package Verified"
    } else {
        "Authorized"
    }
    if ($Content -notmatch "(?m)^Status: \[Hotfix Waiver - $([regex]::Escape($requiredStatus))\]\s*$") {
        throw "Hotfix waiver status must be [$requiredStatus] for this release action."
    }

    if ($Phase -eq "Stage") {
        if ($Content -notmatch '(?m)^Candidate SHA256: <filled after staging>\s*$') {
            throw "Hotfix waiver must contain the Candidate SHA256 placeholder before staging."
        }
    } elseif ($Content -notmatch "(?m)^Candidate SHA256: $([regex]::Escape($CandidateHash))\s*$") {
        throw "Hotfix waiver must identify the frozen candidate with 'Candidate SHA256: $CandidateHash'."
    }

    if ($Content -notmatch '(?m)^Focused synthetic tests: (\d+)/(\d+) passed\s*$' -or
        $Matches[1] -ne $Matches[2] -or [int]$Matches[2] -lt 1) {
        throw "Hotfix waiver must record a passing focused synthetic-test rate."
    }
    $diagnosticResult = [regex]::Match(
        $Content,
        "(?m)^DEV diagnostic: (\d+)/(\d+) passed; runtime version=$([regex]::Escape($Version))\s*$"
    )
    if (-not $diagnosticResult.Success -or
        $diagnosticResult.Groups[1].Value -ne $diagnosticResult.Groups[2].Value -or
        [int]$diagnosticResult.Groups[2].Value -lt 1) {
        throw "Hotfix waiver must identify passing DEV diagnostic results and their evidence."
    }
    if ($Content -notmatch '(?m)^UAT runtime identity: [A-F0-9]{64}\s*$') {
        throw "Hotfix waiver must identify the runtime source used for DEV UAT."
    }
    $evidenceMatch = [regex]::Match($Content, '(?m)^DEV diagnostic evidence: (.+\S)\s*$')
    if (-not $evidenceMatch.Success) {
        throw "Hotfix waiver must identify passing DEV diagnostic results and their evidence."
    }
    $addonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
    $evidenceRoot = $addonRoot + [System.IO.Path]::DirectorySeparatorChar
    $evidenceRelativePath = $evidenceMatch.Groups[1].Value.Trim().Replace('/', '\')
    if ([System.IO.Path]::IsPathRooted($evidenceRelativePath) -or
        $evidenceRelativePath.StartsWith("..\", [System.StringComparison]::Ordinal)) {
        throw "Hotfix diagnostic evidence must be a repository-relative path."
    }
    $evidencePath = [System.IO.Path]::GetFullPath((Join-Path $addonRoot $evidenceRelativePath))
    if (-not $evidencePath.StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
        throw "Hotfix diagnostic evidence file was not found inside the add-on checkout."
    }
    if ($Content -notmatch "(?m)^DEV UAT report: .+\S\s*$" -or
        $Content -match '(?m)^DEV UAT report: (?:PENDING|<)') {
        throw "Hotfix waiver must record actual DEV UAT results before staging."
    }
    if ($Phase -eq "Stage" -or $Phase -eq "Finalize") {
        if ($Content -notmatch '(?m)^Package verification: PENDING \(Finalize has not run\)\s*$') {
            throw "Hotfix waiver package verification must remain pending until Finalize."
        }
    } elseif ($Content -notmatch '(?m)^Package verification: PASS — Finalize verified the package and retained archive\.\s*$') {
        throw "Hotfix waiver must record successful package verification before publication."
    }
}

function Complete-HotfixReleaseWaiver([string]$Content, [string]$Version, [string]$CandidateHash) {
    Assert-HotfixReleaseWaiver $Content $Version $CandidateHash "Finalize"
    $completed = [regex]::Replace(
        $Content,
        '(?m)^Status: \[Hotfix Waiver - Authorized\]\s*$',
        "Status: [Hotfix Waiver - Package Verified]"
    )
    $completed = [regex]::Replace(
        $completed,
        '(?m)^Package verification: PENDING \(Finalize has not run\)\s*$',
        "Package verification: PASS — Finalize verified the package and retained archive."
    )
    if ($completed -eq $Content) {
        throw "Hotfix waiver package verification could not be completed."
    }
    return $completed
}
