@echo off
cd /d "%~dp0"

echo [1/4] Cleaning up unused Jamindan files...
del /f /q "lib\models\jamindan_barangays.dart" 2>nul
del /f /q "lib\models\broadcast_alert.dart" 2>nul
del /f /q "lib\providers\broadcast_provider.dart" 2>nul
del /f /q "lib\screens\mass_broadcast_screen.dart" 2>nul
del /f /q "web\jamindan_broadcast.html" 2>nul

echo [2/4] Checking Backend TypeScript & API tests...
if not exist "node_modules" (
  call npm install
  if errorlevel 1 goto :error
)
call npm run typecheck
if errorlevel 1 goto :error
call npm run test:api
if errorlevel 1 goto :error

echo [3/4] Staging and committing updates...
git status -s
git add -A
if errorlevel 1 goto :error
git commit -m "Remove researcher box and support unified Admin Sign In"

echo [4/4] Pushing to GitHub (master)...
git push origin master
if errorlevel 1 goto :error

echo.
echo ============================================================
echo PUSHED TO GITHUB!
echo Netlify is now building your new UI in the cloud (~1-2 mins).
echo Reply "Done" in chat so I can verify https://yangjd.netlify.app!
echo ============================================================
pause
exit /b 0

:error
echo.
echo ============================================================
echo ERROR OCCURRED ABOVE! Please screenshot this window and send it here.
echo ============================================================
pause
exit /b 1
