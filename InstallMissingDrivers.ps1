<# Скрипт для установки отсутствующих драйверов из репозитория #>
param(
    [string]$DriverRepoPath = "F:\\drivers",
    [string]$LogPath        = "F:\\InstallDrivers.log"
)

# Баннер в консоли
$banner = @"       
   ,--------------v--------------,
    \             |             /
   _.-;==;-._     |     _.-;==;/._
 <`  (    )  `>   |   <`  (    )  `>
   `^-*v=*-^`     |     `^-*=v*-^`
   _.-;=\;-._     |     _.-;/=;-._
 <`  (    )  `>   |   <`  (    )  `>
   `^-*==*\^`     |     `^r*==*-^`
   _.-;==;-\_     |     _/-;==;-._
 <`  (    )  `>   |   <`  (    )  `>
   `^-*==*-^`\    |    /`^-*==*-^`
              \   |   / _.-;==;-._
               \  |  /<`  (    )  `>
                \ | /   `^-*==*-^`
                 \|/
"@
Write-Host $banner -ForegroundColor Cyan

# Пути логов
$simpleLogFilePath = [IO.Path]::Combine(
    [IO.Path]::GetDirectoryName($LogPath),
    [IO.Path]::GetFileNameWithoutExtension($LogPath) + "_simple.log"
)
Start-Transcript -Path $LogPath

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Drivers folder: $DriverRepoPath" -ForegroundColor DarkCyan
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Detailed log: $LogPath" -ForegroundColor DarkCyan
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Simple log:   $simpleLogFilePath`n" -ForegroundColor DarkCyan

# Сканируем все .inf
Write-Host "Scanning drivers folder for .inf files..." -ForegroundColor Yellow
$infFiles = Get-ChildItem -Path $DriverRepoPath -Filter "*.inf" -Recurse

# Получаем устройства с проблемами драйверов
$devices = Get-WmiObject Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
Write-Host "Found $($devices.Count) device(s) needing drivers.`n" -ForegroundColor Yellow

# Выводим начальный список устройств и их кодов ошибок
Write-Host "Initial device status:`n" -ForegroundColor Magenta
$devices | ForEach-Object {
    Write-Host "- $_.Name : ErrorCode $_.ConfigManagerErrorCode" -ForegroundColor Red
}
Write-Host "`n"

# Подготовка массива результатов
$results = @()

# Функция поиска по множеству паттернов
function Find-DriverForDevice {
    param($device, $infFiles)
    # Собираем все аппаратные идентификаторы
    $ids = @()
    if ($device.HardwareID)   { $ids += $device.HardwareID }
    if ($device.CompatibleID) { $ids += $device.CompatibleID }
    $ids += $device.PNPDeviceID.Split('\\')[0]

    # Уникализируем
    $ids = $ids | Select-Object -Unique

    foreach ($id in $ids) {
        $patterns = @([Regex]::Escape($id))
        if ($id -match "VEN_([0-9A-F]{4})&DEV_([0-9A-F]{4})") { $patterns += "VEN_$($matches[1])&DEV_$($matches[2])" }
        if ($id -match "VID_([0-9A-F]{4})&PID_([0-9A-F]{4})") { $patterns += "VID_$($matches[1])&PID_$($matches[2])" }
        if ($id -match "SUBSYS_([0-9A-F]{8})")        { $patterns += "SUBSYS_$($matches[1])" }
        foreach ($pat in $patterns | Select-Object -Unique) {
            $match = $infFiles | Where-Object { Select-String -Path $_.FullName -Pattern $pat -Quiet } |
                     Sort-Object { $_.FullName.Length } | Select-Object -First 1
            if ($match) { return $match }
        }
    }
    # Фолбэк: INF с кратчайшим путём
    return $infFiles | Sort-Object { $_.FullName.Length } | Select-Object -First 1
}

# Обработка каждого устройства
foreach ($device in $devices) {
    $name     = $device.Name
    $deviceId = $device.PNPDeviceID
    Write-Host "Processing: $name [$deviceId]" -ForegroundColor White

    $match = Find-DriverForDevice -device $device -infFiles $infFiles
    if ($match) {
        Write-Host "  -> Using INF: $($match.Name)" -ForegroundColor DarkYellow
        Write-Host "    Installing..." -ForegroundColor DarkYellow
        try {
            pnputil.exe -i -a $match.FullName | Out-Null
            Write-Host "    [OK] Installed." -ForegroundColor Green
            $status = 'Installed'
        } catch {
            Write-Host "    [ERROR] Installation failed." -ForegroundColor Red
            $status = 'Failed'
        }
    } else {
        Write-Host "  [!] No INF found. Skipping." -ForegroundColor Yellow
        $status = 'NoINF'
    }
    # Запись в простой лог
    $infName = if ($match) { $match.Name } else { '' }
    Add-Content -Path $simpleLogFilePath -Value "[$(Get-Date -Format 's')] ${status}: ${name} using ${infName}"
    $results += [PSCustomObject]@{ Name=$name; DeviceID=$deviceId; Status=$status; INF=$infName }
    Write-Host ""
}

# Вывод итогового списка
Write-Host "Summary of operations:`n" -ForegroundColor Cyan
$results | Format-Table -AutoSize

Stop-Transcript
Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Transcript stopped, output file is $LogPath" -ForegroundColor DarkCyan
