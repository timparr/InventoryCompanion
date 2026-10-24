@echo off
setlocal enabledelayedexpansion

:: Extract current folder name dynamically
for %%I in ("%CD%") do set "PROJECT_NAME=%%~nxI"

:: Output file created directly in the current folder
set "OUTPUT_FILE=%PROJECT_NAME%_Context.md"

:: Clear previous dump if it exists
if exist "%OUTPUT_FILE%" del "%OUTPUT_FILE%"

echo ========================================================
echo Building project context dump for %PROJECT_NAME%...
echo ========================================================

echo # %PROJECT_NAME% - Complete Context Dump > "%OUTPUT_FILE%"
echo Generated on: %date% %time% >> "%OUTPUT_FILE%"
echo. >> "%OUTPUT_FILE%"

:: 1. Search for any .txt file in the root directory (the manifest)
for %%T in (*.txt) do (
    if /I not "%%~nT"=="%PROJECT_NAME%_Context" (
        echo Processing Manifest: %%T
        echo ## THIS IS MANIFEST: %%T >> "%OUTPUT_FILE%"
        echo ``` >> "%OUTPUT_FILE%"
        type "%%T" >> "%OUTPUT_FILE%"
        echo. >> "%OUTPUT_FILE%"
        echo ``` >> "%OUTPUT_FILE%"
        echo. >> "%OUTPUT_FILE%"
    )
)

:: 2. Loop through all .lua and .xml files recursively
for /R %%F in (*.lua *.xml) do (
    echo Processing: %%F
    echo. >> "%OUTPUT_FILE%"
    echo ## THIS IS: %%F >> "%OUTPUT_FILE%"
    echo ``` >> "%OUTPUT_FILE%"
    type "%%F" >> "%OUTPUT_FILE%"
    echo. >> "%OUTPUT_FILE%"
    echo ``` >> "%OUTPUT_FILE%"
    echo. >> "%OUTPUT_FILE%"
)

echo.
echo Context output saved to: %OUTPUT_FILE%

:: 3. Generate Timestamped Backup Zip
echo.
echo ========================================================
echo Creating timestamped backup zip...
echo ========================================================

for /f "usebackq" %%i in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd-HH-mm'"`) do set TIMESTAMP=%%i
set "ZIP_FILE=%TIMESTAMP% Backup.zip"

if exist "%ZIP_FILE%" del "%ZIP_FILE%"

powershell -NoProfile -Command "Compress-Archive -Path 'Banking', 'Core', 'Tracking', '*.xml', '*.txt', '*.md' -DestinationPath '%ZIP_FILE%' -Force"

echo Backup created successfully: %ZIP_FILE%
echo ========================================================