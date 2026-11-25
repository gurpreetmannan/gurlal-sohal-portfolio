@echo off
cd /d "%~dp0"
title Gurlal Sohal Raider Portfolio - Deploy to Live
echo ========================================================
echo Gurlal Sohal Raider Portfolio - Deploy to Live Website
echo ========================================================
echo.
echo Current git branch status:
git status -s
echo.
echo Pushing production commits to GitHub repository...
echo https://github.com/gurpreetmannan/gurlal-sohal-portfolio.git
echo.
git push origin main
if errorlevel 1 (
    echo.
    echo ========================================================
    echo [NOTE] If a GitHub sign-in prompt appears, please sign in.
    echo Once signed in, rerun this script to complete deployment.
    echo ========================================================
) else (
    echo.
    echo ========================================================
    echo [SUCCESS] Pushed to GitHub successfully!
    echo.
    echo Vercel will now automatically update your live site at:
    echo   https://gurlalsohal.in
    echo   https://gurlal-sohal-portfolio.vercel.app
    echo ========================================================
)
echo.
pause
