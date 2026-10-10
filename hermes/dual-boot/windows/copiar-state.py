#!/usr/bin/env python3
"""Utilidades SQLite para hermes-dual-sync.ps1 (Windows).

Se usa el módulo estándar sqlite3, así que sirve el Python que Hermes instala
junto a la aplicación (uv/venv). Sin dependencias externas.

  copiar-state.py <origen> <destino>     copia consistente (API .backup, incluye el WAL)
  copiar-state.py --contar <bd>          nº de sesiones
  copiar-state.py --contar-mensajes <bd> nº de mensajes
  copiar-state.py --integridad <bd>      imprime 'ok' si la base está sana
  copiar-state.py --fusionar <origen> <destino>  añade a <destino> las sesiones que
                                         le falten de <origen> (import con Hermes
                                         en marcha; no sustituye la base)
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
    if argv[1] == "--fusionar" and len(argv) == 4:
        return fusionar(argv[2], argv[3])
    if len(argv) == 3:
        return copiar(argv[1], argv[2])
    print(__doc__)
    return 2




def fusionar(origen: str, destino: str) -> int:
    """Fusiona en `destino` las sesiones que le falten de `origen`.

    Se usa cuando Hermes está en marcha: no se puede sustituir state.db (una base
    abierta por el gateway quedaría ilegible), pero sí escribir en ella.  No borra
    ni sustituye nada: solo añade las sesiones que falten (con sus mensajes,
    prompts y datos de uso) y avisa de las que existan en ambos lados con más
    mensajes en el origen.
    """
    if not os.path.exists(origen):
        print(f"no existe {origen}", file=sys.stderr)
        return 1
    con = sqlite3.connect(destino, timeout=30)
    try:
        con.execute("pragma busy_timeout=30000")
        con.execute("attach database ? as w", (origen,))

        def tablas(esquema: str = "") -> set:
            pref = f"{esquema}." if esquema else ""
            return {f[0] for f in con.execute(f"select name from {pref}sqlite_master where type='table'")}

        def columnas(tabla: str, esquema: str = "") -> list:
            pref = f"{esquema}." if esquema else ""
            return [f[1] for f in con.execute(f"pragma {pref}table_info({tabla})")]

        locales, remotas = tablas(), tablas("w")
        ids = [f[0] for f in con.execute(
            "select id from w.sessions where id not in (select id from sessions)")]
        antes = con.execute("select count(*) from messages").fetchone()[0]
        if ids:
            marcas = ",".join("?" * len(ids))
            try:
                con.execute("begin immediate")
                if "system_prompts" in locales and "system_prompts" in remotas:
                    cols = [c for c in columnas("system_prompts") if c in columnas("system_prompts", "w")]
                    con.execute(
                        f"insert or ignore into system_prompts({','.join(cols)}) "
                        f"select {','.join(cols)} from w.system_prompts where hash in "
                        f"(select system_prompt_hash from w.sessions where id in ({marcas}))", ids)
                for tabla, col in (("sessions", "id"), ("session_model_usage", "session_id")):
                    if tabla in locales and tabla in remotas:
                        cols = [c for c in columnas(tabla) if c in columnas(tabla, "w")]
                        con.execute(
                            f"insert or ignore into {tabla}({','.join(cols)}) "
                            f"select {','.join(cols)} from w.{tabla} where {col} in ({marcas})", ids)
                if "messages" in locales and "messages" in remotas:
                    cols = [c for c in columnas("messages")
                            if c != "id" and c in columnas("messages", "w")]
                    con.execute(
                        f"insert into messages({','.join(cols)}) select {','.join(cols)} "
                        f"from w.messages where session_id in ({marcas}) order by id", ids)
                con.commit()
            except sqlite3.Error as exc:
                con.rollback()
                print(f"error: {exc}", file=sys.stderr)
                return 1
        despues = con.execute("select count(*) from messages").fetchone()[0]
        divergentes = con.execute(
            "select count(*) from w.sessions r join sessions l on l.id = r.id "
            "where r.message_count > l.message_count").fetchone()[0]
        print(f"sesiones nuevas: {len(ids)}")
        print(f"mensajes anadidos: {despues - antes}")
        print(f"sesiones en ambos lados con mas mensajes en el origen: {divergentes}")
        print(f"integridad: {con.execute('pragma integrity_check').fetchone()[0]}")
        for f in con.execute(
                f"select id, substr(coalesce(title,''),1,50), message_count "
                f"from sessions where id in ({','.join('?' * len(ids))}) order by started_at", ids) if ids else ():
            print(f"  - {f[0]} | {f[1]} | {f[2]} mensajes")
        con.execute("detach database w")
        return 0
    finally:
        con.close()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
