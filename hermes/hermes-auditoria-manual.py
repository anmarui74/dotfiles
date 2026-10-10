#!/usr/bin/env python3
# hermes-auditoria-manual.py — Contrasta ~/Config/hermes/AGENTS.md con la configuración viva
# de Hermes: inventario del esquema, unidades systemd, alias de modelo, skills propias,
# modelos locales, whitelist NVIDIA, parche del CLI, espejo de Obsidian y copias del manual.
#
# Uso:  hermes-auditoria-manual [--json] [--sin-espejo]
# Salida: 0 = sin desfases · 1 = hay desfases · 2 = error de entorno
#
# Es la comprobación que se ejecuta antes de dar por bueno un cambio del esquema
# (ver ~/Config/hermes/AGENTS.md, sección «Herramientas propias»).
import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
BASE = os.environ.get("BACKUP_BASE", f"{HOME}/Config/hermes")
HERMES = os.environ.get("HERMES_HOME", f"{HOME}/.hermes")
VAULT = os.environ.get("HERMES_VAULT_HERMES", f"{HOME}/MEGA/Obsidian/Obsidian/armarui74/Hermes")
MANUAL = f"{BASE}/AGENTS.md"

JSON_OUT = "--json" in sys.argv
SIN_ESPEJO = "--sin-espejo" in sys.argv

if not os.path.isfile(MANUAL):
    print(f"❌ no encuentro el manual: {MANUAL}", file=sys.stderr)
    sys.exit(2)
MAN = open(MANUAL, encoding="utf-8").read()

fallos, avisos, ok = [], [], 0


def check(cond, msg):
    global ok
    if cond:
        ok += 1
    else:
        fallos.append(msg)


def aviso(msg):
    avisos.append(msg)


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout


def citado(nombre):
    """El manual usa formas abreviadas: 'x.{sh,py}', 'hermes-dual-sync-{import,export,...}.service'."""
    if nombre in MAN:
        return True
    for abrev in re.findall(r"[\w./-]*\{[^{}]+\}[\w./-]*", MAN):
        prefijo, resto = abrev.split("{", 1)
        cuerpo, sufijo = resto.split("}", 1)
        if any(prefijo + p.strip() + sufijo == nombre for p in cuerpo.split(",")):
            return True
    return False


# ─── 1. Inventario: árbol del manual vs directorio real ───
IGNORAR = {"AGENTS.md", "sync.log", "__pycache__"}
for f in sorted(os.listdir(BASE)):
    if f in IGNORAR or f.startswith(".") or ".bak-" in f or f.endswith(".log"):
        continue
    check(citado(f) or f.split(".")[0] in MAN, f"fichero del esquema sin documentar: {f}")

# ─── 2. Unidades systemd del esquema ───
for d in ("units", "dual-boot/systemd-user"):
    p = f"{BASE}/{d}"
    if not os.path.isdir(p):
        aviso(f"no existe {d}/ (¿restauración parcial?)")
        continue
    for u in sorted(os.listdir(p)):
        check(citado(u), f"unidad no citada en el manual: {d}/{u}")

if sh("command -v systemctl"):
    activas = sh("systemctl --user list-unit-files --no-pager --no-legend").split()
    for tok in sorted({t for t in activas if re.match(r"^(hermes|lm-studio)", t)
                       and t.endswith((".service", ".timer", ".path"))}):
        check(citado(tok), f"unidad instalada no citada: {tok}")
else:
    aviso("systemctl no disponible: no se comprueban las unidades instaladas")

# ─── 3. Alias de modelo: config.yaml ↔ tabla del manual ↔ export de Windows ───
cfg = f"{HERMES}/config.yaml"
aliases = {}
if os.path.isfile(cfg):
    bloque = re.search(r"^  aliases:\n((?:    \S+:\s*\S+\n)+)", open(cfg, encoding="utf-8").read(), re.M)
    if bloque:
        aliases = dict(re.findall(r"^    ([a-z0-9-]+):\s*(\S+)$", bloque.group(1), re.M))
tabla = dict(re.findall(r"^\|\s*`([a-z0-9-]+)`\s*\|\s*`([^`]+)`", MAN, re.M))
if aliases:
    check(len(aliases) == len(tabla), f"alias: manual {len(tabla)} vs config {len(aliases)}")
    for k, v in aliases.items():
        check(tabla.get(k) == v, f"alias {k}: manual={tabla.get(k)} config={v}")
