#Requires -Version 5.1
<#
  Start-Strata.ps1 - one-click launcher for the Strata LLM server inside WSL.

  All settings come from the env file next to this script (see .env.example):
    a profile argument selects .env-<profile> (e.g. `Start-Strata.bat orca` -> .env-orca),
    falling back to .env. Nothing about your machine is hardcoded here.

  - Server already running: opens the browser, no double start.
  - Not running: starts it detached inside WSL and polls real load progress
    (engine RSS, % of the resident budget, VRAM, the engine's stage line) until ready.
#>
param([string]$Profile = "default")
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$EnvFile = Join-Path $ScriptDir ".env-$Profile"
if (-not (Test-Path $EnvFile)) { $EnvFile = Join-Path $ScriptDir '.env' }
if (-not (Test-Path $EnvFile)) {
    Write-Host "[NG] No env file found (looked for .env-$Profile, then .env). Copy .env.example to .env and fill it in."
    exit 1
}

function Get-EnvValue([string]$Name) {
    foreach ($line in (Get-Content $EnvFile -ErrorAction SilentlyContinue)) {
        if ($line -match ("^\s*$Name\s*=\s*(.*?)\s*$")) { return $Matches[1] }
    }
    return $null
}

$Key = Get-EnvValue 'API_KEY'
if (-not $Key) { Write-Host '[NG] API_KEY is missing in the env file.'; exit 1 }
$Model = Get-EnvValue 'MODEL'
if (-not $Model) { Write-Host '[NG] MODEL is missing in the env file (the tag of strata-<MODEL>.json).' ; exit 1 }
$Distro = Get-EnvValue 'WSL_DISTRO'; if (-not $Distro) { $Distro = 'Ubuntu' }
$Port = Get-EnvValue 'PORT'; if (-not $Port) { $Port = '8080' }
$TimeoutMin = Get-EnvValue 'TIMEOUT_MINUTES'; if (-not $TimeoutMin) { $TimeoutMin = '20' }
$Gpu = Get-EnvValue 'GPU_IDS'; if (-not $Gpu) { $Gpu = '0' }
$GpuFirst = ($Gpu -split ',')[0].Trim()
$TotalGib = Get-EnvValue 'RESIDENT_TOTAL_GIB'; if (-not $TotalGib) { $TotalGib = '76' }
$ExtraUrls = Get-EnvValue 'EXTRA_URLS'
$OpenBrowser = Get-EnvValue 'OPEN_BROWSER'; if (-not $OpenBrowser) { $OpenBrowser = '1' }
$StrataDir = Get-EnvValue 'STRATA_DIR'
if (-not $StrataDir) {
    $StrataDir = ((wsl.exe -d $Distro -- bash -c 'printf %s "$HOME/Strata"') -join '').Trim()
}
$LogPath = "$StrataDir/serve-$Model.out"

# This folder as seen from inside WSL (no hardcoded /mnt/c path; works for any user name).
# Convert locally instead of asking wslpath: its UTF-8 output gets misread by PowerShell 5.1.
$WinDirFwd = ($ScriptDir -replace '\\', '/') -replace '^([A-Za-z]):', '/mnt/$1'
$WslDir = $WinDirFwd.ToLowerInvariant()
if (-not (Test-Path $ScriptDir)) { Write-Host "[NG] Script folder not found: $ScriptDir"; exit 1 }

function Test-Server {
    $s = (wsl.exe -d $Distro -- bash "$WslDir/load-progress.sh" health $Port) -join ''
    return ($s.Trim() -eq 'READY')
}

if (Test-Server) {
    Write-Host ('[{0}] [OK] Strata (model {1}) is already running on port {2}. Opening the browser.' -f (Get-Date -Format 'HH:mm:ss'), $Model, $Port)
} else {
    Write-Host ('[{0}] [INFO] Starting Strata (model {1}) in WSL distro {2}. Loading the expert cache takes about 5-10 minutes...' -f (Get-Date -Format 'HH:mm:ss'), $Model, $Distro)
    wsl.exe -d $Distro -- bash "$WslDir/start-strata.sh" $Profile
    $start = Get-Date
    $deadline = (Get-Date).AddMinutes([double]$TimeoutMin)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 20
        if (Test-Server) { break }
        $p = (wsl.exe -d $Distro -- bash "$WslDir/load-progress.sh" progress $Port $LogPath $GpuFirst $TotalGib) -join ' '
        Write-Host ('[{0}] [WAIT] Loading... ({1:N1} min elapsed) {2}' -f (Get-Date -Format 'HH:mm:ss'), ((Get-Date) - $start).TotalMinutes, $p.Trim())
    }
    if (-not (Test-Server)) {
        Write-Host ('[{0}] [NG] Not ready after {1} minutes. Check the log inside WSL: {2}' -f (Get-Date -Format 'HH:mm:ss'), $TimeoutMin, $LogPath)
        exit 1
    }
    Write-Host ('[{0}] [OK] Strata is up on port {1}.' -f (Get-Date -Format 'HH:mm:ss'), $Port)
}

Write-Host ''
Write-Host "  Web UI : http://127.0.0.1:$Port/"
Write-Host "  API    : http://127.0.0.1:$Port/v1"
if ($ExtraUrls) {
    foreach ($u in ($ExtraUrls -split ',')) {
        $u = $u.Trim()
        if ($u) { Write-Host "  Extra  : $u" }
    }
}
if ($OpenBrowser -eq '1') { Start-Process "http://127.0.0.1:$Port/" }
Write-Host ''
Write-Host '  Closing this window does NOT stop the server.'
if ($Profile -eq 'default') {
    Write-Host '  To stop it and free RAM/VRAM, double-click Stop-Strata.bat'
} else {
    Write-Host ("  To stop it and free RAM/VRAM, run: Stop-Strata.bat {0}" -f $Profile)
}