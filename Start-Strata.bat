@echo off
REM Strata one-click launcher (double-click this file).
REM Optional profile argument: Start-Strata.bat orca  -> uses .env-orca instead of .env
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Strata.ps1" %*
pause