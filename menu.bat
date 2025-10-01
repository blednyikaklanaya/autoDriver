@echo off
chcp 65001 >nul
title Установка драйверов и прошивка
color 0D

:menu
cls
echo ============================================
echo         🔧 Меню установки и прошивки
echo ============================================
echo.
echo   1. Установить драйверы
echo      (RunDriversInstall.bat) 
echo      и затем открыть скрипт прошивки
echo.
echo   2. Сразу прошить устройство
echo.
echo   0. Выход
echo ============================================
echo.

set /p choice="Введите номер: "

if "%choice%"=="1" goto drivers
if "%choice%"=="2" goto flash
if "%choice%"=="0" exit
goto menu

:drivers
cls
echo 🔄 Запуск PowerShell для установки драйверов...
call "%~dp0RunDriversInstall.bat"
echo.
echo ✅ Драйверы установлены.
echo.
pause
goto flash

:flash
cls
echo.
echo.
echo 🚀 Запуск прошивки
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
    echo ❌ Скрипт прошивки не найден!
)

echo.
pause
exit