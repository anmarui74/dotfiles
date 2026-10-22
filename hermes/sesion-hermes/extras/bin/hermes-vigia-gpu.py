#!/usr/bin/env python3
"""Vigia de GPU de Hermes en Linux: registra a 1 Hz y no toca nada.

Una linea CSV por muestra en ~/.local/state/hermes-gpu/gpu-AAAAMMDD.csv con:
temperatura, potencia, uso, VRAM, relojes, pstate, enlace PCIe, ASPM, contadores AER
y cuantos Xid nuevos aparecieron en el kernel desde la muestra anterior.

Cada linea se vuelca al disco al escribirla (flush), de modo que si el equipo se
cuelga se conserva todo hasta el ultimo segundo. Retencion: 10 dias.

Uso:
    hermes-vigia-gpu.py            # bucle normal (lo lanza systemd)
    hermes-vigia-gpu.py --una      # una sola muestra y sale (para probar)
    hermes-vigia-gpu.py --estado   # resumen de lo registrado hoy
"""
from __future__ import annotations

import os
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

ESTADO = Path.home() / ".local/state/hermes-gpu"
INTERVALO = 1.0          # segundos entre muestras
FSYNC_CADA = 60          # volcado fisico cada minuto
XID_CADA = 30            # revisar el journal cada 30 muestras
RETENCION_DIAS = 10
GPU_PCI = "0000:01:00.0"

CABECERA = ("muestra,instante,temp_c,potencia_w,uso_pct,vram_mb,clock_sm_mhz,clock_mem_mhz,"
            "pstate,enlace_vel,enlace_ancho,l1_aspm,aer_corr,aer_fatal,aer_nonfatal,xid_nuevo,nvidia_smi_ok")


def leer(ruta: str) -> str:
    try:
        return Path(ruta).read_text().strip()
    except OSError:
        return ""


def aer(campo: str) -> str:
    txt = leer(f"/sys/bus/pci/devices/{GPU_PCI}/{campo}")
    for linea in txt.splitlines():
        if linea.startswith("TOTAL_ERR_"):
            return linea.split()[-1]
    return ""


def nvidia() -> list[str]:
    """Una sola llamada a nvidia-smi: devuelve los 7 campos o vacios si falla."""
    try:
        r = subprocess.run(
            ["nvidia-smi", "--query-gpu=temperature.gpu,power.draw,utilization.gpu,memory.used,"
                            "clocks.sm,clocks.mem,pstate",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return [""] * 7
    if r.returncode != 0:
        return [""] * 7
    campos = [c.strip() for c in r.stdout.splitlines()[0].split(",")]
    return (campos + [""] * 7)[:7]


def xid_nuevos(desde: str) -> str:
    """Cuenta NVRM: Xid aparecidos en el kernel desde el instante dado."""
    try:
        r = subprocess.run(["journalctl", "-k", "--since", desde, "--no-pager", "-o", "cat"],
                           capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return str(sum(1 for l in r.stdout.splitlines() if "NVRM: Xid" in l))


def limpia_viejos() -> None:
    limite = datetime.now() - timedelta(days=RETENCION_DIAS)
    for f in ESTADO.glob("gpu-*.csv"):
        try:
            fecha = datetime.strptime(f.stem[4:], "%Y%m%d")
        except ValueError:
            continue
        if fecha < limite:
            f.unlink(missing_ok=True)


def fichero_de_hoy() -> Path:
    return ESTADO / f"gpu-{datetime.now():%Y%m%d}.csv"


def una_muestra(n: int, fh, comprobar_xid: bool, desde: str) -> None:
    instante = datetime.now().astimezone().isoformat(timespec="seconds")
    temp, pot, uso, vram, sm, mem, pst = nvidia()
    ok = "1" if temp else "0"
    linea = ",".join([
        str(n), instante, temp, pot, uso, vram, sm, mem, pst,
        leer(f"/sys/bus/pci/devices/{GPU_PCI}/current_link_speed").replace(" PCIe", ""),
        leer(f"/sys/bus/pci/devices/{GPU_PCI}/current_link_width"),
        leer(f"/sys/bus/pci/devices/{GPU_PCI}/link/l1_aspm"),
        aer("aer_dev_correctable"), aer("aer_dev_fatal"), aer("aer_dev_nonfatal"),
        xid_nuevos(desde) if comprobar_xid else "0",
        ok,
    ])
    fh.write(linea + "\n")
    fh.flush()


def main() -> int:
    ESTADO.mkdir(parents=True, exist_ok=True)
    if "--estado" in sys.argv:
        f = fichero_de_hoy()
        if not f.exists():
            print("todavia no hay muestras hoy")
            return 0
        lineas = f.read_text().splitlines()
        print(f"{f}  ({len(lineas) - 1} muestras)")
        print("  " + lineas[0])
        for l in lineas[-3:]:
            print("  " + l)
        return 0

    una = "--una" in sys.argv
    pidfile = ESTADO / "vigia.pid"
    if not una:
        # una sola instancia
        import fcntl
        lock = open(pidfile, "w")
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            print("ya hay un vigia en marcha", file=sys.stderr)
            return 0
        lock.write(str(os.getpid()))
        lock.flush()

    f = fichero_de_hoy()
    nuevo = not f.exists()
    fh = open(f, "a", buffering=1)
    if nuevo:
        fh.write(CABECERA + "\n")
        limpia_viejos()

    n = 0
    desde = datetime.now().astimezone().isoformat(timespec="seconds")
    try:
        while True:
            t0 = time.monotonic()
            n += 1
            toca_xid = (n % XID_CADA == 0)
            una_muestra(n, fh, toca_xid, desde)
            if toca_xid:
                desde = datetime.now().astimezone().isoformat(timespec="seconds")
            if n % FSYNC_CADA == 0:
                fh.flush()
                os.fsync(fh.fileno())
            if una:
                return 0
            espera = INTERVALO - (time.monotonic() - t0)
            if espera > 0:
                time.sleep(espera)
    except KeyboardInterrupt:
        return 0
    finally:
        fh.close()


if __name__ == "__main__":
    sys.exit(main())
