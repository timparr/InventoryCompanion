#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [ValidateSet("SaveToken", "List", "Test", "Publish")]
    [string]$Action = "Test",
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Id,
    [ValidatePattern('^\d+\.\d+(?:\.\d+)?$')]
    [string]$Compatible,
    [switch]$UseCurl
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$tokenPath = Join-Path $env:LOCALAPPDATA "InventoryCompanion\ESOUI-token.clixml"

function Invoke-ESOUI([string]$Endpoint, [hashtable]$Form) {
    if ($UseCurl) {
        if ($Endpoint -ne "list.json" -or $null -ne $Form) {
            throw "-UseCurl is supported only with -Action List for transport diagnosis."
        }
        $output = @("x-api-token: $token" | curl.exe --silent --show-error --header "@-" --max-redirs 0 --write-out "`n%{http_code}" "https://api.esoui.com/addons/list.json")
        if ($LASTEXITCODE -ne 0) {
            throw "curl failed with exit code $LASTEXITCODE."
        }
        $response = [pscustomobject]@{
            StatusCode = [int]$output[-1]
            Content = $output[0..($output.Count - 2)] -join "`n"
        }
    } else {
        $request = @{
            Uri = "https://api.esoui.com/addons/$Endpoint"
            Headers = @{ "x-api-token" = $token }
            MaximumRedirection = 0
            SkipHttpErrorCheck = $true
        }
        if ($null -ne $Form) {
            $request.Method = "Post"
            $request.Form = $Form
        }
        try {
            $response = Invoke-WebRequest @request
        } catch {
            throw "ESOUI request failed before a response was received. No automatic retry was made; check ESOUI before retrying a live submission."
        }
    }
    $expectedStatus = if ($null -eq $Form) { 200 } else { 202 }
    if ([int]$response.StatusCode -ne $expectedStatus) {
        $detail = ([string]$response.Content).Replace($token, "[redacted]")
        $detail = [regex]::Replace($detail, '[\x00-\x1F\x7F]', ' ')
        if ([string]::IsNullOrWhiteSpace($detail)) {
            $detail = "(empty response body)"
        } elseif ($detail.Length -gt 2000) {
            $detail = $detail.Substring(0, 2000) + " [truncated]"
        }
        throw "ESOUI $Endpoint returned HTTP $($response.StatusCode), expected $expectedStatus. Server response: $detail No automatic retry was made."
    }
    $textReader = [System.IO.StringReader]::new([string]$response.Content)
    $jsonReader = [Newtonsoft.Json.JsonTextReader]::new($textReader)
    $jsonReader.SupportMultipleContent = $true
    try {
        $documents = @(
            while ($jsonReader.Read()) {
                $document = [Newtonsoft.Json.Linq.JToken]::ReadFrom($jsonReader)
                $document.ToString([Newtonsoft.Json.Formatting]::None)
            }
        )
    } finally {
        $jsonReader.Close()
        $textReader.Dispose()
    }
    if ($documents.Count -eq 2 -and $Endpoint -in @("updatetest", "update")) {
        $compatibility = @($documents[0] | ConvertFrom-Json)
        if ($Compatible -notin @($compatibility | ForEach-Object { $_.id })) {
            throw "ESOUI compatibility must be one of: $($compatibility.id -join ', '). No live submission was made."
        }
        $result = $documents[1] | ConvertFrom-Json
    } elseif ($documents.Count -eq 1) {
        $result = $documents[0] | ConvertFrom-Json
    } else {
        throw "ESOUI returned an unexpected number of JSON documents: $($documents.Count)."
    }
    if ($null -eq $result) {
        throw "ESOUI returned an empty response."
    }
    if ($null -ne $result.PSObject.Properties["ERROR"]) {
        throw "ESOUI rejected the request: $(([string]$result.ERROR).Replace($token, '[redacted]'))"
    }
    return $result
}

$form = $null
if ($UseCurl -and $Action -ne "List") {
    throw "-UseCurl requires -Action List; it never uploads."
}
if ($Action -in @("Test", "Publish")) {
    if (-not $PSBoundParameters.ContainsKey("Id") -or -not $PSBoundParameters.ContainsKey("Compatible")) {
        throw "Test and Publish require -Id (ESOUI addon ID) and -Compatible (ESOUI game version, not API number)."
    }
    $state = Get-Content -LiteralPath (Join-Path $PSScriptRoot ".release-test\state.json") -Raw | ConvertFrom-Json
    if ($state.Completed -ne $true -or $state.Version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Finalize the approved package before uploading."
    }
    $version = $state.Version
    $reviewedRoot = Join-Path $PSScriptRoot "Packages\Reviewed"
    $handoff = Join-Path $reviewedRoot "InventoryCompanion-v$version"
    $archiveName = "InventoryCompanion-v$version.zip"
    foreach ($name in @($archiveName, "ReadMe.bbcode", "Changelog.bbcode", "ReleaseReview.md")) {
        $hash = (Get-FileHash -LiteralPath (Join-Path $handoff $name) -Algorithm SHA256).Hash
        $currentHash = (Get-FileHash -LiteralPath (Join-Path $reviewedRoot "Current release\$name") -Algorithm SHA256).Hash
        if ($hash -ne $currentHash) {
            throw "Finalized handoff differs from Current release: $name"
        }
    }
    $review = Get-Content -LiteralPath (Join-Path $handoff "ReleaseReview.md") -Raw
    if ($review -notmatch '(?m)^Status: \[Approved for Release\]\s*$' -or
        $review -notmatch "(?m)^Release version: $([regex]::Escape($version))\s*$") {
        throw "The finalized review must approve this version for release."
    }
    $form = @{
        id = [string]$Id
        version = $version
        compatible = $Compatible
        description = [System.IO.File]::ReadAllText((Join-Path $handoff "ReadMe.bbcode"))
        changelog = [System.IO.File]::ReadAllText((Join-Path $handoff "Changelog.bbcode"))
        updatefile = Get-Item -LiteralPath (Join-Path $handoff $archiveName)
    }
    Write-Output "Package: $($form.updatefile.FullName)"
    Write-Output "Version: $version; ESOUI ID: $Id; compatible: $Compatible"
    Write-Output "ZIP SHA256: $((Get-FileHash -LiteralPath $form.updatefile.FullName -Algorithm SHA256).Hash)"
}