else:
    aviso("no pude leer model.aliases de config.yaml")

exp_path = f"{BASE}/dual-boot/windows/alias-modelos.json"
if os.path.isfile(exp_path) and aliases:
    try:
        exp = json.load(open(exp_path, encoding="utf-8"))
        check(exp.get("aliases") == aliases, "alias-modelos.json (Windows) != alias vivos")
    except Exception as e:
        aviso(f"alias-modelos.json ilegible: {e}")

# ─── 4. Skills propias ───
sk = f"{HERMES}/skills/autonomous-ai-agents"
if os.path.isdir(sk):
    propias = sorted(d for d in os.listdir(sk)
                     if d.startswith("hermes-") or d == "modelos-locales-dimensionado")
    for s in propias:
        check(citado(s), f"skill propia no citada en el manual: {s}")

# ─── 5. Modelos locales (no viajan en el tarball) ───
models = f"{HOME}/.lmstudio/models"
if os.path.isdir(models):
    conocidos = ("Qwen3.8-9B-Q6_K", "Qwen3.5-9B-Q6_K", "gemma-4-E4B-it")
    for g in sh(f"find {models} -name '*.gguf'").splitlines():
        check(any(c in os.path.basename(g) for c in conocidos),
              f"modelo sin documentar en ~/.lmstudio/models: {os.path.basename(g)}")
    m = re.search(r"`~/\.lmstudio/models/` \(~(\d+) GB\)", MAN)
    real = sh(f"du -sm {models}").split()
    if m and real:
        real_gb = int(real[0]) // 1024
        check(abs(real_gb - int(m.group(1))) <= 2,
              f"modelos: manual ~{m.group(1)} GB vs real {real_gb} GB")
    elif not m:
        aviso("el manual no declara el tamaño de ~/.lmstudio/models")
else:
    aviso("~/.lmstudio/models no existe: no se comprueba el inventario de modelos")

# ─── 6. Whitelist NVIDIA viva ───
oc = f"{HOME}/.config/opencode/opencode.json"
if os.path.isfile(oc) and os.path.isfile(exp_path):
    try:
        def wls(o):
            if isinstance(o, dict):
                for k, v in o.items():
                    if k == "whitelist" and isinstance(v, list):
                        yield v
                    yield from wls(v)
            elif isinstance(o, list):
                for i in o:
                    yield from wls(i)
        vivo = sorted(next(wls(json.load(open(oc, encoding="utf-8")))))
        exp = sorted(json.load(open(exp_path, encoding="utf-8")).get("whitelist_nvidia", []))
        check(vivo == exp, "whitelist NVIDIA de opencode.json != export de Windows")
    except Exception as e:
        aviso(f"whitelist NVIDIA no comprobable: {e}")

# ─── 7. Piezas del esquema: parche, contexto de LM Studio, python313 ───
parche = f"{BASE}/hermes-parche-ctrlq.sh"
if os.path.isfile(parche) and os.path.isdir(f"{HERMES}/hermes-agent/.git"):
    est = subprocess.run(["bash", parche, "estado"], capture_output=True, text=True).returncode
    if est in (0, 1):
        check(est == 0, "parche Ctrl+Q NO aplicado (hermes-parche-ctrlq aplicar)")
    else:
        aviso("parche Ctrl+Q en conflicto (revisa 'hermes-parche-ctrlq estado')")
sha = sh(f"sha256sum {BASE}/parches/ctrl-q-corta-audio.patch 2>/dev/null").split()
if sha:
    check(sha[0].startswith("8994c93c"), f"sha256 del parche distinto: {sha[0][:12]}")

settings = f"{HOME}/.lmstudio/settings.json"
if os.path.isfile(settings):
    try:
        st = json.load(open(settings, encoding="utf-8")).get("defaultContextLength")
        val = st.get("value", 0) if isinstance(st, dict) else st
        check(int(val) >= 65536, f"defaultContextLength insuficiente: {st}")
    except Exception as e:
        aviso(f"settings.json de LM Studio ilegible: {e}")

