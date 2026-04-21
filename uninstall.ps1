# uninstall.ps1 — elimina la tarea programada 'ClapListener' y detiene el proceso si corre.

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Este script requiere privilegios de administrador. Reabriendo elevado...' -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$taskName = 'ClapListener'

Write-Host "== Deteniendo tarea '$taskName' ==" -ForegroundColor Cyan
schtasks /End /TN $taskName 2>$null | Out-Null

Write-Host "== Eliminando tarea '$taskName' ==" -ForegroundColor Cyan
schtasks /Delete /TN $taskName /F 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Tarea '$taskName' eliminada." -ForegroundColor Green
} else {
    Write-Host "La tarea no existía o ya estaba eliminada." -ForegroundColor Yellow
}

# Mata procesos pythonw que estén ejecutando clap_listener.py
$listener = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'clap_listener.py'
$procs = Get-CimInstance Win32_Process -Filter "Name = 'pythonw.exe'" |
    Where-Object { $_.CommandLine -like "*clap_listener.py*" }
foreach ($p in $procs) {
    Write-Host "Matando pythonw.exe PID $($p.ProcessId)"
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}

Write-Host 'Listo.' -ForegroundColor Green
