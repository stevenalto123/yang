@echo off
cd /d "%~dp0"

echo [1/4] Cleaning up unused Jamindan files...
del /f /q "lib\models\jamindan_barangays.dart" 2>nul
del /f /q "lib\models\broadcast_alert.dart" 2>nul
del /f /q "lib\providers\broadcast_provider.dart" 2>nul
del /f /q "lib\screens\mass_broadcast_screen.dart" 2>nul
del /f /q "web\jamindan_broadcast.html" 2>nul

echo [2/4] Installing Node packages & running Backend API tests...
call npm install
if errorlevel 1 goto :error
call npm run typecheck
if errorlevel 1 goto :error
call npm run test:api
if errorlevel 1 goto :error

echo [3/4] Staging and committing updates...
git add .
git diff --cached --quiet || git commit -m "Deploy full-stack LifeCheckpoint with cloud Flutter build on Netlify"

echo [4/4] Pushing to GitHub (master) — Netlify will build Flutter Web + Functions in the cloud...
git push origin master
if errorlevel 1 goto :error

echo.
echo ============================================================
echo PUSHED TO GITHUB!
echo Netlify is now building Flutter Web + API in the cloud (~2-3 mins).
echo Reply "Done" in chat so I can monitor the Netlify deploy for you!
echo ============================================================
pause
exit /b 0

:error
echo.
echo ============================================================
echo ERROR OCCURRED! Take a screenshot or send the error to chat.
echo ============================================================
pause
exit /b 1
