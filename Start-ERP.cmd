@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0local-deployment\Start-Local.ps1" -OpenBrowser
if errorlevel 1 pause
