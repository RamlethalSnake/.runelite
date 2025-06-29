@echo off
setlocal

:: Define the items you want to forcibly exclude
set FILE1=plugins/
set FILE2=sync-branches.sh

:: Checkout your current branch or one passed via argument
if "%~1"=="" (
    echo Using current branch.
) else (
    git checkout %~1
)

:: Update .gitignore
echo ✅ Updating .gitignore to re-block specific files...
(
    echo %FILE1%
    echo %FILE2%
)>>.gitignore

:: Remove files from tracking (won't delete locally)
echo 🔍 Untracking unwanted files...
git rm --cached -r %FILE1%
git rm --cached %FILE2%

:: Commit the change
echo 📦 Committing cleanup...
git add .gitignore
git commit -m "Fix: remove unwanted files and patch .gitignore"
git push

echo 🧼 Cleanup complete. Files will no longer track in this branch.
pause