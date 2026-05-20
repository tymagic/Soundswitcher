@echo off
chcp 65001 >nul 2>&1
cd /d "%~dp0"
start "" "%~dp0node_modules\.bin\electron.cmd" "%~dp0"
