@echo off
REM ------------------------------
REM Запуск скрипта установки драйверов
REM ------------------------------

REM Получаем директорию скрипта
set "SCRIPT_DIR=%~dp0"

REM Путь к папке с драйверами
set "DRIVER_REPO=%SCRIPT_DIR%drivers"

REM Путь к лог-файлу (складываем в ту же папку)
set "LOG_FILE=%SCRIPT_DIR%InstallDrivers.log"

echo [%%DATE%% %%TIME%%] Запуск установки драйверов из: %DRIVER_REPO% >> "%LOG_FILE%"

REM Запуск PS скрипта с логированием
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%InstallMissingDrivers.ps1" ^
    -DriverRepoPath "%DRIVER_REPO%" ^
    -LogPath "%LOG_FILE%"

echo [%%DATE%% %%TIME%%] Завершено (код ошибки: %%ERRORLEVEL%%) >> "%LOG_FILE%"

echo Операция завершена. См. лог: %LOG_FILE%
pause