if sh("command -v pacman"):
    check(sh("pacman -Q python313").startswith("python313"), "python313 no instalado (stack de voz)")

# ─── 8. Espejo de Obsidian (fiel a los orígenes) ───
NOTAS = [(f"{BASE}/AGENTS.md", "💻 Manual de Hermes — AGENTS.md"),
         (f"{BASE}/sesion-hermes/SOUL.md", "💻 Identidad de Hermes — SOUL.md"),
         (f"{HOME}/Config/Hermes-Win/AGENTS-WIN.md", "💻 Manual de Hermes en Windows — AGENTS-WIN.md"),
         (f"{BASE}/dual-boot/windows/LEEME-comun.md", "💻 Dual boot — Estado compartido · LEEME-comun.md"),
         (f"{BASE}/dual-boot/windows/LEEME-WINDOWS.md", "💻 Dual boot — Windows · LEEME-WINDOWS.md"),
         (f"{BASE}/dual-boot/windows/PARA-WINDOWS-motor-fusion.md", "💻 Dual boot — Motor de fusión · PARA-WINDOWS-motor-fusion.md"),
         (f"{BASE}/dual-boot/windows/PARA-WINDOWS-ajustes-linux.md", "💻 Dual boot — Ajustes de Linux en Windows · PARA-WINDOWS-ajustes-linux.md"),
         (f"{BASE}/dual-boot/windows/PARA-WINDOWS-backup.md", "💻 Dual boot — Backup en Windows · PARA-WINDOWS-backup.md")]
if SIN_ESPEJO or not os.path.isdir(VAULT):
    aviso("espejo de Obsidian no comprobado (vault no accesible o --sin-espejo)")
else:
    for orig, nota in NOTAS:
        ruta = f"{VAULT}/{nota}"
        if not os.path.isfile(orig) or not os.path.isfile(ruta):
            aviso(f"nota del espejo ausente: {nota}")
            continue
        a = open(orig, encoding="utf-8").read().splitlines()
        b = open(ruta, encoding="utf-8").read().splitlines()
        while b and b[0] == "":
            b = b[1:]
        check(a == b, f"nota del vault desfasada: {nota}")
    # enlaces internos del índice
    indice = f"{VAULT}/💻 README.md"
    if os.path.isfile(indice):
        import urllib.parse
        malos = []
        for m in re.finditer(r"\]\(([^)]+)\)", open(indice, encoding="utf-8").read()):
            p = urllib.parse.unquote(m.group(1))
            if p.startswith(("http", "#")):
                continue
            if not os.path.exists(f"{VAULT}/{p if p.endswith('.md') else p + '.md'}"):
                malos.append(p)
        check(not malos, f"enlaces rotos en el índice del vault: {malos}")

# ─── 9. Copias del manual (canónica y saneada) ───
for p in (f"{BASE}/sesion-hermes/AGENTS.md", f"{HOME}/Documentos/dotfiles/hermes/AGENTS.md"):
    if os.path.isfile(p):
        check(open(p, encoding="utf-8").read() == MAN, f"copia del manual desfasada: {p}")
    else:
        aviso(f"copia del manual ausente: {p}")

# ─── 10. El tarball más reciente no es anterior al manual ───
tarballs = sorted(sh(f"ls {BASE}/backups/hermes/hermes-backup-*.tar.gz 2>/dev/null").split())
if tarballs:
    check(os.path.getmtime(tarballs[-1]) > os.path.getmtime(MANUAL),
          "el último tarball es anterior a la última edición del manual (¿backup pendiente?)")
else:
    aviso("sin tarballs en backups/hermes/")

# ─── Informe ───
if JSON_OUT:
    print(json.dumps({"ok": ok, "fallos": fallos, "avisos": avisos}, ensure_ascii=False, indent=2))
else:
    for a in avisos:
        print(f"   ⚠️  {a}")
    if fallos:
        print(f"\n❌ {len(fallos)} desfase(s) entre el manual y la configuración viva:")
        for f in fallos:
            print(f"   - {f}")
        print(f"\n   ({ok} comprobaciones correctas)")
    else:
        print(f"✅ SIN DESFASES ({ok} comprobaciones): manual, espejo, copias y sistema coherentes")
sys.exit(1 if fallos else 0)
