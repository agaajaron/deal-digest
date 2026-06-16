@echo off
echo Starting Deal Digest...
echo.
echo Open Chrome at: http://localhost:8080/index.html
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0proxy.ps1"
pause
