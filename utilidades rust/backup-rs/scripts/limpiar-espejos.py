#!/usr/bin/env python3
"""Compara los espejos de backup-rs con sus origenes y reporta residuos.

Modo informe (por defecto): lista lo que sobra en el espejo y los directorios
vacios que faltan.  Con --borrar aplica los borrados (solo lo sobrante).
"""
import os
import sys
from pathlib import Path

ORIGENES = [
    "/home/antonio/Config",
    "/home/antonio/Documentos",
    "/home/antonio/Descargas",
    "/home/antonio/Imágenes",
    "/home/antonio/Vídeos",
    "/home/antonio/Cursos informatica",
    "/home/antonio/Varios Linux",
    "/home/antonio/start-lmstudio.sh",
    "/home/antonio/system-info.sh",
    "/home/antonio/modelos_ia",
]

ESPEJOS = [
    "/mnt/seagate/Linux",
    "/home/antonio/MyCloud/antonio/Linux",
    "/home/antonio/MyCloud/public/Linux",
]

borrar = "--borrar" in sys.argv


def recorrer(base, sobrantes, faltan):
    """Walk del espejo: lo que no existe en origen es sobrante."""
    for raiz, dirs, ficheros in os.walk(base, topdown=True, followlinks=False):
        rel = os.path.relpath(raiz, base)
        # raiz del origen correspondiente
        oroot = ORIGENES[0] if rel == "." else None
        # comprobacion: raiz del espejo se compara elemento a elemento
        for d in list(dirs):
            p_esp = os.path.join(raiz, d)
            rel_d = os.path.relpath(p_esp, base)
            p_orig = "/home/antonio/" + rel_d
            if not os.path.lexists(p_orig):
                sobrantes.append(("dir", p_esp))
                dirs.remove(d)  # no seguir bajando: se borra entero
        for f in ficheros:
            p_esp = os.path.join(raiz, f)
            rel_f = os.path.relpath(p_esp, base)
            p_orig = "/home/antonio/" + rel_f
            if not os.path.lexists(p_orig):
                sobrantes.append(("file", p_esp))


def dirs_vacios_origen(sobrantes):
    """Directorios vacios del origen que no existen en el espejo."""
    faltan = []
    for origen in ORIGENES:
        op = Path(origen)
        if not op.is_dir():
            continue
        for raiz, dirs, ficheros in os.walk(origen, topdown=True):
            if not dirs and not ficheros:
                rel = os.path.relpath(raiz, "/home/antonio")
                esp = None
                faltan.append(("vacío", raiz, rel))
    return faltan


total_sobra = 0
for espejo in ESPEJOS:
    sobrantes = []
    if not os.path.ismount(espejo) and not espejo.startswith("/mnt/seagate"):
        # los nube son subcarpetas de un montaje CIFS: comprobar solo existencia
        if not os.path.isdir(espejo):
            print(f"!! {espejo} no accesible, salto")
            continue
    if not os.path.isdir(espejo):
        print(f"!! {espejo} no accesible, salto")
        continue
    recorrer(espejo, sobrantes, None)
    total_sobra += len(sobrantes)
    print(f"\n=== {espejo}: {len(sobrantes)} entradas sobrantes ===")
    for tipo, ruta in sobrantes[:400]:
        print(f"  [{tipo}] {ruta}")
    if len(sobrantes) > 400:
        print(f"  ... y {len(sobrantes)-400} más")
    if borrar:
        import shutil
        n = 0
        for tipo, ruta in sorted(sobrantes, key=lambda x: -len(x[1])):
            try:
                if os.path.isdir(ruta) and not os.path.islink(ruta):
                    shutil.rmtree(ruta)
                else:
                    os.remove(ruta)
                n += 1
            except Exception as e:
                print(f"  !! fallo borrando {ruta}: {e}")
        print(f"  BORRADOS: {n}")

print(f"\nTOTAL sobrantes en los espejos: {total_sobra}")
print(f"Modo: {'BORRAR' if borrar else 'informe'}")
