@echo off
setlocal

for %%i in (%0) do set DIR=%%~dpi..

for /f %%i in ('scoop prefix scoop') do set STANDARDIZE=%DIR%\bin\standardize.ps1
for /f %%i in ('scoop which pwsh') do set PWSH=%%i
if "%PWSH%x" == "x" for /f %%i in ('scoop which powershell') do set PWSH=%%i

:stdone
if "x%~1" == "x" goto end
%PWSH% -noprofile -ex unrestricted -f %STANDARDIZE% -dir %DIR% "%~1" -u
if errorlevel 1 exit /b %errorlevel%
shift
goto :stdone

:end
