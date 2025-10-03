@echo off
REM ------------------------------
REM Run installer drivers
REM ------------------------------

REM Get direct file
set "SCRIPT_DIR=%~dp0"

REM Direct for folder a scripts
set "DRIVER_REPO=%SCRIPT_DIR%drivers"

REM direct for log
set "LOG_FILE=%SCRIPT_DIR%InstallDrivers.log"

echo [%%DATE%% %%TIME%%] Run installer drivers: %DRIVER_REPO% >> "%LOG_FILE%"

REM Запуск PS скрипта с логированием
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%InstallMissingDrivers.ps1" ^
    -DriverRepoPath "%DRIVER_REPO%" ^
    -LogPath "%LOG_FILE%"

echo [%%DATE%% %%TIME%%] End (error code: %%ERRORLEVEL%%) >> "%LOG_FILE%"

set "CURPATH=%~dp0"

set "WALLPAPER=%CURPATH%wallpaper.jpg"

if not exist "%WALLPAPER%" (
    echo Error: file %WALLPAPER% not exist!
    pause
    exit /b
)

reg add "HKCU\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "%WALLPAPER%" /f >nul

RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters

echo End install, check LOG file this: %LOG_FILE%
pause