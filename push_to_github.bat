@echo off
setlocal
cd /d "%~dp0"

echo ========================================================
echo Gurlal Sohal Raider Portfolio - Push to GitHub
echo ========================================================

set /p GITHUB_USER="Enter your GitHub username: "
if "%GITHUB_USER%"=="" (
    echo Username cannot be empty.
    pause
    exit /b 1
)

set REPO_URL=https://github.com/%GITHUB_USER%/gurlal-sohal-portfolio.git

echo.
echo Setting remote origin to: %REPO_URL%
git remote remove origin 2>nul
git remote add origin %REPO_URL%
git branch -M main

echo.
echo Pushing 'main' branch to GitHub...
echo (If prompted, sign in via browser or enter your GitHub Personal Access Token)
echo.
git push -u origin main

if errorlevel 1 (
    echo.
    echo [ERROR] Push failed. Please ensure:
    echo 1. You created a repository named 'gurlal-sohal-portfolio' on github.com/new
    echo 2. You have authenticated with GitHub (e.g. Personal Access Token or GitHub Desktop)
) else (
    echo.
    echo [SUCCESS] Portfolio pushed successfully to %REPO_URL%!
)

pause
