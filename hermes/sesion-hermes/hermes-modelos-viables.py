#!/usr/bin/env python3
"""hermes-modelos-viables.py — ¿qué modelos sirven de verdad como agente en Hermes?

Aplica la misma metodología que el `check-nvidia-whitelist.sh` de OpenCode:
un modelo sólo es utilizable si, además de responder,

  1. contesta con HTTP 200 real a una petición de chat,
  2. genera a una velocidad aceptable (por defecto ≥ 10 tok/s), y
  3. emite **tool calling** real (sin herramientas no puede ser agente).

Prueba los modelos locales de LM Studio (sondeo en vivo, igual que hace Hermes) y los
del whitelist de NVIDIA.

Uso:
    hermes-modelos-viables                 # locales + NVIDIA
    hermes-modelos-viables --local
    hermes-modelos-viables --nvidia
    hermes-modelos-viables --modelo qwen3.8-9b
    hermes-modelos-viables --min-tok-s 15 --tokens 300
    hermes-modelos-viables --json

Salida: tabla por pantalla + línea en ~/Config/hermes/logs/modelos-viables.log
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

MIN_TOK_S_DEFAULT = 10.0
TOKENS_DEFAULT = 200
TIMEOUT_DEFAULT = 120.0
LOG_DEFAULT = os.path.expanduser("~/Config/hermes/logs/modelos-viables.log")
ENV_HERMES = os.path.expanduser("~/.hermes/.env")
OPENCODE_JSON = os.path.expanduser("~/.config/opencode/opencode.json")

LOCAL_BASE = "http://127.0.0.1:1234/v1"
NVIDIA_BASE = "https://integrate.api.nvidia.com/v1"
NVIDIA_WHITELIST_FALLBACK = [
    "meta/muse-glimmer-30b",
    "meta/llama-3.2-11b-vision-instruct",
    "openai/gpt-oss-20b",
    "nvidia/nemotron-3-ultra-550b-a55b",
    "nvidia/nemotron-3-super-120b-a12b",
    "nvidia/nemotron-3.5-lightning-30b-a3b",
    "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning",
]
TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_current_time",
            "description": "Devuelve la hora actual del sistema.",
            "parameters": {"type": "object", "properties": {}, "required": []},
        },
    }
]


# ---------------------------------------------------------------- utilidades
def leer_clave(nombre: str) -> str:
    """Clave desde ~/.hermes/.env (o el entorno)."""
    valor = os.environ.get(nombre, "")
    if valor:
        return valor
    if os.path.exists(ENV_HERMES):
        for linea in open(ENV_HERMES, encoding="utf-8", errors="replace"):
            linea = linea.strip()
            if linea.startswith("export "):
                linea = linea[7:]
            if linea.startswith(f"{nombre}="):
                return linea.split("=", 1)[1].strip().strip('"').strip("'")
    return ""


def peticion(url: str, clave: str, cuerpo: dict | None, timeout: float, metodo: str = "POST",
             intentos: int = 3):
    """Petición HTTP con reintento ante saturación (429/5xx) o timeout.

    NVIDIA devuelve 503 y timeouts cuando está sobrecargado: sin reintento, un modelo bueno
    aparece como inviable. El `check-nvidia-whitelist.sh` de OpenCode hace lo mismo.
    """
    datos = json.dumps(cuerpo).encode() if cuerpo is not None else None
    cabeceras = {"Content-Type": "application/json"}
    if clave:
        cabeceras["Authorization"] = f"Bearer {clave}"
    ultimo_error: Exception | None = None
    for intento in range(intentos):
        req = urllib.request.Request(url, data=datos, headers=cabeceras, method=metodo)
        inicio = time.monotonic()
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                texto = resp.read().decode("utf-8", "replace")
            return resp.status, json.loads(texto) if texto.strip() else {}, time.monotonic() - inicio
        except urllib.error.HTTPError as exc:
            ultimo_error = exc
            if exc.code not in (429, 500, 502, 503, 504):
                raise
        except (TimeoutError, OSError) as exc:
            ultimo_error = exc
        if intento < intentos - 1:
            time.sleep(4 * (intento + 1))
    raise ultimo_error  # type: ignore[misc]


def modelos_locales(clave: str, timeout: float) -> list[str]:
    """Sondeo en vivo, como hace Hermes: /v1/models de LM Studio."""
    try:
        _, datos, _ = peticion(f"{LOCAL_BASE}/models", clave, None, timeout, metodo="GET")
    except Exception as exc:  # noqa: BLE001
        print(f"  ✗ LM Studio no responde en {LOCAL_BASE} ({exc}).")
        print("    Arranca el servidor:  lms server start   (o abre la app lm-studio)")
        return []
    ids = [m.get("id", "") for m in datos.get("data", []) if isinstance(m, dict)]
    return [i for i in ids if i and "embed" not in i.lower()]


def modelos_nvidia() -> list[str]:
    if os.path.exists(OPENCODE_JSON):
        try:
            cfg = json.load(open(OPENCODE_JSON, encoding="utf-8"))
            provs = cfg.get("provider") or cfg.get("providers") or {}
            nv = provs.get("nvidia", {}) or {}
            wl = nv.get("whitelist") or nv.get("models") or []
            if isinstance(wl, dict):
                wl = list(wl.keys())
            if wl:
                return list(wl)
        except Exception:  # noqa: BLE001
            pass
    return list(NVIDIA_WHITELIST_FALLBACK)


def _tokens(respuesta: dict, texto: str) -> int:
    uso = respuesta.get("usage") or {}
    n = uso.get("completion_tokens") or uso.get("output_tokens")
    if isinstance(n, int) and n > 0:
        return n
    return max(1, len(texto) // 4)


# ---------------------------------------------------------------- prueba
def probar(etiqueta: str, base: str, clave: str, modelo: str, tokens: int,
           min_tok_s: float, timeout: float) -> dict:
    res = {"proveedor": etiqueta, "modelo": modelo, "http": None, "tok_s": None,
           "tools": False, "error": "", "veredicto": ""}
    url = f"{base}/chat/completions"
    try:
        # 1) ¿responde?
        codigo, _, _ = peticion(
            url, clave,
            {"model": modelo, "messages": [{"role": "user", "content": "Responde solo: ok"}],
             "max_tokens": 8},
            timeout,
        )
        res["http"] = codigo
        # 2) velocidad real
        codigo, datos, segundos = peticion(
            url, clave,
            {"model": modelo, "max_tokens": tokens,
             "messages": [{"role": "user",
                           "content": "Escribe los números del 1 al 100 separados por comas, sin nada más."}]},
            timeout,
        )
        if codigo != 200:
            res["error"] = f"HTTP {codigo}"
            res["veredicto"] = "✗ inaccesible"
            return res
        texto = (datos.get("choices") or [{}])[0].get("message", {}).get("content") or ""
        n = _tokens(datos, texto)
        res["tok_s"] = round(n / max(segundos, 0.01), 1)
        # 3) tool calling real
        codigo, datos, _ = peticion(
            url, clave,
            {"model": modelo, "tool_choice": "auto", "tools": TOOLS, "max_tokens": 120,
             "messages": [{"role": "user",
                           "content": "¿Qué hora es ahora mismo? Usa la herramienta get_current_time."}]},
            timeout,
        )
        if codigo == 200:
            msg = (datos.get("choices") or [{}])[0].get("message", {}) or {}
            res["tools"] = bool(msg.get("tool_calls"))
        res["veredicto"] = (
            "✅ viable" if res["tools"] and res["tok_s"] >= min_tok_s
            else "⚠️ lento" if res["tools"]
            else "❌ sin tool calling"
        )
    except urllib.error.HTTPError as exc:
        res["http"] = exc.code
        detalle = "fin de vida / retirado" if exc.code in (404, 410) else exc.reason
        res["error"] = f"HTTP {exc.code} ({detalle})"
        res["veredicto"] = "✗ inaccesible"
    except Exception as exc:  # noqa: BLE001
        res["error"] = f"{type(exc).__name__}: {exc}".strip()
        res["veredicto"] = "✗ error"
    return res


# ---------------------------------------------------------------- presentación
def mostrar(resultados: list[dict], min_tok_s: float) -> None:
    ancho = max((len(r["modelo"]) for r in resultados), default=10)
    print()
    print(f"{'MODELO'.ljust(ancho)}  {'PROV':<8}  {'TOK/S':>7}  TOOLS  VEREDICTO")
    print("-" * (ancho + 40))
    for r in resultados:
        velocidad = f"{r['tok_s']:.1f}" if r["tok_s"] is not None else "-"
        tools = "sí" if r["tools"] else "no"
        extra = f"  ({r['error']})" if r["error"] else ""
        print(f"{r['modelo'].ljust(ancho)}  {r['proveedor']:<8}  {velocidad:>7}  {tools:<5}  {r['veredicto']}{extra}")
    viables = [r for r in resultados if r["veredicto"].startswith("✅")]
    print()
    print(f"Veredicto: {len(viables)}/{len(resultados)} modelos realmente viables como agente "
          f"(≥ {min_tok_s:g} tok/s + tool calling).")


def anotar_log(resultados: list[dict], min_tok_s: float) -> None:
    os.makedirs(os.path.dirname(LOG_DEFAULT), exist_ok=True)
    with open(LOG_DEFAULT, "a", encoding="utf-8") as fh:
        fh.write(f"\n[{time.strftime('%d/%m/%Y %H:%M:%S')}] umbral {min_tok_s:g} tok/s\n")
        for r in resultados:
            fh.write(f"  {r['veredicto']} {r['modelo']} ({r['proveedor']}) "
                     f"tok/s={r['tok_s']} tools={r['tools']} {r['error']}\n")


# ---------------------------------------------------------------- main
def main() -> int:
    ap = argparse.ArgumentParser(description="Comprueba qué modelos son viables como agente en Hermes.")
    ap.add_argument("--local", action="store_true", help="solo los modelos locales de LM Studio")
    ap.add_argument("--nvidia", action="store_true", help="solo los modelos del whitelist de NVIDIA")
    ap.add_argument("--modelo", action="append", default=[], help="modelo concreto (repetible)")
    ap.add_argument("--min-tok-s", type=float, default=MIN_TOK_S_DEFAULT,
                    help=f"umbral de velocidad (por defecto {MIN_TOK_S_DEFAULT:g})")
    ap.add_argument("--tokens", type=int, default=TOKENS_DEFAULT, help="tokens a generar en la prueba de velocidad")
    ap.add_argument("--timeout", type=float, default=TIMEOUT_DEFAULT, help="timeout por petición en segundos")
    ap.add_argument("--json", action="store_true", help="salida en JSON (además del log)")
    ap.add_argument("--sin-log", action="store_true", help="no escribir en el log")
    args = ap.parse_args()

    hacer_local = args.local or not args.nvidia
    hacer_nvidia = args.nvidia or not args.local

    clave_local = leer_clave("LM_API_KEY") or "lm-studio"
    clave_nvidia = leer_clave("NVIDIA_API_KEY")

    resultados: list[dict] = []

    if hacer_local:
        print("▶ LM Studio (local, http://127.0.0.1:1234/v1)")
        modelos = modelos_locales(clave_local, args.timeout)
        modelos = [m for m in modelos if not args.modelo or m in args.modelo]
        if not modelos and not args.modelo:
            print("  (sin modelos locales que probar)")
        for m in modelos:
            print(f"  · probando {m} …", flush=True)
            resultados.append(probar("lmstudio", LOCAL_BASE, clave_local, m,
                                     args.tokens, args.min_tok_s, args.timeout))

    if hacer_nvidia:
        if not clave_nvidia:
            print("▶ NVIDIA: sin NVIDIA_API_KEY en ~/.hermes/.env — se omite.")
        else:
            print("▶ NVIDIA (whitelist)")
            modelos = [m for m in modelos_nvidia() if not args.modelo or m in args.modelo]
            for m in modelos:
                print(f"  · probando {m} …", flush=True)
                resultados.append(probar("nvidia", NVIDIA_BASE, clave_nvidia, m,
                                         args.tokens, args.min_tok_s, args.timeout))

    if not resultados:
        print("No hay nada que probar (¿servidor de LM Studio apagado y sin NVIDIA?).")
        return 2

    mostrar(resultados, args.min_tok_s)
    if not args.sin_log:
        anotar_log(resultados, args.min_tok_s)
    if args.json:
        print(json.dumps(resultados, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
