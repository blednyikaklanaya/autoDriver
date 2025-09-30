<#
.SYNOPSIS
    Installs only missing drivers from a local folder and logs errors.

.PARAMETER DriverRepoPath
    Path to the root drivers folder.

.PARAMETER LogPath
    Path to the detailed transcript log file (optional). Defaults to "InstallDrivers.log" next to the script.

.PARAMETER SimpleLogPath
    Path to the simplified log file (optional). Defaults to "InstallDrivers_simple.log" next to the script.

.NOTES
    Run as Administrator:
    PowerShell -ExecutionPolicy Bypass -File .\InstallMissingDrivers.ps1 -DriverRepoPath 'D:\Drivers'
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$DriverRepoPath,
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "",
    [Parameter(Mandatory = $false)]
    [string]$SimpleLogPath = ""
)

# --- Banner ASCII Art ---
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

# --- Подготовка путей и логов ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $LogPath) { $LogPath = Join-Path $scriptDir 'InstallDrivers.log' }
if (-not $SimpleLogPath) { $SimpleLogPath = Join-Path $scriptDir 'InstallDrivers_simple.log' }

"=== Driver install run at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" |
    Out-File -FilePath $SimpleLogPath -Encoding UTF8
"INFO: Drivers folder: $DriverRepoPath" |
    Out-File -FilePath $SimpleLogPath -Append

try {
    Start-Transcript -Path $LogPath -Append -ErrorAction Stop
} catch {
    Write-Warning "Failed to start transcript: $_"
}

Write-Host "Drivers folder: $DriverRepoPath" -ForegroundColor Cyan
Write-Host "Detailed log: $LogPath" -ForegroundColor Cyan
Write-Host "Simple log:   $SimpleLogPath" -ForegroundColor Cyan

if (-not (Get-Command pnputil.exe -ErrorAction SilentlyContinue)) {
    Write-Error "pnputil.exe not found. Exiting."
    "ERROR: pnputil.exe not found, aborting." |
        Out-File -FilePath $SimpleLogPath -Append
    Stop-Transcript; exit 1
}

Write-Host "Scanning drivers folder for .inf files..." -ForegroundColor Gray
$allInfs = Get-ChildItem -Path $DriverRepoPath -Recurse -Filter '*.inf' -ErrorAction SilentlyContinue

$missing = @()
$missing += Get-PnpDevice -Status Error -ErrorAction SilentlyContinue
$missing += Get-PnpDevice -Status Unknown -ErrorAction SilentlyContinue
$missing = $missing | Sort-Object InstanceId

Write-Host "Found $($missing.Count) device(s) needing drivers." -ForegroundColor Cyan
"INFO: Found $($missing.Count) devices needing drivers." |
    Out-File -FilePath $SimpleLogPath -Append

if (-not $missing) {
    Write-Host "All devices have drivers installed." -ForegroundColor Green
    "INFO: All devices have drivers installed, nothing to do." |
        Out-File -FilePath $SimpleLogPath -Append
    Stop-Transcript; exit 0
}

foreach ($dev in $missing) {
    $devInfo = "$($dev.FriendlyName) [$($dev.InstanceId)]"
    Write-Host "`nDevice: $devInfo" -ForegroundColor Yellow
    "DEVICE: $devInfo" |
        Out-File -FilePath $SimpleLogPath -Append

    try {
        $hwIds = (Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds').Data
    } catch {
        Write-Warning "Could not retrieve Hardware IDs: $_"
        "WARNING: Could not retrieve Hardware IDs for $($devInfo) $_" |
            Out-File -FilePath $SimpleLogPath -Append
        continue
    }

    $installed = $false
    foreach ($id in $hwIds) {
        $escapedId = [regex]::Escape($id)
        $match = $allInfs | Where-Object { Select-String -Pattern $escapedId -Path $_.FullName -Quiet } | Select-Object -First 1
        if ($match) {
            Write-Host "  -> Found driver for ID '$id': $($match.FullName)" -ForegroundColor White
            Write-Host "    Installing..." -ForegroundColor Gray
            "INSTALL: Attempting $(Split-Path $match.FullName -Leaf) for $($devInfo)" |
                Out-File -FilePath $SimpleLogPath -Append
            try {
                pnputil.exe /add-driver "$($match.FullName)" /install /subdirs | Out-Null
                Write-Host "    [OK] Installed." -ForegroundColor Green
                "SUCCESS: Installed driver $(Split-Path $match.FullName -Leaf) for $($devInfo)" |
                    Out-File -FilePath $SimpleLogPath -Append
                $installed = $true
                break
            } catch {
                Write-Warning "Installation failed: $_"
                "ERROR: Installation failed for $($match.FullName): $_" |
                    Out-File -FilePath $SimpleLogPath -Append
            }
        }
    }

    if (-not $installed) {
        Write-Host "    [!] No matching driver found." -ForegroundColor Red
        "FAIL: No matching driver found for $($devInfo)" |
            Out-File -FilePath $SimpleLogPath -Append
    }
}

Stop-Transcript