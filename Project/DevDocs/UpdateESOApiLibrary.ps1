$ErrorActionPreference = "Stop"

$generatorRoot = Join-Path $HOME "Documents\ESO-LuaLS-Generator"
$generatorScript = Join-Path $generatorRoot "generate_all.py"
$generatorOutput = Join-Path $generatorRoot "generated-eso-api\luals"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$libraryOutput = Join-Path $repoRoot "generated-eso-api\luals"
$python = Join-Path $env:LOCALAPPDATA "Programs\Python\Python312\python.exe"

if (-not (Test-Path $generatorScript -PathType Leaf)) {
    throw "ESO LuaLS Generator was not found at $generatorRoot. See Project\DevDocs\DeveloperSetup.md."
}
if (-not (Test-Path $python -PathType Leaf)) {
    throw "Python 3.12 was not found at $python. Install Python 3.12 or update this script to your Python executable."
}

"" | & $python -X utf8 $generatorScript
if ($LASTEXITCODE -ne 0) {
    throw "ESO LuaLS Generator failed with exit code $LASTEXITCODE."
}

$hasGlobalDefinitions = Test-Path (Join-Path $generatorOutput "eso-globals.lua") -PathType Leaf
$hasFunctionDefinitions = Test-Path (Join-Path $generatorOutput "eso-functions.lua") -PathType Leaf
if (-not $hasGlobalDefinitions -or -not $hasFunctionDefinitions) {
    throw "ESO LuaLS Generator completed without producing both LuaLS definition files."
}

New-Item -ItemType Directory -Path $libraryOutput -Force | Out-Null
Copy-Item (Join-Path $generatorOutput "*.lua") $libraryOutput -Force
Write-Output "Updated ESO LuaLS definitions in $libraryOutput"
