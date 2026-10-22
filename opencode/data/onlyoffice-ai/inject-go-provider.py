#!/usr/bin/env python3
"""
inject-go-provider.py — Añade el proveedor "OpenCode Go" al plugin IA de ONLYOFFICE

Escribe en el LevelDB del localStorage del plugin IA un proveedor OpenAI-compatible
que apunta al proxy local opencode-go-proxy.py (puerto 4002), el cual añade la
cabecera x-opencode-session que OpenCode Go exige.

Requisitos:
    1. El proxy debe estar corriendo:  python3 ~/.config/opencode/opencode-go-proxy.py
    2. ONLYOFFICE Desktop Editors CERRADO (si está abierto, al salir sobrescribe
       el LevelDB con su copia en memoria y se pierde el cambio)

Uso:
    python3 inject-go-provider.py            # inyecta / actualiza
    python3 inject-go-provider.py --check    # solo verifica el estado actual
    python3 inject-go-provider.py --remove   # quita el proveedor OpenCode Go
"""
import json
import os
import struct
import sys

LVL = os.path.expanduser(
    "~/.local/share/onlyoffice/desktopeditors/data/cache/Local Storage/leveldb")
LOG = os.path.join(LVL, "000003.log")
KEY = b"_onlyoffice://plugin\x00\x01onlyoffice_ai_plugin_storage_key"

PROVIDER_NAME = "OpenCode Go"
BASE_URL = "http://localhost:4002/v1"
API_KEY = "opencode-go"          # el proxy no la valida; la real vive en .env
CAPABILITIES = 511               # todas las tareas del plugin

# Modelos accesibles por el endpoint OpenAI-compatible de Go (/chat/completions).
# Los modelos de Go servidos por /anthropic o /responses NO valen para el plugin.
MODELS = [
    ("deepseek-v4.1-flash", "DeepSeek V4.1 Flash (razona, barato)"),
    ("glm-5.3-flash", "GLM-5.3 Flash (rápido, tareas de texto)"),
    ("kimi-k2.7-code", "Kimi K2.7 Code (código)"),
    ("mimo-v2.6-flash", "MiMo V2.6 Flash (rápido)"),
    ("minimax-m3.1-flash-free", "MiniMax M3.1 Flash Free (gratis)"),
]


# ── CRC32C (polinomio 0x82F63B78) ─────────────────────────────
def _crc32c_table():
    poly = 0x82F63B78
    table = []
    for i in range(256):
        c = i
        for _ in range(8):
            c = (c >> 1) ^ poly if c & 1 else c >> 1
        table.append(c & 0xFFFFFFFF)
    return table


_TABLE = _crc32c_table()


def crc32c(data, crc=0):
    crc ^= 0xFFFFFFFF
    for b in data:
        crc = _TABLE[(crc ^ b) & 0xFF] ^ (crc >> 8)
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF


def mask(crc):
    return (((crc >> 15) | (crc << 17)) + 0xA282EAD8) & 0xFFFFFFFF


# ── LevelDB: lectura ──────────────────────────────────────────
def _read_varint(buf, off):
    result, shift = 0, 0
    while True:
        b = buf[off]
        off += 1
        result |= (b & 0x7F) << shift
        if not (b & 0x80):
            break
        shift += 7
    return result, off


def parse_log(path):
    data = open(path, "rb").read()
    off, entries = 0, []
    while off + 7 <= len(data):
        checksum, length, rtype = struct.unpack_from("<IHB", data, off)
        off += 7
        if off + length > len(data):
            break
        payload = data[off:off + length]
        off += length
        if rtype != 1 or len(payload) < 12:
            continue
        real = mask(crc32c(b"\x01" + payload))
        seq, count = struct.unpack_from("<QI", payload, 0)
        p = 12
        for _ in range(count):
            if p >= len(payload):
                break
            et = payload[p]
            p += 1
            klen, p = _read_varint(payload, p)
            key = payload[p:p + klen]
            p += klen
            if et == 1:
                vlen, p = _read_varint(payload, p)
                val = payload[p:p + vlen]
                p += vlen
            else:
                val = b"<DEL>"
            entries.append({"seq": seq, "type": "put" if et == 1 else "del",
                            "key": key, "val": val, "cksum_ok": real == checksum})
    return entries


def _enc_varint(n):
    out = b""
    while True:
        b = n & 0x7F
        n >>= 7
        out += bytes([b | 0x80]) if n else bytes([b])
        if not n:
            break
    return out


def make_record(seq, key, value):
    payload = struct.pack("<QI", seq, 1) + b"\x01"
    payload += _enc_varint(len(key)) + key
    payload += _enc_varint(len(value)) + value
    return struct.pack("<IHB", mask(crc32c(b"\x01" + payload)), len(payload), 1) + payload


