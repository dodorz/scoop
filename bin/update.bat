@echo off
setlocal

for /f %%i in ('scoop prefix scoop') do (
    set CHECKVER=%%i\bin\checkver.ps1
    set FORMAT=%%i\bin\formatjson.ps1
)
for /f %%i in ('scoop which pwsh') do set PWSH=%%i
if "%PWSH%x" == "x" for /f %%i in ('scoop which powershell') do set PWSH=%%i

for %%i in (%0) do set DIR=%%~dpi..
cd %DIR%
git checkout uo

set "TMP_PRE=%TEMP%\scoop_pre_%RANDOM%.txt"
set "TMP_POST=%TEMP%\scoop_post_%RANDOM%.txt"
set "TMP_UPD=%TEMP%\scoop_upd_%RANDOM%.txt"
set "TMP_POST_MAN=%TEMP%\scoop_post_man_%RANDOM%.txt"
git diff --name-only > "%TMP_PRE%"

if "x%~1" == "x" goto updall

:updone
if "x%~1" == "x" goto commit
%PWSH% -noprofile -ex unrestricted -f %CHECKVER% -dir %DIR%\bucket "%~n1" -u
if errorlevel 1 exit /b %errorlevel%
shift
goto :updone

:updall
%PWSH% -noprofile -ex unrestricted -f %CHECKVER% -dir %DIR%\bucket -u
if errorlevel 1 exit /b %errorlevel%

:commit
git diff --name-only > "%TMP_POST%"
findstr /i /r /c:"^bucket\\.*\.json$" "%TMP_POST%" > "%TMP_POST_MAN%"
findstr /v /x /g:"%TMP_PRE%" "%TMP_POST_MAN%" > "%TMP_UPD%"
for /f %%i in ('type "%TMP_UPD%"') do (
    git add %%i
    for /f %%v in ('jq .version %%i') do (
        git commit -m "%%~ni: Update to version %%v"
        git tag "%%~ni-%%v"
    )
)
del "%TMP_PRE%" "%TMP_POST%" "%TMP_POST_MAN%" "%TMP_UPD%" >nul 2>nul
::git push origin master
::git checkout -f master

:end
