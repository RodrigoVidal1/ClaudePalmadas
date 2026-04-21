# install.ps1 — instala dependencias Python y registra la tarea programada 'ClapListener'.
# Debe ejecutarse como administrador.

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Este script requiere privilegios de administrador. Reabriendo elevado...' -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$listener = Join-Path $root 'clap_listener.py'
$requirements = Join-Path $root 'requirements.txt'
$taskName = 'ClapListener'

Write-Host '== Comprobando Python ==' -ForegroundColor Cyan
$python = (Get-Command python.exe -ErrorAction SilentlyContinue).Source
$pythonw = (Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source
if (-not $python -or -not $pythonw) {
    Write-Host 'Python no encontrado en PATH. Instálalo desde python.org y vuelve a intentar.' -ForegroundColor Red
    exit 1
}
Write-Host "  python  = $python"
Write-Host "  pythonw = $pythonw"

Write-Host '== Instalando dependencias ==' -ForegroundColor Cyan
& $python -m pip install --upgrade pip
& $python -m pip install -r $requirements

Write-Host '== Comprobando claude CLI ==' -ForegroundColor Cyan
$claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claude) {
    Write-Host 'Aviso: claude no está en PATH. Instálalo o añádelo a PATH antes de probar.' -ForegroundColor Yellow
} else {
    Write-Host "  claude = $claude"
}

Write-Host '== Registrando tarea programada ==' -ForegroundColor Cyan
$currentUser = "$env:USERDOMAIN\$env:USERNAME"
$trAction = "`"$pythonw`" `"$listener`""

# Elimina tarea previa si existe
cmd /c "schtasks /Query /TN $taskName >nul 2>&1"
if ($LASTEXITCODE -eq 0) {
    schtasks /Delete /TN $taskName /F | Out-Null
}

schtasks /Create `
    /TN $taskName `
    /TR $trAction `
    /SC ONLOGON `
    /RL HIGHEST `
    /RU $currentUser `
    /F | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error al crear la tarea (código $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}

Write-Host "Tarea '$taskName' creada para usuario $currentUser." -ForegroundColor Green
Write-Host ''
Write-Host '== Arrancando ahora (sin esperar al siguiente logon) ==' -ForegroundColor Cyan
schtasks /Run /TN $taskName | Out-Null
$configPath = Join-Path $root 'config.json'
$claps = (Get-Content $configPath -Raw | ConvertFrom-Json).claps_required
Write-Host "Detector corriendo en segundo plano. Prueba dando $claps palmadas." -ForegroundColor Green
Write-Host "Log: $(Join-Path $root 'clap_listener.log')"
