@echo off
rem Double-click launcher for the locally built XPrismLauncher.
rem
rem Why not just click install\prismlauncher.exe?
rem   * TEMP/TMP are redirected into the repo. Prism's single-instance lock lives in
rem     %TEMP%; if that path is not writable the app decides another copy is already
rem     running and exits with "Unable to redirect command to already running instance".
rem   * --dir keeps instances/logs/accounts in .tools\run-data, so this build never
rem     touches your real Prism Launcher installation in %APPDATA%\PrismLauncher.
setlocal
set "ROOT=%~dp0"
set "TEMP=%ROOT%.tools\tmp"
set "TMP=%TEMP%"
if not exist "%TEMP%" mkdir "%TEMP%"
if not exist "%ROOT%install\prismlauncher.exe" (
    echo Build not found: %ROOT%install\prismlauncher.exe
    echo Run:  .\scripts\toolchain\build.ps1 -Install
    pause
    exit /b 1
)
start "" "%ROOT%install\prismlauncher.exe" --dir "%ROOT%.tools\run-data"
