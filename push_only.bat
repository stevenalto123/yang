@echo off
cd /d "%~dp0"

echo [0/3] Moving legacy backend folder to server\lib and removing obsolete files...
if exist "netlify\lib" (
  if not exist "server\lib" mkdir "server\lib"
  xcopy /Y /Q "netlify\lib\*" "server\lib\" >nul
  if errorlevel 1 goto :error
  rmdir /s /q "netlify" 2>nul
)
if exist ".test-dist" rmdir /s /q ".test-dist" 2>nul

echo [1/3] Checking Backend TypeScript and API tests...
if exist "node_modules" (
  call npm run typecheck
  if errorlevel 1 goto :error
  call npm run test:api
  if errorlevel 1 goto :error
) else (
  echo   Skipping local npm tests - Vercel runs full build and checks in cloud.
)

echo [2/3] Staging and committing updates...
git status -s
git add -A
if errorlevel 1 goto :error
git commit -m "Rename netlify/lib to server/lib and enable true offline PWA mode with self-hosted CanvasKit (v37)"

echo [3/3] Pushing to GitHub (master)...
git push origin master
if errorlevel 1 goto :error

echo.
echo ============================================================
echo PUSHED TO GITHUB!
echo Vercel is now building and deploying your updated app (~2 mins).
echo Reply "Done" in chat so I can verify offline mode live!
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
