@echo off
setlocal enabledelayedexpansion

for %%i in (%0) do set "DIR=%%~dpi.."
cd /d "%DIR%"

if "x%~1" == "x" (
    echo Usage: %~nx0 manifest [manifest...]
    exit /b 1
)

:addone
if "x%~1" == "x" goto end

set "INPUT=%~1"
set "MANIFEST="

for %%i in ("%INPUT%") do (
    set "INPUT_DIR=%%~dpi"
    set "INPUT_NAME=%%~ni"
    set "INPUT_EXT=%%~xi"
)

if not "x%INPUT_EXT%" == "x" (
    set "CANDIDATE=%INPUT%"
) else (
    set "CANDIDATE=%INPUT%.json"
)

if not "x%INPUT_DIR%" == "x" (
    if exist "%CANDIDATE%" set "MANIFEST=%CANDIDATE%"
) else (
    if exist "bucket\%CANDIDATE%" (
        set "MANIFEST=bucket\%CANDIDATE%"
    ) else if exist "%CANDIDATE%" (
        set "MANIFEST=%CANDIDATE%"
    )
)

if "x%MANIFEST%" == "x" (
    echo Manifest not found: %~1
    exit /b 1
)

for %%i in ("%MANIFEST%") do set "APP=%%~ni"
for /f "usebackq delims=" %%v in (`jq -r .version "%MANIFEST%"`) do set "VERSION=%%v"

if "x%VERSION%" == "x" (
    echo Version not found: %MANIFEST%
    exit /b 1
)
if "%VERSION%" == "null" (
    echo Version not found: %MANIFEST%
    exit /b 1
)

git add "%MANIFEST%"
if errorlevel 1 exit /b %errorlevel%

git commit -m "%APP%: Add version %VERSION%"
if errorlevel 1 exit /b %errorlevel%

git tag "%APP%-%VERSION%"
if errorlevel 1 exit /b %errorlevel%

shift
goto addone

:end
