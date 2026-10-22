#!/usr/bin/env python3
"""Crea en los espejos los directorios VACIOS del origen que falten.

backup-rs no copia directorios vacios; este script los replica para que el
espejo refleje fielmente la estructura del origen.
"""
import os
import sys

ORIGENES = [
    "/home/antonio/Config",
    "/home/antonio/Documentos",
    "/home/antonio/Descargas",
    "/home/antonio/Imágenes",
    "/home/antonio/Vídeos",
    "/home/antonio/Cursos informatica",
    "/home/antonio/Varios Linux",
    "/home/antonio/modelos_ia",
]

ESPEJOS = [
    "/mnt/seagate/Linux",
    "/home/antonio/MyCloud/antonio/Linux",
    "/home/antonio/MyCloud/public/Linux",
]

aplicar = "--crear" in sys.argv
total = 0

for origen in ORIGENES:
    for raiz, dirs, ficheros in os.walk(origen, topdown=True):
        if dirs or ficheros:
            continue  # no esta vacio
        rel = os.path.relpath(raiz, "/home/antonio")
        for espejo in ESPEJOS:
            destino = os.path.join(espejo, rel)
            if os.path.isdir(espejo) and not os.path.lexists(destino):
                total += 1
                print(f"FALTA en {espejo}: {rel}")
                if aplicar:
                    try:
                        os.makedirs(destino, exist_ok=True)
                    except Exception as e:
                        print(f"   !! fallo: {e}")

print(f"TOTAL directorios vacios que faltaban: {total}  (modo {'CREAR' if aplicar else 'informe'})")