$target = switch ($Action) {
    "SaveToken" { $tokenPath }
    "List" { "ESOUI addon list" }
    default { "ESOUI addon $Id, version $version" }
}
$operation = switch ($Action) {
    "SaveToken" { "Store the API token encrypted for this Windows user on this machine" }
    "List" { "Read authorized addon IDs" }
    "Test" { "Upload ZIP, description and changelog to the non-saving test endpoint" }
    "Publish" { "Test, then submit a LIVE update with ZIP, description and changelog" }
}
if (-not $PSCmdlet.ShouldProcess($target, $operation)) {
    return
}

$token = $env:ESOUI_TOKEN
try {
    if ($Action -eq "SaveToken" -and -not $IsWindows) {
        throw "Encrypted token storage requires Windows DPAPI."
    }
    if ($Action -eq "SaveToken" -or [string]::IsNullOrWhiteSpace($token)) {
        if ($Action -ne "SaveToken" -and (Test-Path -LiteralPath $tokenPath -PathType Leaf)) {
            if (-not $IsWindows) {
                throw "The stored API token requires Windows DPAPI."
            }
            $secureToken = Import-Clixml -LiteralPath $tokenPath
            if ($secureToken -isnot [System.Security.SecureString]) {
                throw "The stored API token is not an encrypted SecureString. Run -Action SaveToken to replace it."
            }
        } else {
            $secureToken = Read-Host "ESOUI API token (hidden; paste with Ctrl+Shift+V)" -AsSecureString
        }
        try {
            $token = [System.Net.NetworkCredential]::new("", $secureToken).Password
        } finally {
            $secureToken.Dispose()
        }
    }
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "An ESOUI API token is required."
    }
    $trimmedToken = $token.Trim()
    if ($trimmedToken -ne $token) {
        Write-Warning "Removed surrounding whitespace from the API token."
        $token = $trimmedToken
    }
    $invalidCharacters = @(
        for ($index = 0; $index -lt $token.Length; $index++) {
            $character = $token[$index]
            if ([char]::IsWhiteSpace($character) -or [int]$character -lt 0x21 -or
                [int]$character -gt 0x7E -or $character -eq '"' -or $character -eq "'") {
                $kind = switch ([int]$character) {
                    0x09 { "TAB" }
                    0x0A { "LINE FEED" }
                    0x0D { "CARRIAGE RETURN" }
                    0x20 { "SPACE" }
                    0x22 { "DOUBLE QUOTE" }
                    0x27 { "SINGLE QUOTE" }
                    default { [char]::GetUnicodeCategory($character).ToString() }
                }
                "position $($index + 1): U+$('{0:X4}' -f [int]$character) ($kind)"
            }
        }
    )
    if ($invalidCharacters.Count -gt 0) {
        throw "Invalid token characters (1-based UTF-16 positions after trimming): $($invalidCharacters -join '; '). Copy only the token value; no request was sent."
    }
    if ($Action -eq "SaveToken") {
        $secureToken = ConvertTo-SecureString -String $token -AsPlainText -Force
        try {
            $null = New-Item -ItemType Directory -Path (Split-Path $tokenPath -Parent) -Force
            $secureToken | Export-Clixml -LiteralPath $tokenPath
        } finally {
            $secureToken.Dispose()
        }
        Write-Output "API token stored with Windows DPAPI encryption at $tokenPath. No request was sent."
        return
    }
    if ($Action -eq "List") {
        Invoke-ESOUI "list.json" $null
        return
    }
    $null = Invoke-ESOUI "updatetest" $form
    Write-Output "ESOUI accepted the test upload; no listing changes were saved."
    if ($Action -eq "Publish") {
        $null = Invoke-ESOUI "update" $form
        Write-Output "ESOUI accepted the live update. Verify the public listing before confirming publication."
    }
} finally {
    $token = $null
    $trimmedToken = $null
}
