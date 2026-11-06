#Requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("InventoryCompanion-upload-test-" + [guid]::NewGuid().ToString("N"))
$originalToken = $env:ESOUI_TOKEN
$originalLocalAppData = $env:LOCALAPPDATA
$requests = [System.Collections.Generic.List[object]]::new()
$status = 202
$body = '{"SUCCESS":"Accepted"}'
$networkFailure = $false
$assertions = @{ Passed = 0 }

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $assertions.Passed++
}

function Assert-Fails([scriptblock]$Command, [string]$Message) {
    try {
        & $Command | Out-Null
    } catch {
        Assert ($_.Exception.Message.Contains($Message)) "Unexpected failure: $($_.Exception.Message)"
        return
    }
    throw "Expected failure containing: $Message"
}

function Invoke-WebRequest {
    param($Uri, $Headers, $MaximumRedirection, $SkipHttpErrorCheck, $Method, $Form)
    Assert ($Uri.StartsWith("https://api.esoui.com/addons/")) "Unexpected API host."
    Assert ($Headers["x-api-token"] -eq "synthetic-token") "Missing token header."
    Assert ($MaximumRedirection -eq 0) "Credential-bearing redirects must be disabled."
    $requests.Add([pscustomobject]@{ Uri = $Uri; Method = $Method; Form = $Form })
    if ($networkFailure) { throw "Synthetic transport failure with synthetic-token" }
    return [pscustomobject]@{ StatusCode = $status; Content = $body }
}

function curl.exe {
    $header = @($input) -join ""
    Assert ($header -eq "x-api-token: synthetic-token") "curl must receive the token through stdin."
    Assert (-not ($args -join " ").Contains("synthetic-token")) "Token must not appear in curl arguments."
    $global:LASTEXITCODE = 0
    '[{"id":123,"title":"Synthetic addon"}]'
    '200'
}

function Read-Host {
    param([string]$Prompt, [switch]$AsSecureString)
    Assert $AsSecureString.IsPresent "Token entry must be hidden."
    return ConvertTo-SecureString "synthetic-token" -AsPlainText -Force
}

