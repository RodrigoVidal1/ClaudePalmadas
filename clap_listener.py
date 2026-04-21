"""
Daemon que escucha el micrófono y lanza launcher.ps1 al detectar 3 palmadas.
Registrado como tarea programada 'ClapListener' (al iniciar sesión, privilegios elevados).
Detección basada en PICO absoluto (más sensible a transientes cortos como palmadas).
"""
import json
import logging
import os
import shutil
import subprocess
import sys
import time
from collections import deque
from pathlib import Path

import numpy as np
import sounddevice as sd

CONFIG_PATH = Path(__file__).with_name("config.json")


def load_config() -> dict:
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def setup_logging(log_path: str) -> None:
    logging.basicConfig(
        filename=log_path,
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )


def launch_powershell(launcher_script: str) -> None:
    CREATE_NEW_CONSOLE = 0x00000010
    wt = shutil.which("wt.exe") or os.path.join(
        os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WindowsApps", "wt.exe"
    )
    if wt and os.path.exists(wt):
        try:
            subprocess.Popen(
                [
                    wt,
                    "new-tab",
                    "--title", "Palmadas -> Claude",
                    "powershell.exe",
                    "-NoExit",
                    "-ExecutionPolicy", "Bypass",
                    "-File", launcher_script,
                ],
                close_fds=True,
            )
            return
        except OSError as exc:
            logging.warning("wt.exe launch failed, falling back to powershell: %s", exc)

    subprocess.Popen(
        [
            "powershell.exe",
            "-NoExit",
            "-ExecutionPolicy", "Bypass",
            "-File", launcher_script,
        ],
        creationflags=CREATE_NEW_CONSOLE,
        close_fds=True,
    )


class ClapDetector:
    def __init__(self, cfg: dict):
        device = cfg.get("input_device")
        samplerate = cfg.get("samplerate")
        if samplerate is None:
            info = sd.query_devices(device=device, kind="input")
            samplerate = int(info["default_samplerate"])
        self.samplerate = int(samplerate)
        self.block_size = int(self.samplerate * cfg["block_ms"] / 1000)

        self.peak_threshold = float(cfg.get("peak_threshold", 0.2))
        self.rms_threshold = float(cfg.get("rms_threshold", 0.0))
        self.refractory_s = cfg["refractory_ms"] / 1000
        self.min_gap_s = cfg["min_gap_ms"] / 1000
        self.max_gap_s = cfg["max_gap_ms"] / 1000
        self.window_s = cfg["window_ms"] / 1000
        self.cooldown_s = cfg["cooldown_ms"] / 1000
        self.claps_required = int(cfg["claps_required"])
        self.launcher_script = cfg["launcher_script"]
        self.input_device = device

        self.clap_times: deque = deque(maxlen=self.claps_required)
        self.last_clap_time = 0.0
        self.cooldown_until = 0.0

    def on_audio(self, indata: np.ndarray, frames: int, time_info, status) -> None:
        if status:
            logging.warning("audio status: %s", status)

        now = time.monotonic()
        if now < self.cooldown_until:
            return

        mono = indata[:, 0] if indata.ndim > 1 else indata
        mono = mono.astype(np.float32)
        peak = float(np.max(np.abs(mono)))
        if peak < self.peak_threshold:
            return

        if self.rms_threshold > 0:
            rms = float(np.sqrt(np.mean(mono * mono)))
            if rms < self.rms_threshold:
                return

        if now - self.last_clap_time < self.refractory_s:
            return

        self.last_clap_time = now
        self.clap_times.append(now)
        logging.info("clap detected (peak=%.3f, count=%d)", peak, len(self.clap_times))

        self._check_pattern(now)

    def _check_pattern(self, now: float) -> None:
        if len(self.clap_times) < self.claps_required:
            return

        times = list(self.clap_times)
        if times[-1] - times[0] > self.window_s:
            return

        for i in range(1, len(times)):
            gap = times[i] - times[i - 1]
            if gap < self.min_gap_s or gap > self.max_gap_s:
                return

        logging.info("3-clap pattern matched, launching")
        try:
            launch_powershell(self.launcher_script)
        except Exception as exc:
            logging.exception("launch failed: %s", exc)

        self.clap_times.clear()
        self.cooldown_until = now + self.cooldown_s

    def run(self) -> None:
        logging.info(
            "starting detector (rate=%d, block=%d, peak_th=%.3f, rms_th=%.3f, device=%s)",
            self.samplerate, self.block_size, self.peak_threshold, self.rms_threshold, self.input_device,
        )
        with sd.InputStream(
            samplerate=self.samplerate,
            channels=1,
            dtype="float32",
            blocksize=self.block_size,
            callback=self.on_audio,
            device=self.input_device,
        ):
            while True:
                time.sleep(3600)


def main() -> int:
    cfg = load_config()
    setup_logging(cfg["log_path"])
    try:
        ClapDetector(cfg).run()
    except KeyboardInterrupt:
        logging.info("stopped by user")
        return 0
    except Exception as exc:
        logging.exception("fatal: %s", exc)
        return 1


if __name__ == "__main__":
    sys.exit(main())
