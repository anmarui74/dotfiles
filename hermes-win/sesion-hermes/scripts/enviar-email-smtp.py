#!/usr/bin/env python3
"""Enviador de correo por SMTP de Gmail con contraseña de aplicación.

Alternativa a la API de Google cuando el token OAuth vive en modo «Prueba» (caduca a los 7 días).
No usa OAuth: no hay token que caduque ni pantalla de consentimiento de por medio.

La contraseña de aplicación se lee de, por orden:
  1. variable de entorno GMAIL_APP_PASSWORD
  2. %LOCALAPPDATA%\\hermes\\gmail-app-password.txt   (solo la contraseña, nada más)
  3. %LOCALAPPDATA%\\hermes\\gmail-app-password.json  ({"usuario": "...", "password": "..."})

Uso:
  python enviar-email-smtp.py --json correo.json          # envía
  python enviar-email-smtp.py --json correo.json --simular # no envía, solo valida y enseña
  python enviar-email-smtp.py --probar                     # se manda un correo a sí mismo

El JSON de entrada es el mismo que usa enviar-email.py:
  {"to": "...", "subject": "...", "body": "...", "html": "...", "cc": "...", "bcc": "..."}
"""
from __future__ import annotations

import argparse
import json
import os
import smtplib
import ssl
import sys
from email.headerregistry import Address
from email.message import EmailMessage
from email.utils import formatdate

SERVIDOR = "smtp.gmail.com"
PUERTO = 587
USUARIO_POR_DEFECTO = "anmarui74@gmail.com"
REMITENTE_NOMBRE = "Antonio Martínez Ruiz"


def ruta_perfil(nombre: str) -> str:
    """Perfil de Hermes: HERMES_HOME si está definido; si no, el de cada sistema."""
    casa = os.environ.get("HERMES_HOME")
    if not casa:
        if os.name == "nt":
            casa = os.path.join(os.environ.get("LOCALAPPDATA") or os.path.expanduser("~"), "hermes")
        else:
            casa = os.path.expanduser("~/.hermes")
    return os.path.join(casa, nombre)


def leer_credenciales() -> tuple[str, str]:
    """Devuelve (usuario, contraseña_de_aplicación).

    Google muestra la contraseña de aplicación en cuatro grupos de cuatro caracteres; se acepta
    pegada con espacios y se limpian: la contraseña real son los 16 caracteres seguidos.
    """
    def limpiar(v: str) -> str:
        return "".join((v or "").split())

    usuario = os.environ.get("GMAIL_USER", USUARIO_POR_DEFECTO)

    passwd = limpiar(os.environ.get("GMAIL_APP_PASSWORD", ""))
    if passwd:
        return usuario, passwd

    r_txt = ruta_perfil("gmail-app-password.txt")
    if os.path.exists(r_txt):
        with open(r_txt, encoding="utf-8") as f:
            passwd = limpiar(f.read())
        if passwd:
            return usuario, passwd

    r_json = ruta_perfil("gmail-app-password.json")
    if os.path.exists(r_json):
        with open(r_json, encoding="utf-8") as f:
            d = json.load(f)
        return d.get("usuario", usuario), limpiar(d.get("password", ""))

    raise SystemExit(
        "FALTA_CREDENCIAL: no encuentro la contraseña de aplicación.\n"
        f"  Guárdala en {r_txt} (solo la contraseña, 16 caracteres, sin comillas)\n"
        "  o define GMAIL_APP_PASSWORD. Se genera en https://myaccount.google.com/apppasswords"
    )


def construir(datos: dict) -> EmailMessage:
    msg = EmailMessage()
    msg["Subject"] = datos["subject"]
    remitente = datos.get("from") or f"{REMITENTE_NOMBRE} <{os.environ.get('GMAIL_USER', USUARIO_POR_DEFECTO)}>"
    msg["From"] = remitente
    msg["To"] = datos["to"]
    if datos.get("cc"):
        msg["Cc"] = datos["cc"]
    if datos.get("bcc"):
        msg["Bcc"] = datos["bcc"]
    msg["Date"] = formatdate(localtime=True)

    cuerpo = datos.get("body", "")
    if datos.get("html"):
        msg.set_content(cuerpo or "Este mensaje necesita un lector de HTML.")
        msg.add_alternative(datos["html"], subtype="html")
    else:
        msg.set_content(cuerpo)
    return msg


def enviar(msg: EmailMessage, usuario: str, passwd: str, simular: bool = False) -> dict:
    destinatarios = [a.addr_spec for a in msg["To"].addresses]
    for campo in ("Cc", "Bcc"):
        if msg[campo]:
            destinatarios += [a.addr_spec for a in msg[campo].addresses]

    if simular:
        return {"status": "simulado", "to": destinatarios, "subject": msg["Subject"]}

    contexto = ssl.create_default_context()
    with smtplib.SMTP(SERVIDOR, PUERTO, timeout=30) as s:
        s.ehlo()
        s.starttls(context=contexto)
        s.ehlo()
        s.login(usuario, passwd)
        s.send_message(msg, from_addr=usuario, to_addrs=destinatarios)
    return {"status": "sent", "to": destinatarios, "subject": msg["Subject"], "via": "smtp"}


def main() -> int:
    ap = argparse.ArgumentParser(description="Envía correo por SMTP de Gmail (contraseña de aplicación).")
    ap.add_argument("--json", help="Fichero JSON con to/subject/body (mismo formato que enviar-email.py)")
    ap.add_argument("--probar", action="store_true", help="Manda un correo de prueba a la propia cuenta")
    ap.add_argument("--simular", action="store_true", help="No envía: solo valida credenciales y composición")
    args = ap.parse_args()

    usuario, passwd = leer_credenciales()

    if args.probar:
        datos = {
            "to": usuario,
            "subject": "Prueba de envío por SMTP (Hermes)",
            "body": "Prueba técnica del enviador SMTP con contraseña de aplicación.\n\nHermes",
        }
    elif args.json:
        with open(args.json, encoding="utf-8") as f:
            datos = json.load(f)
    else:
        ap.error("indica --json <fichero> o --probar")

    msg = construir(datos)
    resultado = enviar(msg, usuario, passwd, simular=args.simular)
    print(json.dumps(resultado, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