try {
    $null = New-Item -ItemType Directory -Path $fixture
    $env:LOCALAPPDATA = $fixture
    $scriptPath = Join-Path $fixture "Publish-ESOUI.ps1"
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Publish-ESOUI.ps1") -Destination $scriptPath
    $stateRoot = Join-Path $fixture ".release-test"
    $current = Join-Path $fixture "Packages\Reviewed\Current release"
    $handoff = Join-Path $fixture "Packages\Reviewed\InventoryCompanion-v1.2.3"
    foreach ($directory in @($stateRoot, $current, $handoff)) {
        $null = New-Item -ItemType Directory -Path $directory -Force
    }
    $statePath = Join-Path $stateRoot "state.json"
    '{"Completed":true,"Version":"1.2.3"}' | Set-Content -LiteralPath $statePath
    $documents = @{
        "InventoryCompanion-v1.2.3.zip" = "synthetic archive"
        "ReadMe.bbcode" = "[b]Synthetic description[/b]"
        "Changelog.bbcode" = "[b]Synthetic changes[/b]"
        "ReleaseReview.md" = "Status: [Approved for Release]`nRelease version: 1.2.3"
    }
    foreach ($name in $documents.Keys) {
        foreach ($directory in @($current, $handoff)) {
            $documents[$name] | Set-Content -LiteralPath (Join-Path $directory $name)
        }
    }
    $env:ESOUI_TOKEN = "synthetic-token"
    $arguments = @{ Id = 123; Compatible = "12.1.6"; Confirm = $false }

    & $scriptPath @arguments -WhatIf | Out-Null
    Assert ($requests.Count -eq 0) "WhatIf must not send requests."
    & $scriptPath @arguments | Out-Null
    Assert ($requests.Count -eq 1 -and $requests[0].Uri.EndsWith("/updatetest")) "Default must only test."
    $form = $requests[0].Form
    Assert ($form.id -eq "123" -and $form.version -eq "1.2.3" -and $form.compatible -eq "12.1.6") "Incorrect release metadata."
    Assert ($form.description.Trim() -eq $documents["ReadMe.bbcode"]) "Incorrect description."
    Assert ($form.changelog.Trim() -eq $documents["Changelog.bbcode"]) "Incorrect changelog."
    Assert ($form.updatefile -is [System.IO.FileInfo]) "Upload must be a multipart file."
    Assert ($form.Count -eq 6) "Unexpected upload fields."

    $requests.Clear()
    & $scriptPath @arguments -Action Publish | Out-Null
    Assert ($requests.Count -eq 2) "Publish must test before live upload."
    Assert ($requests[0].Uri.EndsWith("/updatetest") -and $requests[1].Uri.EndsWith("/update")) "Wrong endpoint order."

    $body = '[{"id":"12.1.6","interface":"101051"}]{"testDiagnostics":{"id":123}}'
    & $scriptPath @arguments | Out-Null
    $requests.Clear()
    & $scriptPath @arguments -Action Publish | Out-Null
    Assert ($requests.Count -eq 2 -and $requests[1].Uri.EndsWith("/update")) "Live responses may also prepend compatibility JSON."
    $body = '[{"id":"12.1.0","interface":"101051"}]{"testDiagnostics":{"id":123}}'
    Assert-Fails { & $scriptPath @arguments } "compatibility must be one of: 12.1.0"
    $status = 200
    $body = '{}{}'
    Assert-Fails { & $scriptPath -Action List -Confirm:$false } "unexpected number"
    $status = 202
    $body = '{"SUCCESS":"Accepted"}'
    $requests.Clear()
    $status = 403
    Assert-Fails { & $scriptPath @arguments -Action Publish } "HTTP 403"
    Assert ($requests.Count -eq 1) "Failed test must block live submission."
    $status = 400
    $body = '{"ERROR":"Invalid token synthetic-token"}'
    Assert-Fails { & $scriptPath @arguments } 'Server response: {"ERROR":"Invalid token [redacted]"}'
    try {
        & $scriptPath @arguments | Out-Null
        throw "Expected HTTP error."
    } catch {
        Assert (-not $_.Exception.Message.Contains("synthetic-token")) "HTTP error must redact credentials."
    }
    $body = "<html>Bad request`nPlease check the request.</html>"
    Assert-Fails { & $scriptPath @arguments } "Server response: <html>Bad request Please check the request.</html>"
    $body = ""
    Assert-Fails { & $scriptPath @arguments } "(empty response body)"
    $body = "x" * 2100
    Assert-Fails { & $scriptPath @arguments } "[truncated]"
    $body = '{"SUCCESS":"Accepted"}'
    $status = 200
    Assert-Fails { & $scriptPath @arguments } "expected 202"
    $status = 202
    $body = '{"ERROR":"synthetic-token rejected"}'
    Assert-Fails { & $scriptPath @arguments } "[redacted] rejected"
    $body = 'null'
    Assert-Fails { & $scriptPath @arguments } "empty response"
    $body = '{"SUCCESS":"Accepted"}'
    $networkFailure = $true
    Assert-Fails { & $scriptPath @arguments } "No automatic retry"
    $networkFailure = $false

    $requests.Clear()
    '{"Completed":false,"Version":"1.2.3"}' | Set-Content -LiteralPath $statePath
    Assert-Fails { & $scriptPath @arguments } "Finalize"
    '{"Completed":true,"Version":"1.2.3"}' | Set-Content -LiteralPath $statePath
    "changed" | Set-Content -LiteralPath (Join-Path $handoff "ReadMe.bbcode")
    Assert-Fails { & $scriptPath @arguments } "differs"
    Copy-Item -LiteralPath (Join-Path $current "ReadMe.bbcode") -Destination (Join-Path $handoff "ReadMe.bbcode")
    foreach ($directory in @($current, $handoff)) {
        "Status: [Not Approved]`nRelease version: 1.2.3" | Set-Content -LiteralPath (Join-Path $directory "ReleaseReview.md")
    }
    Assert-Fails { & $scriptPath @arguments } "must approve"
    Assert-Fails { & $scriptPath -Confirm:$false } "require -Id"
    Assert ($requests.Count -eq 0) "Local validation failures must not contact ESOUI."

    $status = 200
    $body = '[{"id":123,"title":"Synthetic addon"}]'
    $listing = & $scriptPath -Action List -Confirm:$false
    Assert ($listing.id -eq 123 -and $requests.Count -eq 1) "List must return authorized addon IDs."
    Assert ($requests[0].Uri.EndsWith("/list.json")) "Wrong list endpoint."
    $requests.Clear()
    $listing = & $scriptPath -Action List -UseCurl -Confirm:$false
    Assert ($listing.id -eq 123 -and $requests.Count -eq 0) "curl diagnosis must use only the curl transport."
    Assert-Fails { & $scriptPath @arguments -UseCurl } "requires -Action List"
    foreach ($paddedToken in @(" synthetic-token", "synthetic-token`n", "`t synthetic-token `r`n")) {
        $env:ESOUI_TOKEN = $paddedToken
        $listing = & $scriptPath -Action List -Confirm:$false -WarningVariable tokenWarnings -WarningAction SilentlyContinue
        Assert ($listing.id -eq 123) "Surrounding token whitespace must be normalized."
        Assert (@($tokenWarnings).Count -eq 1) "Token normalization must be reported."
    }
    $requests.Clear()
    foreach ($invalidToken in @("synthetic token", "synthetic`ntoken", '"synthetic-token"', "synthetic$([char]0x200B)token")) {
        $env:ESOUI_TOKEN = $invalidToken
        Assert-Fails { & $scriptPath -Action List -Confirm:$false } "no request was sent"
    }
    $env:ESOUI_TOKEN = "synthetic `t`n`r`"'$([char]0x200B)token"
    try {
        & $scriptPath -Action List -Confirm:$false | Out-Null
        throw "Expected invalid character rejection."
    } catch {
        $message = $_.Exception.Message
        foreach ($expected in @(
            "position 10: U+0020 (SPACE)",
            "position 11: U+0009 (TAB)",
            "position 12: U+000A (LINE FEED)",
            "position 13: U+000D (CARRIAGE RETURN)",
            "position 14: U+0022 (DOUBLE QUOTE)",
            "position 15: U+0027 (SINGLE QUOTE)",
            "position 16: U+200B (Format)"
        )) {
            Assert ($message.Contains($expected)) "Missing invalid-character detail: $expected"
        }
        Assert (-not $message.Contains("synthetic")) "Character diagnostics must not disclose token text."
    }
    Assert ($requests.Count -eq 0) "Invalid token characters must block requests."
    $requests.Clear()
    & $scriptPath -Action SaveToken -WhatIf | Out-Null
    $storedTokenPath = Join-Path $fixture "InventoryCompanion\ESOUI-token.clixml"
    Assert (-not (Test-Path -LiteralPath $storedTokenPath)) "WhatIf must not persist a token."
    & $scriptPath -Action SaveToken -Confirm:$false | Out-Null
    Assert (Test-Path -LiteralPath $storedTokenPath) "SaveToken must persist the encrypted token."
    Assert (-not (Get-Content -LiteralPath $storedTokenPath -Raw).Contains("synthetic-token")) "Stored token must not contain plaintext."
    $env:ESOUI_TOKEN = $null
    $listing = & $scriptPath -Action List -Confirm:$false
    Assert ($listing.id -eq 123 -and $requests.Count -eq 1) "Stored DPAPI token must work without interactive entry."
    $requests.Clear()
    '"not a SecureString"' | Export-Clixml -LiteralPath $storedTokenPath
    Assert-Fails { & $scriptPath -Action List -Confirm:$false } "not an encrypted SecureString"
    Assert ($requests.Count -eq 0) "Malformed stored credentials must block requests."
    Write-Output "PASS: $($assertions.Passed) ESOUI upload assertions; no network requests or real credentials used."
} finally {
    $env:ESOUI_TOKEN = $originalToken
    $env:LOCALAPPDATA = $originalLocalAppData
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
