# restart.ps1 — reinicia la tarea programada 'ClapListener' para recargar config.json.
# Ejecutar como administrador (la tarea está registrada con /RL HIGHEST).

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Requiere admin. Reabriendo elevado...' -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$taskName = 'ClapListener'
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$listener = Join-Path $root 'clap_listener.py'

Write-Host "== Parando tarea '$taskName' ==" -ForegroundColor Cyan
schtasks /End /TN $taskName 2>$null | Out-Null

# Matar cualquier pythonw.exe que siga ejecutando clap_listener.py
$procs = Get-CimInstance Win32_Process -Filter "Name = 'pythonw.exe'" |
    Where-Object { $_.CommandLine -like "*clap_listener.py*" }
foreach ($p in $procs) {
    Write-Host "  matando PID $($p.ProcessId)"
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Milliseconds 500

Write-Host "== Arrancando tarea '$taskName' ==" -ForegroundColor Cyan
schtasks /Run /TN $taskName | Out-Null

Start-Sleep -Milliseconds 500
$running = Get-CimInstance Win32_Process -Filter "Name = 'pythonw.exe'" |
    Where-Object { $_.CommandLine -like "*clap_listener.py*" }
if ($running) {
    Write-Host "Detector en marcha (PID $($running.ProcessId))." -ForegroundColor Green
    Write-Host "Log: $(Join-Path $root 'clap_listener.log')"
} else {
    Write-Host 'Aviso: no se detecta pythonw.exe con clap_listener.py. Revisa el log.' -ForegroundColor Yellow
}
