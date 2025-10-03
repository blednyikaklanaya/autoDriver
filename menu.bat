@echo off
chcp 65001 >nul
title Установка драйверов и прошивка
color 0D

:menu
cls
echo ============================================
echo         Installation and firmware menu
echo ============================================
echo.
echo   1. Install drivers
echo      (RunDriversInstall.bat) 
echo      and then open the firmware script
echo.
echo   2. Firmware the device immediately
echo.
echo   0. Exit
echo ============================================
echo.

set /p choice="Enter the number: "

if "%choice%"=="1" goto drivers
if "%choice%"=="2" goto flash
if "%choice%"=="0" exit
goto menu

:drivers
cls
echo Launching PowerShell to install drivers...
call "%~dp0RunDriversInstall.bat"
echo.
echo The drivers are installed.
echo.
pause
goto flash

:flash
cls
echo.
echo.
echo Firmware launch
echo.
echo.
cd /d "%~dp0d"

if exist flash.exe (
    start "" "flash.exe"
) else if exist flash.bat (
    call flash.bat
) else if exist flash.ps1 (
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "flash.ps1"
) else (
    echo Firmware script not found!
)

echo.
pause
exit