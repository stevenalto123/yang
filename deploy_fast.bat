@echo off
cd /d "%~dp0"

echo [1/5] Cleaning up unused Jamindan files...
del /f /q "lib\models\jamindan_barangays.dart" 2>nul
del /f /q "lib\models\broadcast_alert.dart" 2>nul
del /f /q "lib\providers\broadcast_provider.dart" 2>nul
del /f /q "lib\screens\mass_broadcast_screen.dart" 2>nul
del /f /q "web\jamindan_broadcast.html" 2>nul

echo [2/5] Installing Node packages & testing Backend API...
call npm install
if errorlevel 1 goto :error
call npm run typecheck
if errorlevel 1 goto :error
call npm run test:api
if errorlevel 1 goto :error

echo [3/5] Running Flutter static analysis...
call flutter analyze --no-pub
if errorlevel 1 goto :error

echo [4/5] Building Flutter Web PWA...
call flutter build web --no-pub --release --base-href /
if errorlevel 1 goto :error

echo [5/5] Pushing to GitHub (master) to deploy on Netlify...
git add .
git diff --cached --quiet || git commit -m "Deploy full-stack LifeCheckpoint with Netlify Functions and Supabase"
git push origin master
if errorlevel 1 goto :error

echo.
echo ============================================================
echo SUCCESS! Wait ~20 seconds, then open:
echo https://yangjd.netlify.app
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
