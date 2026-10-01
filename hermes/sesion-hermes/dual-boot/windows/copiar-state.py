#!/usr/bin/env python3
"""Utilidades SQLite para hermes-dual-sync.ps1 (Windows).

Se usa el módulo estándar sqlite3, así que sirve el Python que Hermes instala
junto a la aplicación (uv/venv). Sin dependencias externas.

  copiar-state.py <origen> <destino>     copia consistente (API .backup, incluye el WAL)
  copiar-state.py --contar <bd>          nº de sesiones
  copiar-state.py --contar-mensajes <bd> nº de mensajes
  copiar-state.py --integridad <bd>      imprime 'ok' si la base está sana
"""
import os
import sqlite3
import sys


def _conectar(ruta: str) -> sqlite3.Connection:
    return sqlite3.connect(f"file:{ruta}?mode=ro", uri=True)


def copiar(origen: str, destino: str) -> int:
    if not os.path.exists(origen):
        print(f"no existe {origen}", file=sys.stderr)
        return 1
    for sufijo in ("", "-wal", "-shm"):
        if os.path.exists(destino + sufijo):
            os.remove(destino + sufijo)
    src = sqlite3.connect(origen)
    try:
        dst = sqlite3.connect(destino)
        try:
            src.backup(dst)
        finally:
            dst.close()
    finally:
        src.close()
    # la copia no debe dejar un WAL huérfano al lado del destino
    for sufijo in ("-wal", "-shm"):
        if os.path.exists(destino + sufijo):
            os.remove(destino + sufijo)
    return 0


def contar(ruta: str, tabla: str) -> int:
    try:
        con = _conectar(ruta)
        try:
            return int(con.execute(f"SELECT COUNT(*) FROM {tabla}").fetchone()[0])
        finally:
            con.close()
    except sqlite3.Error as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 0


def integridad(ruta: str) -> int:
    try:
        con = _conectar(ruta)
        try:
            print(con.execute("PRAGMA integrity_check").fetchone()[0])
        finally:
            con.close()
    except sqlite3.Error as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    if argv[1] == "--contar" and len(argv) == 3:
        print(contar(argv[2], "sessions"))
        return 0
    if argv[1] == "--contar-mensajes" and len(argv) == 3:
        print(contar(argv[2], "messages"))
        return 0
    if argv[1] == "--integridad" and len(argv) == 3:
        return integridad(argv[2])
    if len(argv) == 3:
        return copiar(argv[1], argv[2])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
