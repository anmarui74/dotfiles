#!/usr/bin/env python3
"""Renueva el token de Google SIN tocar nada, mientras la app OAuth siga en modo «Prueba».

El tope de 7 días del modo Prueba se reinicia con cada consentimiento. Si el navegador conserva la
sesión de Google, el consentimiento puede hacerse sin interacción usando `prompt=none`: Google
devuelve el `code` directamente y canjeándolo sale un refresh token con 7 días nuevos.

Cómo funciona:
  1. Lanza Chrome con un perfil DEDICADO (`<perfil Hermes>/google-perfil`) en modo oculto y con
     puerto de depuración.
  2. Abre la URL de autorización con `prompt=none`.
  3. Lee la URL de la pestaña desde el propio CDP (sin websocket) hasta que trae `code=`.
  4. Canjea el código (PKCE) y guarda el token en `google_token.json`.
  5. Cierra Chrome.

Antes hay que iniciar sesión UNA vez en ese perfil:
    python oauth-renovar.py --login        (abre Chrome visible; Antonio inicia sesión y lo cierra)

Uso habitual:
    python oauth-renovar.py --comprobar    # ¿cuántos días le quedan al token actual?
    python oauth-renovar.py                # renovar ahora (silencioso; rc=0 si lo consiguió)
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import secrets
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request

AUTH = "https://accounts.google.com/o/oauth2/auth"
TOKEN = "https://oauth2.googleapis.com/token"
REDIRECT = "http://localhost:1"
PUERTO = 9226


def perfil_hermes() -> str:
    casa = os.environ.get("HERMES_HOME")
    if not casa:
        if os.name == "nt":
            casa = os.path.join(os.environ.get("LOCALAPPDATA") or os.path.expanduser("~"), "hermes")
        else:
            casa = os.path.expanduser("~/.hermes")
    return casa


def ruta_token() -> str:
    return os.path.join(perfil_hermes(), "google_token.json")


def ruta_perfil_chrome() -> str:
    return os.path.join(perfil_hermes(), "google-perfil")


def chrome_exe() -> str:
    if os.name != "nt":
        for c in ("google-chrome-stable", "google-chrome", "chromium", "chromium-browser"):
            ruta = shutil.which(c)
            if ruta:
                return ruta
        raise SystemExit("no encuentro Chrome/Chromium en el PATH")
    for p in (
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        os.path.join(os.environ.get("LOCALAPPDATA", ""), "Google", "Chrome", "Application", "chrome.exe"),
    ):
        if os.path.exists(p):
            return p
    raise SystemExit("no encuentro chrome.exe")


def credenciales() -> dict:
    """client_id/client_secret/scopes: del token si existe; si no, del client_secret.json."""
    t = ruta_token()
    if os.path.exists(t):
        d = json.load(open(t, encoding="utf-8"))
        if d.get("client_id"):
            return {"client_id": d["client_id"], "client_secret": d.get("client_secret", ""),
                    "scopes": d.get("scopes") or []}
    for nombre in ("google_client_secret.json", "google_credentials.json"):
        p = os.path.join(perfil_hermes(), nombre)
        if os.path.exists(p):
            d = json.load(open(p, encoding="utf-8"))
            d = d.get("installed") or d.get("web") or d
            return {"client_id": d["client_id"], "client_secret": d.get("client_secret", ""), "scopes": []}
    raise SystemExit("no encuentro client_id: ni google_token.json ni google_client_secret.json")


def url_autorizacion(cred: dict, verifier: str, prompt: str) -> str:
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip("=")
    params = {
        "response_type": "code",
        "client_id": cred["client_id"],
        "redirect_uri": REDIRECT,
        "scope": " ".join(cred["scopes"]) or "https://www.googleapis.com/auth/gmail.readonly",
        "state": secrets.token_urlsafe(24),
        "code_challenge": challenge,
        "code_challenge_method": "S256",
        "access_type": "offline",
        "prompt": prompt,
    }
    return f"{AUTH}?{urllib.parse.urlencode(params)}"


def pedir_json(url: str, timeout: float = 3.0):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return json.load(r)
    except Exception:
        return None


def lanzar_chrome(visible: bool, url: str):
    args = [chrome_exe(),
            f"--user-data-dir={ruta_perfil_chrome()}",
            f"--remote-debugging-port={PUERTO}",
            "--no-first-run", "--no-default-browser-check", "--disable-sync",
            "--remote-allow-origins=http://127.0.0.1"]
    if not visible:
        args += ["--headless=new", "--window-size=1200,900", "--disable-gpu"]
    args.append(url)
    return subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def cerrar(proc: subprocess.Popen) -> None:
    try:
        if os.name == "nt":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
        else:
            proc.terminate()
    except Exception:
        pass


def esperar_codigo(limite: float = 75.0) -> str | None:
    """Lee la URL de las pestañas por CDP hasta ver `code=`. Sin websocket: /json/list basta."""
    fin = time.time() + limite
    while time.time() < fin:
        objetivos = pedir_json(f"http://127.0.0.1:{PUERTO}/json/list") or []
        for t in objetivos:
            u = t.get("url", "")
            if "code=" in u:
                q = urllib.parse.parse_qs(urllib.parse.urlparse(u).query)
                if q.get("code"):
                    return q["code"][0]
            if "error=" in u:
                q = urllib.parse.parse_qs(urllib.parse.urlparse(u).query)
                raise SystemExit(f"Google devolvió error: {q.get('error')}")
        time.sleep(1.5)
    return None


def canjear(code: str, cred: dict, verifier: str) -> dict:
    cuerpo = urllib.parse.urlencode({
        "code": code, "client_id": cred["client_id"], "client_secret": cred["client_secret"],
        "redirect_uri": REDIRECT, "grant_type": "authorization_code", "code_verifier": verifier,
    }).encode()
    req = urllib.request.Request(TOKEN, data=cuerpo)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def dias_restantes() -> str:
    d = json.load(open(ruta_token(), encoding="utf-8"))
    cuerpo = urllib.parse.urlencode({
        "grant_type": "refresh_token", "refresh_token": d["refresh_token"],
        "client_id": d["client_id"], "client_secret": d.get("client_secret", "")}).encode()
    with urllib.request.urlopen(urllib.request.Request(d.get("token_uri", TOKEN), data=cuerpo), timeout=30) as r:
        resp = json.load(r)
    if "refresh_token_expires_in" in resp:
        s = resp["refresh_token_expires_in"]
        return f"{s/86400:.1f} días (modo PRUEBA: caduca)"
    return "sin caducidad (app en producción)"


def main() -> int:
    ap = argparse.ArgumentParser(description="Renueva el token de Google sin interacción (prompt=none).")
    ap.add_argument("--login", action="store_true", help="Abre Chrome visible para iniciar sesión una vez")
    ap.add_argument("--comprobar", action="store_true", help="Solo informa de la vida del token actual")
    ap.add_argument("--visible", action="store_true", help="No ocultar Chrome al renovar (depuración)")
    a = ap.parse_args()

    if a.comprobar:
        print(dias_restantes())
        return 0

    cred = credenciales()
    verifier = secrets.token_urlsafe(64)
    os.makedirs(ruta_perfil_chrome(), exist_ok=True)

    prompt = "select_account" if a.login else "none"
    url = url_autorizacion(cred, verifier, prompt)
    proc = lanzar_chrome(a.login or a.visible, url)

    if a.login:
        print("Chrome abierto con el perfil dedicado. Inicia sesión con la cuenta correcta y CIÉRRALO.")
        print("Después ejecuta este script sin argumentos para probar la renovación automática.")
        return 0

    try:
        code = esperar_codigo()
        if not code:
            print("SIN_SESION: el perfil dedicado no tiene sesión de Google válida.\n"
                  "  Ejecuta: python oauth-renovar.py --login", file=sys.stderr)
            return 3
        resp = canjear(code, cred, verifier)
        if not resp.get("refresh_token"):
            print("ERROR: Google no devolvió refresh_token (¿consentimiento sin offline?)", file=sys.stderr)
            return 4
        datos = {
            "token": resp.get("access_token"), "refresh_token": resp["refresh_token"],
            "token_uri": TOKEN, "client_id": cred["client_id"], "client_secret": cred["client_secret"],
            "scopes": (resp.get("scope") or " ".join(cred["scopes"])).split(),
            "universe_domain": "googleapis.com", "account": "", "expiry": "",
        }
        json.dump(datos, open(ruta_token(), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        vida = "7 días (modo Prueba)" if "refresh_token_expires_in" in resp else "sin caducidad"
        print(f"OK: token renovado | refresh token: {vida}")
        return 0
    finally:
        cerrar(proc)


if __name__ == "__main__":
    sys.exit(main())