def get_current():
    best = None
    if os.path.exists(LOG):
        for e in parse_log(LOG):
            if e["key"] == KEY and e["type"] == "put":
                if best is None or e["seq"] > best["seq"]:
                    best = e
    return best


def onlyoffice_running():
    try:
        for pid in os.listdir("/proc"):
            if not pid.isdigit():
                continue
            try:
                with open(f"/proc/{pid}/cmdline", "rb") as fh:
                    cmd = fh.read().replace(b"\x00", b" ").decode("utf-8", "ignore")
            except OSError:
                continue
            if "onlyoffice" in cmd.lower() and "DesktopEditors" in cmd:
                return pid
    except OSError:
        pass
    return None


def save(cfg):
    new_value = b"\x01" + json.dumps(cfg, ensure_ascii=False).encode("utf-8")
    max_seq = max((e["seq"] for e in parse_log(LOG)), default=0) if os.path.exists(LOG) else 0
    seq = max_seq + 10
    with open(LOG, "ab") as fh:
        fh.write(make_record(seq, KEY, new_value))
    for e in parse_log(LOG):
        if e["key"] == KEY and e["seq"] == seq and e["type"] == "put":
            ok = e["cksum_ok"] and e["val"] == new_value
            return ok, seq
    return False, seq


def main():
    check_only = "--check" in sys.argv
    remove = "--remove" in sys.argv

    if not os.path.isdir(LVL):
        os.makedirs(LVL, exist_ok=True)
        print("ℹ️  Creado el directorio del perfil de OnlyOffice (perfil nuevo).")

    cur = get_current()
    if cur:
        cfg = json.loads(cur["val"][1:])
        print(f"ℹ️  Configuración actual: version={cfg.get('version')}, "
              f"proveedores={len(cfg.get('providers', {}))}")
    else:
        print("⚠️  No hay configuración previa del plugin IA; se creará desde cero.")
        cfg = {"version": 4, "providers": {}, "models": [], "customProviders": {}}

    prov = cfg.get("providers", {}).get(PROVIDER_NAME)

    if check_only:
        if prov:
            print(f"✅ Proveedor '{PROVIDER_NAME}' presente -> {prov['url']}")
            print(f"   Modelos del proveedor: {[m['id'] for m in prov.get('models', [])]}")
            activos = [m for m in cfg.get("models", []) if m.get("provider") == PROVIDER_NAME]
            print(f"   Modelos asignados: {[m['id'] for m in activos]}")
            return 0
        print(f"❌ Proveedor '{PROVIDER_NAME}' NO presente")
        return 1

    if remove:
        if not prov:
            print(f"ℹ️  '{PROVIDER_NAME}' no estaba configurado.")
            return 0
        del cfg["providers"][PROVIDER_NAME]
        cfg["models"] = [m for m in cfg.get("models", [])
                         if m.get("provider") != PROVIDER_NAME]
        ok, seq = save(cfg)
        print(f"{'✅' if ok else '❌'} Proveedor '{PROVIDER_NAME}' eliminado (seq={seq})")
        return 0 if ok else 1

    pid = onlyoffice_running()
    if pid:
        print(f"🔴 ONLYOFFICE está abierto (PID {pid}).")
        print("   Ciérralo por completo y vuelve a ejecutar este script: si sigue abierto,")
        print("   al salir reescribirá el LevelDB y se perderá el cambio.")
        return 2

    ahora = 1792677000
    cfg["providers"][PROVIDER_NAME] = {
        "name": PROVIDER_NAME,
        "url": BASE_URL,
        "key": API_KEY,
        "models": [
            {"id": mid, "object": "model", "created": ahora, "owned_by": "opencode",
             "name": mid, "endpoints": [1], "options": {}}
            for mid, _desc in MODELS
        ],
    }

    cfg["models"] = [m for m in cfg.get("models", [])
                     if m.get("provider") != PROVIDER_NAME]
    for mid, desc in MODELS:
        cfg["models"].append({
            "capabilities": CAPABILITIES,
            "provider": PROVIDER_NAME,
            "name": f"{PROVIDER_NAME} [{desc}]",
            "id": mid,
        })

    ok, seq = save(cfg)
    print(f"{'✅' if ok else '❌'} Record escrito en el LevelDB (seq={seq})")
    print(f"   '{PROVIDER_NAME}' -> {BASE_URL}")
    print(f"   Modelos registrados: {[m for m, _ in MODELS]}")
    print("   Abre OnlyOffice → pestaña IA → Ajustes → Editar modelos de IA")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
