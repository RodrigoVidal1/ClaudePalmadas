# setupPalmadas

Detector de palmadas en Windows: cuando detecta 2 palmadas seguidas, abre una PowerShell con privilegios de administrador que muestra un menú navegable (↑/↓) con las subcarpetas de `C:\dev`. Al elegir una, hace `cd` y lanza `claude` (Claude Code).

## Requisitos

- Windows 10/11
- Python 3.10+ en PATH (probado con 3.14)
- Claude Code CLI (`claude`) en PATH
- Micrófono funcional como dispositivo de entrada por defecto
- Usuario en grupo Administradores (se auto-eleva al instalar)

## Instalación

```powershell
powershell -ExecutionPolicy Bypass -File C:\dev\setupPalmadas\install.ps1
```

El script:
1. Se auto-eleva a administrador si hace falta.
2. Instala dependencias Python (`sounddevice`, `numpy`).
3. Registra la tarea programada **ClapListener** para arrancar al iniciar sesión con privilegios elevados.
4. Inicia el detector en segundo plano (no hace falta reiniciar).

A partir de aquí el detector arranca solo en cada inicio de sesión.

## Uso

Da **2 palmadas** con ritmo normal (120–900 ms entre ellas). Se abre una PowerShell admin con:

- **↑ / ↓** — moverse por la lista (con wraparound)
- **Home / End** — ir al principio / al final
- **Enter** o **Space** — seleccionar carpeta
- **Esc** o **Q** — cancelar

Al elegir, la ventana queda en la carpeta seleccionada con `claude` corriendo. Carpetas que empiezan por `.` (como `.git`, `.claude`) no se listan.

## Prueba manual (sin instalar)

Para probar el detector en primer plano viendo los logs en la consola:

```powershell
python C:\dev\setupPalmadas\clap_listener.py
```

Ctrl+C para parar. El log también se escribe en `clap_listener.log`.

## Calibración del micrófono

Si la detección falla (no pilla palmadas o se dispara con ruidos), lanza el modo calibración:

```powershell
python C:\dev\setupPalmadas\calibrate.py
```

Imprime el pico y RMS de cada bloque de audio. Haz:

1. Silencio 2 s → observa el ruido de fondo (normal: <0.02)
2. Da unas 10 palmadas normales → observa el pico (normal: 0.25–0.7)
3. Habla fuerte / escribe / click → observa esos picos
4. Ctrl+C para ver `max_peak` y `max_rms`

Ajusta en `config.json`:

- `peak_threshold` — debe quedar **por encima del ruido/tecleo** y **por debajo de palmadas**. Valor inicial: `0.2`. Si las palmadas dan 0.15, bájalo a `0.10`.
- `claps_required` — número de palmadas necesarias (2 por defecto, subir a 3 reduce falsos positivos).
- `min_gap_ms` / `max_gap_ms` — ritmo aceptado entre palmadas.
- `window_ms` — tiempo total máximo para completar la secuencia.
- `cooldown_ms` — tras un disparo, cuánto ignorar (evita dobles aperturas).

Tras editar `config.json`, reinicia el detector:

```powershell
schtasks /End /TN ClapListener
schtasks /Run /TN ClapListener
```

## Desinstalación

```powershell
powershell -ExecutionPolicy Bypass -File C:\dev\setupPalmadas\uninstall.ps1
```

Elimina la tarea programada y mata el proceso si está corriendo.

## Estructura de archivos

| Archivo | Qué hace |
|---|---|
| `clap_listener.py` | Daemon: captura audio y dispara el launcher con N palmadas |
| `launcher.ps1` | Menú navegable de carpetas de `C:\dev` + lanza `claude` |
| `calibrate.py` | Diagnóstico del micrófono (pico/RMS en tiempo real) |
| `config.json` | Parámetros de detección (umbrales, gaps, rutas) |
| `install.ps1` | Instalación (auto-eleva, instala deps, registra tarea) |
| `uninstall.ps1` | Desinstalación (borra tarea y mata proceso) |
| `requirements.txt` | Deps Python |
| `clap_listener.log` | Log de eventos (se crea al correr el detector) |

## Troubleshooting

- **No abre la PowerShell** → revisa `clap_listener.log`. Si hay líneas `clap detected` pero nunca `pattern matched`, ajusta `min_gap_ms`/`max_gap_ms` al ritmo real de tus palmadas.
- **Se abre solo (falsos positivos)** → sube `peak_threshold` o `claps_required`.
- **No detecta nada** → verifica el micrófono activo en Windows (Configuración → Sistema → Sonido → Entrada) y corre `calibrate.py` para ver si llegan datos.
- **UAC salta al abrir la PowerShell** → la tarea no está en modo `HIGHEST`. Reinstala con `install.ps1`.
- **`claude` no se encuentra** → verifica con `where claude` que está en PATH. Si no, reinstálalo o añádelo.

## Comprobar estado de la tarea

```powershell
schtasks /Query /TN ClapListener /V /FO LIST
```
