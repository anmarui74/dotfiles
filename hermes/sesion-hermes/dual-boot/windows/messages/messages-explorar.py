#!/usr/bin/env python3
"""Explorador del DOM de Mensajes de Google (perfil dedicado de Hermes) para el envío.

Solo lee: no escribe ni envía nada.
"""
import importlib.util
import json
import sys
import time

spec = importlib.util.spec_from_file_location("ml", "/home/antonio/.local/bin/messages-leer.py")
ml = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ml)

tab = ml.elegir(9224)
if not tab:
    print("No hay pestaña de Mensajes en el puerto 9224")
    raise SystemExit(1)
c = ml.CDP(tab["webSocketDebuggerUrl"])
try:
    print("URL:", c.js("location.href"))
    print("\n=== conversaciones (primeras 5) ===")
    print(c.js("""JSON.stringify([...document.querySelectorAll('mws-conversation-list-item')].slice(0,5)
        .map(e => ({nombre: (e.querySelector('[data-e2e-conversation-name]')||{}).innerText,
                    href: (e.querySelector('a.list-item')||{}).getAttribute ? e.querySelector('a.list-item').getAttribute('href') : null})))"""))

    print("\n=== botones relevantes ===")
    print(c.js("""JSON.stringify([...document.querySelectorAll('button,[role="button"],a[role="button"]')]
        .map(e => ({txt:(e.innerText||'').trim().slice(0,30), aria:e.getAttribute('aria-label'), testid:e.getAttribute('data-e2e')}))
        .filter(x => x.txt || x.aria).slice(0,20))"""))

    print("\n=== cajas de texto / campos ===")
    print(c.js("""JSON.stringify([...document.querySelectorAll('input, textarea, [contenteditable="true"]')]
        .map(e => ({tag:e.tagName, aria:e.getAttribute('aria-label'), placeholder:e.getAttribute('placeholder'),
                    testid:e.getAttribute('data-e2e'), role:e.getAttribute('role')})))"""))

    print("\n=== abriendo la conversacion de Maria (clic) ===")
    print("clic:", c.clic_en("[...document.querySelectorAll('mws-conversation-list-item')].find(it=>it.innerText.includes('Mart'))"))
    time.sleep(3)
    print("URL ahora:", c.js("location.href"))
    print("cabecera:", c.js("(()=>{const h=document.querySelector('mws-conversation-header');return h?h.innerText.split('\\n')[0]:null})()"))

    print("\n=== componentes tras abrir el hilo ===")
    print(c.js("""JSON.stringify({mensajes: document.querySelectorAll('mws-message-wrapper').length,
        entradas: [...document.querySelectorAll('textarea, [contenteditable="true"], input[type="text"]')]
            .map(e=>({tag:e.tagName, aria:e.getAttribute('aria-label'), ph:e.getAttribute('placeholder'), testid:e.getAttribute('data-e2e')}))})"""))
finally:
    c.cerrar()
