#!/usr/bin/env python3
import json, os, sys, datetime, subprocess, time
from pathlib import Path

CONFIG_DIR = Path.home() / ".config" / "mimocode"
AUTH_FILE = Path.home() / ".local" / "share" / "mimocode" / "auth.json"
LOG_FILE = CONFIG_DIR / "data" / "nvidia-whitelist.log"
STATE_FILE = CONFIG_DIR / "data" / "nvidia-whitelist-state.json"
API_URL = "https://integrate.api.nvidia.com/v1"
JSONS = [
    CONFIG_DIR / "mimocode.jsonc",
    CONFIG_DIR / "profiles" / "local" / "mimocode.jsonc",
    CONFIG_DIR / "profiles" / "cloud" / "mimocode.jsonc",
]
MIN_TOKENS_PER_SEC = 10
GENERATION_TOKENS = 200
MAX_NEW_MODELS_PER_RUN = 10

def log(msg):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    (CONFIG_DIR / "data").mkdir(parents=True, exist_ok=True)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"[{datetime.datetime.now().strftime('%d/%m/%Y %H:%M:%S')}] {msg}\n")

def get_api_key():
    with open(AUTH_FILE) as f:
        d = json.load(f)
    return d.get("nvidia", {}).get("key", "")

def curl_subprocess(args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=120)
    return result.stdout, result.stderr

def curl_post(model, payload):
    cmd = ["curl","-s","--max-time","60","-w","\n%{http_code}","-X","POST",f"{API_URL}/chat/completions","-H",f"Authorization: Bearer {api_key}","-H","Content-Type: application/json","-d",payload]
    out,_ = curl_subprocess(cmd)
    if not out:
        return "000",""
    parts = out.rsplit("\n",1)
    code = parts[-1].strip()
    body = "\n".join(parts[:-1])
    return code, body

def curl_get_models():
    cmd = ["curl","-s","--max-time","30",f"{API_URL}/models","-H",f"Authorization: Bearer {api_key}"]
    out,_ = curl_subprocess(cmd)
    return out

api_key = get_api_key()
if not api_key:
    log("No API key")
    sys.exit(1)

# load state
if STATE_FILE.exists():
    with open(STATE_FILE) as f:
        state = json.load(f)
else:
    state = {"modelos_vistos":[],"descartados":{},"retirados":{}}

def load_whitelist(p):
    with open(p, encoding="utf-8") as f:
        try:
            d = json.load(f)
        except json.JSONDecodeError:
            import re
            txt = re.sub(r'//.*','', f.read())
            d = json.loads(txt)
    return d.get("provider",{}).get("nvidia",{}).get("whitelist",[])

wl = load_whitelist(JSONS[0])
log(f"Whitelist actual: {wl}")

retired = []
new_wl = []
for m in wl:
    payload = json.dumps({"model": m, "messages":[{"role":"user","content":"hola"}], "max_tokens":5})
    code, body = curl_post(m, payload)
    if code == "200":
        new_wl.append(m)
        log(f"OK {m}")
    elif code == "410":
        retired.append(m)
        log(f"RETIRADO {m} 410")
    else:
        new_wl.append(m)
        log(f"WARN {m} code {code}")

candidates = []
if True:
    catalog_raw = curl_get_models()
    try:
        catalog = json.loads(catalog_raw)
        models_catalog = [m.get("id") for m in catalog.get("data",[]) if m.get("id")]
    except:
        models_catalog = []
    seen = set(state.get("modelos_vistos",[]))
    current_set = set(wl)
    new_models = [m for m in models_catalog if m not in seen and m not in current_set]
    log(f"Modelos nuevos detectados en catálogo: {len(new_models)}")
    count = 0
    for m in new_models:
        if count >= MAX_NEW_MODELS_PER_RUN:
            log("Límite de modelos nuevos alcanzado")
            break
        count +=1
        # velocidad
        payload = json.dumps({"model": m, "messages":[{"role":"user","content":"Escribe un texto de unas 180 palabras sobre la historia de la informática."}], "max_tokens":GENERATION_TOKENS})
        code, body = curl_post(m, payload)
        if code != "200":
            log(f"Descartado {m} HTTP {code}")
            continue
        try:
            d = json.loads(body)
            ct = d.get("usage",{}).get("completion_tokens",0)
        except:
            ct = 0
        # tok/s estimado aprox; usamos tiempo real? simplificado
        # tool calling test
        tool_payload = json.dumps({"model": m, "messages":[{"role":"user","content":"¿Qué hora es? Llama a get_current_time."}], "max_tokens":200, "tools":[{"type":"function","function":{"name":"get_current_time","description":"Devuelve hora","parameters":{"type":"object","properties":{}}}}], "tool_choice":"auto"})
        tcode, tbody = curl_post(m, tool_payload)
        if tcode != "200":
            log(f"Descartado {m} tool test HTTP {tcode}")
            continue
        try:
            td = json.loads(tbody)
            has_tool = bool(td.get("choices",[{}])[0].get("message",{}).get("tool_calls"))
        except:
            has_tool = False
        if has_tool:
            candidates.append(m)
            log(f"CANDIDATO {m} pasa tool calling")
        else:
            log(f"Descartado {m} sin tool calling")

if retired:
    for p in JSONS:
        try:
            with open(p, encoding="utf-8") as f:
                d = json.load(f)
        except Exception as e:
            log(f"Error leyendo {p}: {e}")
            continue
        prov = d.setdefault("provider",{})
        nv = prov.setdefault("nvidia",{})
        wl_cur = nv.get("whitelist",[])
        models_cur = nv.get("models",{})
        new_wl_merged = [x for x in wl_cur if x not in retired]
        nv["whitelist"] = new_wl_merged
        nv["models"] = {k:v for k,v in models_cur.items() if k in new_wl_merged}
        # backup
        try:
            p.with_name(p.name+".bak").write_text(json.dumps(d))
        except:
            pass
        with open(p,"w",encoding="utf-8") as f:
            json.dump(d,f,indent=2,ensure_ascii=False)
            f.write("\n")
        log(f"Actualizado {p}")
    subprocess.run(["bash", str(CONFIG_DIR/"sync-mimocode.sh"), "--quiet"])
    log("Sincronización realizada")

if candidates:
    log(f"Candidatos nuevos: {candidates}")
    # notificación
    try:
        subprocess.run(["notify-send","-u","normal","MiMoCode NVIDIA","Candidatos nuevos: "+", ".join(candidates)])
    except:
        pass

# update state
state["ultima_ejecucion"] = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
state["modelos_vistos"] = models_catalog if 'models_catalog' in locals() else state.get("modelos_vistos",[])
for m in retired:
    state.setdefault("retirados",{})[m] = {"fecha": datetime.date.today().isoformat(),"http":410}
with open(STATE_FILE,"w",encoding="utf-8") as f:
    json.dump(state,f,indent=2,ensure_ascii=False)
    f.write("\n")

log("Fin verificación")
