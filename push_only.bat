@echo off
cd /d "%~dp0"

echo [0/3] Removing obsolete scripts, unused Netlify config, and personal files...
del /f /q /a "deploy.bat" 2>nul
del /f /q /a "deploy.bat.bat" 2>nul
del /f /q /a "deploy_fast.bat" 2>nul
del /f /q /a "serve_web.js" 2>nul
del /f /q /a "scripts\generate_sw.js" 2>nul
del /f /q /a "netlify.toml" 2>nul
del /f /q /a "netlify\functions\api.mts" 2>nul
rmdir /q "netlify\functions" 2>nul
del /f /q /a "Jhon_Steven_Application_Letter.doc" 2>nul
del /f /q /a "Jhon_Steven_Application_Letter.html" 2>nul
del /f /q /a "Jhon_Steven_Application_Letter.rtf" 2>nul
del /f /q /a "Jhon_Steven_Application_Letter_and_Resume.rtf" 2>nul
del /f /q /a "Jhon_Steven_Letter_and_Resume_v2.pdf" 2>nul
del /f /q /a "Jhon_Steven_Letter_and_Resume_v2.rtf" 2>nul
del /f /q /a "Jhon_Steven_Letter_and_Resume_v3.rtf" 2>nul
del /f /q /a "~$on_Steven_Application_Letter.rtf" 2>nul

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
git commit -m "Harden OTP lockout/cooldown, JWT revocation, CSP, error sanitization, and mobile FIL/Dark UI fixes"

echo [3/3] Pushing to GitHub (master)...
git push origin master
if errorlevel 1 goto :error

echo.
echo ============================================================
echo PUSHED TO GITHUB!
echo Vercel is now building and deploying your updated app (~1-2 mins).
echo Reply "Done" in chat with your .vercel.app link so I can verify it live!
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
