@echo off
cd /d "%~dp0"
title Gurlal Sohal Raider Portfolio - Local Development Server
echo ========================================================
echo Gurlal Sohal Raider Portfolio - Local Development Server
echo ========================================================
echo.
echo Starting local HTTP development server...
echo Serving at:
echo   - http://localhost:3000/
echo   - http://127.0.0.1:3000/
echo.
echo [TIP] In Google Chrome, always enter: http://localhost:3000/
echo If Chrome shows an HTTPS upgrade warning, click "Continue to site".
echo.
echo Press Ctrl+C in this window anytime to stop the server.
echo ========================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
