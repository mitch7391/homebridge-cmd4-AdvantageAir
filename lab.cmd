@echo off
setlocal
where node >nul 2>nul
if not errorlevel 1 (
  node "%~dp0dev\lab\lab.mjs" %*
  exit /b
)
set "LAB_NODE=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
if not exist "%LAB_NODE%" (
  echo Node.js 24 is recommended. Install Node.js or add it to PATH.
  exit /b 1
)
"%LAB_NODE%" "%~dp0dev\lab\lab.mjs" %*
