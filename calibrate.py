"""
Modo calibración: imprime PICO absoluto y RMS por bloque.
Útil para ajustar 'peak_threshold' (detector) en config.json.

Objetivo: identificar 'peak_threshold' que deje tus palmadas por encima y el ruido
ambiente por debajo. Por ejemplo, si las palmadas dan pico 0.4-0.8 y el ruido ~0.02,
un umbral de 0.2 funciona bien.
"""
import json
import time
from pathlib import Path

import numpy as np
import sounddevice as sd

CONFIG_PATH = Path(__file__).with_name("config.json")


def main() -> None:
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        cfg = json.load(f)

    samplerate = cfg.get("samplerate")  # None => usa el del device
    block_ms = cfg["block_ms"]
    device = cfg.get("input_device")

    # Resolve effective sample rate
    if samplerate is None:
        info = sd.query_devices(device=device, kind="input")
        samplerate = int(info["default_samplerate"])
    samplerate = int(samplerate)
    block_size = int(samplerate * block_ms / 1000)

    print(f"Device      = {device or 'default'}")
    print(f"Sample rate = {samplerate} Hz, block = {block_ms} ms ({block_size} samples)")
    print(f"peak_threshold actual = {cfg.get('peak_threshold', 0.3)}")
    print(f"rms_threshold actual  = {cfg.get('rms_threshold', 0.25)}")
    print("Se imprime solo si peak > 0.01. Ctrl+C para salir.\n")

    state = {"max_peak": 0.0, "max_rms": 0.0}

    def on_audio(indata, frames, time_info, status):
        if status:
            print("status:", status)
        mono = indata[:, 0] if indata.ndim > 1 else indata
        mono = mono.astype(np.float32)
        peak = float(np.max(np.abs(mono)))
        rms = float(np.sqrt(np.mean(mono * mono)))

        if peak > state["max_peak"]:
            state["max_peak"] = peak
        if rms > state["max_rms"]:
            state["max_rms"] = rms

        if peak > 0.01:
            bar_peak = "#" * min(60, int(peak * 60))
            print(
                f"peak={peak:5.3f}  rms={rms:5.3f}  "
                f"max_peak={state['max_peak']:5.3f}  max_rms={state['max_rms']:5.3f}  |{bar_peak}"
            )

    with sd.InputStream(
        samplerate=samplerate,
        channels=1,
        dtype="float32",
        blocksize=block_size,
        callback=on_audio,
        device=device,
    ):
        try:
            while True:
                time.sleep(3600)
        except KeyboardInterrupt:
            print(
                f"\nResumen: max_peak={state['max_peak']:.3f}, max_rms={state['max_rms']:.3f}"
            )
            print("Ajusta 'peak_threshold' en config.json entre ruido ambiente y tus palmadas.")


if __name__ == "__main__":
    main()
