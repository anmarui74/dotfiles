#!/usr/bin/env python3
"""
inject-provider.py — Restaura el proveedor "OpenCode Local" (opencode → OnlyOffice AI)

Inyecta en el LevelDB del localStorage del plugin IA de OnlyOffice Desktop Editors
el proveedor compatible con la API de OpenAI que apunta a opencode local (puerto 4001).

Uso:
    python3 inject-provider.py            # inyecta (requiere OnlyOffice cerrado)
    python3 inject-provider.py --check    # solo verifica el estado actual

La configuración original extraída está en: onlyoffice-ai-config.json
"""
import struct, os, json, sys

LVL = os.path.expanduser('~/.local/share/onlyoffice/desktopeditors/data/cache/Local Storage/leveldb')
LOG = os.path.join(LVL, '000003.log')
KEY = b'_onlyoffice://plugin\x00\x01onlyoffice_ai_plugin_storage_key'
PROVIDER_NAME = "OpenCode Local"
MODEL_ID = "models-qwen3.5-9b"
BASE_URL = "http://localhost:4001/v1"
API_KEY = "lm-studio"

# ── CRC32C (polinomio 0x82F63B78) ─────────────────────────────
def _crc32c_table():
    poly = 0x82F63B78
    return [((lambda c: c if c <= 0xFFFFFFFF else c & 0xFFFFFFFF)(
                (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(
                    (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(
                        (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(
                            (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(
                                (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(
                                    (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(
                                        (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(i)
                                    )))))) )) for i in range(256)]

_TABLE = _crc32c_table()

def crc32c(data, crc=0):
    crc ^= 0xffffffff
    for b in data:
        crc = _TABLE[(crc ^ b) & 0xff] ^ (crc >> 8)
    return (crc ^ 0xffffffff) & 0xffffffff

def mask(crc):
    return (((crc >> 15) | (crc << 17)) + 0xa282ead8) & 0xffffffff

# ── Lectura de records del log ─────────────────────────────────
def _read_varint(buf, off):
    result, shift = 0, 0
    while True:
        b = buf[off]; off += 1
        result |= (b & 0x7f) << shift
        if not (b & 0x80): break
        shift += 7
    return result, off

def parse_log(path):
    data = open(path, 'rb').read()
    off, entries = 0, []
    while off + 7 <= len(data):
        checksum, length, rtype = struct.unpack_from('<IHB', data, off)
        off += 7
        if off + length > len(data): break
        payload = data[off:off+length]; off += length
        if rtype != 1 or len(payload) < 12: continue
        real = mask(crc32c(b'\x01' + payload))
        seq, count = struct.unpack_from('<QI', payload, 0)
        p = 12
        for _ in range(count):
            if p >= len(payload): break
            et = payload[p]; p += 1
            klen, p = _read_varint(payload, p)
            key = payload[p:p+klen]; p += klen
            if et == 1:
                vlen, p = _read_varint(payload, p)
                val = payload[p:p+vlen]; p += vlen
            else:
                val = b'<DEL>'
            entries.append({'seq': seq, 'type': 'put' if et == 1 else 'del',
                            'key': key, 'val': val, 'cksum_ok': (real == checksum)})
    return entries

# ── Escritura ───────────────────────────────────────────────────
def _enc_varint(n):
    out = b''
    while True:
        b = n & 0x7f; n >>= 7
        out += bytes([b | 0x80]) if n else bytes([b])
        if not n: break
    return out

def make_record(seq, key, value):
    payload = struct.pack('<QI', seq, 1) + b'\x01'
    payload += _enc_varint(len(key)) + key
    payload += _enc_varint(len(value)) + value
    return struct.pack('<IHB', mask(crc32c(b'\x01' + payload)), len(payload), 1) + payload

def get_current():
    best = None
    if os.path.exists(LOG):
        for e in parse_log(LOG):
            if e['key'] == KEY and e['type'] == 'put':
                if best is None or e['seq'] > best['seq']:
                    best = e
    return best

def ensure_dirs():
    """Crea los directorios del perfil de OnlyOffice si no existen (instalación limpia)."""
    os.makedirs(LVL, exist_ok=True)

def main():
    check_only = '--check' in sys.argv
    ensure_dirs()
    cur = get_current()

    if cur:
        cfg = json.loads(cur['val'][1:])
        prov = cfg['providers'].get(PROVIDER_NAME)
        print(f"ℹ️  Configuración actual: version={cfg.get('version')}, providers={len(cfg['providers'])}")
        if prov:
            print(f"✅ Proveedor '{PROVIDER_NAME}' YA presente -> {prov['url']}")
            models = [m['id'] for m in cfg.get('models', [])]
            print(f"   Modelos registrados: {models}")
            return 0
        if check_only:
            print(f"❌ Proveedor '{PROVIDER_NAME}' NO presente")
            return 1
        print(f"➕ Añadiendo proveedor '{PROVIDER_NAME}' a la configuración existente...")
    else:
        if check_only:
            print("❌ No hay configuración del plugin AI")
            return 1
        print("➕ No había configuración previa; creándola desde cero...")
        cfg = {"version": 4, "providers": {}, "models": [], "customProviders": {}}

    cfg['providers'][PROVIDER_NAME] = {
        "name": PROVIDER_NAME, "url": BASE_URL, "key": API_KEY,
        "models": [{"id": MODEL_ID, "object": "model", "created": 1780000000,
                    "owned_by": "lmstudio", "name": MODEL_ID,
                    "endpoints": [1], "options": {}}]
    }
    exists = any(m.get('id') == MODEL_ID and m.get('provider') == PROVIDER_NAME for m in cfg.get('models', []))
    if not exists:
        cfg.setdefault('models', []).append({
            "capabilities": 511, "provider": PROVIDER_NAME,
            "name": f"{PROVIDER_NAME} [{MODEL_ID}]", "id": MODEL_ID
        })

    new_value = b'\x01' + json.dumps(cfg, ensure_ascii=False).encode('utf-8')
    max_seq = max((e['seq'] for e in parse_log(LOG)), default=0) if os.path.exists(LOG) else 0
    seq = max_seq + 10

    with open(LOG, 'ab') as f:
        f.write(make_record(seq, KEY, new_value))
    print(f"✅ Record añadido al LevelDB (seq={seq})")

    # Verificar
    for e in parse_log(LOG):
        if e['key'] == KEY and e['seq'] == seq and e['type'] == 'put':
            ok = e['cksum_ok'] and e['val'] == new_value
            cfg2 = json.loads(e['val'][1:])
            print(f"✅ Verificado: cksum={'OK' if e['cksum_ok'] else 'FAIL'}, "
                  f"'{PROVIDER_NAME}' -> {cfg2['providers'][PROVIDER_NAME]['url']}")
            print(f"   Modelos: {[m['id'] for m in cfg2['models']]}")
            return 0 if ok else 1
    print("❌ Verificación fallida")
    return 1

if __name__ == '__main__':
    sys.exit(main())
