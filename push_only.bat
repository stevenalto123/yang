@echo off
cd /d "%~dp0"

echo [1/3] Checking Backend TypeScript & API tests...
if not exist "node_modules" (
  call npm install
  if errorlevel 1 goto :error
)
call npm run typecheck
if errorlevel 1 goto :error
call npm run test:api
if errorlevel 1 goto :error

echo [2/3] Staging and committing updates...
git status -s
git add -A
if errorlevel 1 goto :error
git commit -m "Scope system strictly to City of Manila districts, shelters, hospitals, and hotlines"

echo [3/3] Pushing to GitHub (master)...
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
