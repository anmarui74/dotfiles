#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Reflow: un parrafo = una linea. Une las lineas partidas a mano dentro de un mismo parrafo,
respetando titulos, listas, tablas, bloques de codigo, citas/callouts, reglas horizontales y
frontmatter. Verifica que el TEXTO PLANO no cambia (solo se juntan lineas).

Uso:  reflow-md.py [--dry] ruta1 ruta2 ...
No toca las copias (documentos/, sesion-hermes/): esas se regeneran desde el original.
"""
import os, re, sys

EXCL_DIRS = {"node_modules", "__pycache__", "backups", "logs", "state", "sesion-hermes", "documentos", ".obsidian",
             ".git", "installs", "hermes-agent", "_mojibake-backup", "target",
             "venv", ".venv", "site-packages", "Lib", "dist-info", "sessions", "cache"}
REGLA = re.compile(r"^\s*([-*_])\s*(\1\s*){2,}$")


PREFIJO_CITA = re.compile(r"^(?:\s*>\s*)+")


def sin_cita(l):
    """Quita el prefijo de cita ("> ", ">> ", "> > ") para mirar lo que hay debajo."""
    return PREFIJO_CITA.sub("", l)


def es_fence(l):
    s = sin_cita(l).strip()          # una valla dentro de una cita ("> ```bash") tambien abre codigo
    return s.startswith("```") or s.startswith("~~~")


def es_bloque(l):
    """Abre bloque propio: titulo, lista, tabla, cita, regla, HTML."""
    s = l.lstrip()
    if not s:
        return True
    if s.startswith("#") or s.startswith("|") or s.startswith(">"):
        return True
    if s.startswith("<"):
        return True
    if re.match(r"^([-*+]|\d+[.)])\s", s):
        return True
    if REGLA.match(l):
        return True
    return False


def corto(p):
    """Ruta abreviada para el log. En Windows relpath falla entre unidades (C: -> D:)."""
    try:
        return os.path.relpath(p, os.path.expanduser("~"))
    except ValueError:
        return p


def reflow(texto):
    lineas = texto.split("\n")
    salida = []
    enCodigo = False
    frontmatter = False
    if lineas and lineas[0].strip() == "---":
        frontmatter = True
    for idx, l in enumerate(lineas):
        if frontmatter:
            salida.append(l)
            if idx > 0 and l.strip() == "---":
                frontmatter = False
            continue
        if es_fence(l):
            enCodigo = not enCodigo
            salida.append(l)
            continue
        if enCodigo or not l.strip():
            salida.append(l)
            continue
        prev = salida[-1] if salida else ""
        sangrada = l != l.lstrip()
        unir = False
        if prev.strip() and not es_fence(prev):
            prevCita = prev.lstrip().startswith(">")
            curCita = l.lstrip().startswith(">")
            if prevCita and curCita:
                cont = sin_cita(l).lstrip()
                cabecera = sin_cita(prev).lstrip().startswith("[")   # "> [!note] Titulo"
                # no unir: ni sobre una cabecera de callout, ni otra cabecera, ni bloque nuevo, ni valla
                unir = bool(cont) and not cabecera and not (
                    cont.startswith("[") or cont.startswith("#") or cont.startswith("|")
                    or re.match(r"^([-*+]|\d+[.)])\s", cont) or es_fence(l))
            elif not es_bloque(prev) and (not es_bloque(l) or sangrada):
                unir = True
            elif es_bloque(prev) and sangrada and not es_bloque(l):
                unir = True                                    # continuacion sangrada de un item
        if unir:
            if prev.lstrip().startswith(">"):
                salida[-1] = prev.rstrip() + " " + sin_cita(l).strip()   # sin el ">" de continuacion
            else:
                salida[-1] = prev.rstrip() + " " + l.strip()
        else:
            salida.append(l)
    return "\n".join(salida)


def plano(t):
    """Texto comparable: sin markdown, sin espacios de más y sin marcas de cita.

    Las marcas '>' se quitan a propósito: al unir una cita, el '>' de la línea de
    continuación desaparece, y eso no es un cambio de texto.
    """
    t = t.replace("**", "").replace("*", "").replace("`", "")
    t = re.sub(r"(?m)^\s*(?:>\s*)+", "", t)
    return re.sub(r"\s+", " ", t).strip()


dry = "--dry" in sys.argv
raices = [a for a in sys.argv[1:] if not a.startswith("--")]
vistos, n_ficheros, n_cortes, problemas = set(), 0, 0, []

candidatos = []
for raiz in raices:
    if os.path.isfile(raiz):
        candidatos.append(raiz)
    else:
        for root, dirs, files in os.walk(raiz):
            dirs[:] = [d for d in dirs if d not in EXCL_DIRS]
            for f in files:
                if f.endswith(".md"):
                    candidatos.append(os.path.join(root, f))

if True:
    for p in sorted(candidatos):
            if p in vistos:
                continue
            vistos.add(p)
            datos = open(p, "rb").read()
            crlf = b"\r\n" in datos
            bom = datos.startswith(b"\xef\xbb\xbf")
            original = datos.decode("utf-8-sig" if bom else "utf-8").replace("\r\n", "\n")
            nuevo = reflow(original)
            if nuevo == original:
                continue
            if plano(original) != plano(nuevo):
                problemas.append(p)
                continue
            n_ficheros += 1
            n_cortes += len(original.split("\n")) - len(nuevo.split("\n"))
            if not dry:
                salida = nuevo.replace("\n", "\r\n") if crlf else nuevo
                b = salida.encode("utf-8")
                if bom:
                    b = b"\xef\xbb\xbf" + b
                open(p, "wb").write(b)
            print("  %-64s %3d -> %3d lineas%s" % (corto(p)[:64],
                                                 len(original.split("\n")), len(nuevo.split("\n")),
                                                 "  [CRLF]" if crlf else ""))
print("\n%d ficheros %s · %d lineas unidas · %d con texto alterado (NO tocados)"
      % (n_ficheros, "revisados (dry)" if dry else "reflowados", n_cortes, len(problemas)))
for p in problemas:
    print("   AVISO texto cambiado:", p)
