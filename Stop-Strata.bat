@echo off
REM Stop the Strata server. Closing Start-Strata.bat does NOT stop it.
REM Optional profile: Stop-Strata.bat orca  -> stops the .env-orca server only.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-Strata.ps1" %*
pause
