#Requires -Version 5.1
<#
  Stop-Strata.ps1 - stop the Strata server started by Start-Strata.ps1.

  Same profile argument as the launcher (Stop-Strata.bat orca -> .env-orca).
  Kills the server and its engine inside WSL. Does NOT shut down the WSL VM
  (that would drop every other distro session too).
#>
param([string]$Profile = "default")
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$EnvFile = Join-Path $ScriptDir ".env-$Profile"
if (-not (Test-Path $EnvFile)) { $EnvFile = Join-Path $ScriptDir '.env' }
if (-not (Test-Path $EnvFile)) {
    Write-Host "[NG] No env file found (looked for .env-$Profile, then .env)."
    exit 1
}

function Get-EnvValue([string]$Name) {
    foreach ($line in (Get-Content $EnvFile -ErrorAction SilentlyContinue)) {
        if ($line -match ("^\s*$Name\s*=\s*(.*?)\s*$")) { return $Matches[1] }
    }
    return $null
}

$Distro = Get-EnvValue 'WSL_DISTRO'; if (-not $Distro) { $Distro = 'Ubuntu' }
$Port = Get-EnvValue 'PORT'; if (-not $Port) { $Port = '8080' }
$Model = Get-EnvValue 'MODEL'; if (-not $Model) { $Model = '?' }
$WslDir = (($ScriptDir -replace '\\', '/') -replace '^([A-Za-z]):', '/mnt/$1').ToLowerInvariant()

Write-Host ("[{0}] [INFO] Stopping Strata (model {1}) on port {2}. This does not shut down WSL." -f (Get-Date -Format 'HH:mm:ss'), $Model, $Port)
$out = (wsl.exe -d $Distro -- bash "$WslDir/stop-strata.sh" $Profile) -join "`n"
Write-Host $out
if ($out -match 'NOT_RUNNING') {
    Write-Host ("[{0}] [OK] Nothing was running on port {1}." -f (Get-Date -Format 'HH:mm:ss'), $Port)
} elseif ($out -match 'STOPPED|STOP_SENT') {
    Write-Host ("[{0}] [OK] Server stopped. RAM and VRAM are released as the process exits." -f (Get-Date -Format 'HH:mm:ss'))
    Write-Host "  vmmemWSL may stay at a few GB. That is the idle WSL VM, not the model."
} else {
    Write-Host ("[{0}] [NG] Stop did not confirm. Check inside WSL: ss -tln | grep {1}" -f (Get-Date -Format 'HH:mm:ss'), $Port)
    exit 1
}
