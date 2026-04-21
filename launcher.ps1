# Menú de carpetas de C:\dev. Disparado por clap_listener.py tras las palmadas.
# Hereda token admin del proceso padre (tarea programada con privilegios elevados).
# Navegación con flechas ↑/↓, Enter selecciona, Esc/Q cancela.

$ErrorActionPreference = 'Stop'
$base = 'C:\dev'

try {
    $Host.UI.RawUI.BackgroundColor = 'Black'
    $Host.UI.RawUI.ForegroundColor = 'White'
    $Host.UI.RawUI.WindowTitle = 'Palmadas -> Claude'
    Clear-Host
} catch {}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$hostLabel = if ($isAdmin) { 'Administrador' } else { 'NO admin' }

if (-not (Test-Path $base)) {
    Write-Host "La carpeta $base no existe." -ForegroundColor Red
    Read-Host 'Pulsa Enter para cerrar'
    exit 1
}

$dirs = Get-ChildItem -Path $base -Directory | Where-Object { -not $_.Name.StartsWith('.') } | Sort-Object Name
if ($dirs.Count -eq 0) {
    Write-Host "No hay subcarpetas en $base." -ForegroundColor Yellow
    Read-Host 'Pulsa Enter para cerrar'
    exit 1
}

function Show-Menu {
    param(
        [string[]] $Items,
        [int] $Selected,
        [string] $Title
    )
    Clear-Host
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "(↑/↓ navegar · Enter seleccionar · Esc/Q cancelar)" -ForegroundColor DarkGray
    Write-Host ""
    for ($i = 0; $i -lt $Items.Count; $i++) {
        if ($i -eq $Selected) {
            Write-Host ("  > " + $Items[$i]) -ForegroundColor Black -BackgroundColor Green
        } else {
            Write-Host ("    " + $Items[$i])
        }
    }
}

$names = @($dirs | ForEach-Object { $_.Name })
$selected = 0
$done = $false
$cancelled = $false
$title = "=== Palmadas → Claude ($hostLabel) ==="

try {
    [System.Console]::CursorVisible = $false
    while (-not $done) {
        Show-Menu -Items $names -Selected $selected -Title $title
        $key = [System.Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow'   { $selected = ($selected - 1 + $names.Count) % $names.Count }
            'DownArrow' { $selected = ($selected + 1) % $names.Count }
            'Home'      { $selected = 0 }
            'End'       { $selected = $names.Count - 1 }
            'Enter'     { $done = $true }
            'Spacebar'  { $done = $true }
            'Escape'    { $cancelled = $true; $done = $true }
            'Q'         { $cancelled = $true; $done = $true }
        }
    }
} finally {
    [System.Console]::CursorVisible = $true
}

if ($cancelled) {
    Clear-Host
    Write-Host 'Cancelado.' -ForegroundColor DarkGray
    exit 0
}

$target = $dirs[$selected].FullName
Clear-Host
Write-Host "→ $target" -ForegroundColor Green
Set-Location $target
claude
