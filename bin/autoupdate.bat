for %%i in (%0) do set DIR=%%~dpi..

git checkout master

pwsh -noprofile -ex unrestricted -f bin\checkver.ps1 -dir . -u

:commit
for /f %%i in ('git diff --name-only') do (
    git add %%i
    for /f %%v in ('jq .version %%i') do (
        git commit -m "%%~ni: Update to version %%v"
        git tag "%%~ni-%%v"
    )
)
git push origin master
git checkout -f master

:end
