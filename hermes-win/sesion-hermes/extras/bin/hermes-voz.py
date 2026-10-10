#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""hvoz para Windows: lanza Hermes y activa el modo voz automaticamente.

Equivalente Windows del `hvoz` de Linux (~/.local/bin/hermes-voz + funcion zsh).
El CLI de Hermes no tiene bandera ni ajuste para arrancar en modo voz, y `-q`
siembra el texto LITERALMENTE (no pasa por los slash commands), asi que la unica
via es inyectar `/voice on` en la consola del proceso como si se tecleara:

  1. Se lanza Hermes en la MISMA consola (hereda) o en una consola nueva.
  2. Se espera a que el TUI pinte su prompt de verdad (marcador "to record" del
     placeholder, o simbolo de prompt + banner de Hermes). NUNCA el ">" del prompt
     del shell, que ya esta en pantalla.
  3. Se escriben los eventos de teclado del texto en el buffer de entrada
     (WriteConsoleInputW) y, tras una pausa, la tecla Enter. Nunca en la misma
     escritura: prompt_toolkit lo interpretaria como pegado y solo insertaria
     un salto de linea (misma regla critica que en Linux).
  4. Se CONFIRMA en pantalla que el comando se ejecuto; si no, se reintenta
     (Enter suelto si el texto ya estaba escrito, texto+Enter si no lo estaba).

Uso:
  python hermes-voz.py                 # lanza `hermes` en esta consola
  python hermes-voz.py --text "/voice on"
  python hermes-voz.py --cmd "hermes -p otro"
  python hermes-voz.py --nueva-consola  # para pruebas sin TTY propio

Variables: HV_CMD (comando), HV_WAIT (segundos de espera del prompt),
HV_LOG (fichero de log). Salida de diagnostico SIEMPRE a fichero: cuando el
script se adjunta a la consola del hijo, stdout es esa consola y no se debe
ensuciar.
"""
from __future__ import annotations

import argparse
import ctypes
import os
import subprocess
import sys
import time
from ctypes import wintypes as wt

k32 = ctypes.WinDLL("kernel32", use_last_error=True)

STD_INPUT_HANDLE = -10
STD_OUTPUT_HANDLE = -11
KEY_EVENT = 0x0001
CREATE_NEW_CONSOLE = 0x00000010
SHIFT_PRESSED = 0x0010
# Simbolos de prompt SOLO como respaldo del marcador especifico de Hermes, y
# exigiendo ademas una palabra de su banner: el ">" o el "$" del prompt de
# cmd.exe/PowerShell ya estan en pantalla y hacian que "se detectara el prompt"
# al instante, inyectando el texto antes de que el TUI existiera (quedaba escrito
# sin enviar: habia que pulsar Enter a mano).
PROMPT_SYMBOLS = ("\u276f", "\u203a", "\u00bb", "\u2192")
HERMES_TOKENS = ("Hermes", "Ctrl+B", "hermes")
# Placeholder del input en reposo ("type or Ctrl+B to record"): texto propio de
# Hermes, presente justo cuando el TUI ya lee teclado. Es la senal fiable.
READY_MARKERS = ("to record",)
VOICE_OK_MARKERS = ("Voice mode enabled", "Voice mode is already enabled")
VOICE_FAIL_MARKERS = ("Voice mode unavailable", "Voice mode requirements not met",
                      "Voice mode requires")
VOICE_ECHO = "/voice on"


class COORD(ctypes.Structure):
    _fields_ = [("X", ctypes.c_short), ("Y", ctypes.c_short)]


class SMALL_RECT(ctypes.Structure):
    _fields_ = [("Left", ctypes.c_short), ("Top", ctypes.c_short),
                ("Right", ctypes.c_short), ("Bottom", ctypes.c_short)]


class CONSOLE_SCREEN_BUFFER_INFO(ctypes.Structure):
    _fields_ = [("dwSize", COORD), ("dwCursorPosition", COORD),
                ("wAttributes", ctypes.c_ushort), ("srWindow", SMALL_RECT),
                ("dwMaximumWindowSize", COORD)]


class _Char(ctypes.Union):
    _fields_ = [("UnicodeChar", ctypes.c_wchar), ("AsciiChar", ctypes.c_char)]


class KEY_EVENT_RECORD(ctypes.Structure):
    _fields_ = [("bKeyDown", wt.BOOL), ("wRepeatCount", wt.WORD),
                ("wVirtualKeyCode", wt.WORD), ("wVirtualScanCode", wt.WORD),
                ("uChar", _Char), ("dwControlKeyState", wt.DWORD)]


class _Event(ctypes.Union):
    _fields_ = [("KeyEvent", KEY_EVENT_RECORD), ("_pad", ctypes.c_byte * 16)]


class INPUT_RECORD(ctypes.Structure):
    _fields_ = [("EventType", wt.WORD), ("Event", _Event)]


k32.GetStdHandle.argtypes = [wt.DWORD]
k32.GetStdHandle.restype = wt.HANDLE
k32.CreateFileW.argtypes = [wt.LPCWSTR, wt.DWORD, wt.DWORD, wt.LPVOID, wt.DWORD, wt.DWORD, wt.HANDLE]
k32.CreateFileW.restype = wt.HANDLE
GENERIC_READ, GENERIC_WRITE = 0x80000000, 0x40000000
FILE_SHARE_READ, FILE_SHARE_WRITE = 0x00000001, 0x00000002
OPEN_EXISTING = 3
INVALID_HANDLE_VALUE = wt.HANDLE(-1).value
k32.GetConsoleMode.argtypes = [wt.HANDLE, ctypes.POINTER(wt.DWORD)]
k32.GetConsoleMode.restype = wt.BOOL
k32.AttachConsole.argtypes = [wt.DWORD]
k32.AttachConsole.restype = wt.BOOL
k32.FreeConsole.argtypes = []
k32.FreeConsole.restype = wt.BOOL
k32.GetConsoleScreenBufferInfo.argtypes = [wt.HANDLE, ctypes.POINTER(CONSOLE_SCREEN_BUFFER_INFO)]
k32.GetConsoleScreenBufferInfo.restype = wt.BOOL
k32.ReadConsoleOutputCharacterW.argtypes = [wt.HANDLE, wt.LPWSTR, wt.DWORD, COORD,
                                           ctypes.POINTER(wt.DWORD)]
k32.ReadConsoleOutputCharacterW.restype = wt.BOOL
k32.WriteConsoleInputW.argtypes = [wt.HANDLE, ctypes.POINTER(INPUT_RECORD), wt.DWORD,
                                   ctypes.POINTER(wt.DWORD)]
k32.WriteConsoleInputW.restype = wt.BOOL
# MapVirtualKeyW vive en user32, no en kernel32 (y no es imprescindible: el scan
# code solo es un dato de relleno del evento).
try:
    _user32 = ctypes.WinDLL("user32", use_last_error=True)
    _user32.MapVirtualKeyW.argtypes = [wt.UINT, wt.UINT]
    _user32.MapVirtualKeyW.restype = wt.UINT
except OSError:  # pragma: no cover
    _user32 = None


def _scancode(vk: int) -> int:
    if not vk or _user32 is None:
        return 0
    try:
        return int(_user32.MapVirtualKeyW(vk, 0))
    except Exception:
        return 0


_VK_EXTRA = {"/": 0xBF, " ": 0x20, "\r": 0x0D, ".": 0xBE, ",": 0xBC, "-": 0xBD,
             "=": 0xBB, ";": 0xBA, "'": 0xDE, "`": 0xC0, "[": 0xDB, "]": 0xDD,
             "\\": 0xDC}

_LOG_PATH = None


def log(msg: str) -> None:
    line = f"{time.strftime('%d/%m/%Y %H:%M:%S')} {msg}\n"
    if _LOG_PATH:
        try:
            with open(_LOG_PATH, "a", encoding="utf-8") as fh:
                fh.write(line)
            return
        except OSError:
            pass
    sys.stderr.write(line)


def _has_console() -> bool:
    mode = wt.DWORD()
    return bool(k32.GetConsoleMode(k32.GetStdHandle(STD_INPUT_HANDLE), ctypes.byref(mode)))


def _open_console_handles():
    """(entrada, salida) de la consola adjunta.

    Los handles estandar del proceso NO se refrescan al hacer AttachConsole: si el
    proceso se lanzo desde un pipe (git-bash, CI) siguen apuntando al pipe y
    WriteConsoleInputW falla con ERROR_INVALID_HANDLE (6). Por eso se abren
    CONIN$/CONOUT$ explicitamente y solo se cae a los handles estandar si no hay
    consola.
    """
    hin = k32.CreateFileW("CONIN$", GENERIC_READ | GENERIC_WRITE,
                          FILE_SHARE_READ | FILE_SHARE_WRITE, None, OPEN_EXISTING, 0, None)
    hout = k32.CreateFileW("CONOUT$", GENERIC_READ | GENERIC_WRITE,
                           FILE_SHARE_READ | FILE_SHARE_WRITE, None, OPEN_EXISTING, 0, None)
    if hin in (None, INVALID_HANDLE_VALUE):
        hin = k32.GetStdHandle(STD_INPUT_HANDLE)
    if hout in (None, INVALID_HANDLE_VALUE):
        hout = k32.GetStdHandle(STD_OUTPUT_HANDLE)
    return hin, hout


def _screen_text(hout) -> str:
    info = CONSOLE_SCREEN_BUFFER_INFO()
    if not k32.GetConsoleScreenBufferInfo(hout, ctypes.byref(info)):
        return ""
    win = info.srWindow
    width = win.Right - win.Left + 1
    height = win.Bottom - win.Top + 1
    if width <= 0 or height <= 0:
        return ""
    buf = ctypes.create_unicode_buffer(width * height + 1)
    read = wt.DWORD()
    k32.ReadConsoleOutputCharacterW(hout, buf, width * height, COORD(win.Left, win.Top),
                                    ctypes.byref(read))
    return buf.value


def _vk_for(ch: str) -> tuple[int, int]:
    """(virtual-key code, control key state) for one character."""
    if ch.isalpha():
        return ord(ch.upper()), SHIFT_PRESSED if ch.isupper() else 0
    if ch.isdigit():
        return ord(ch), 0
    vk = _VK_EXTRA.get(ch, 0)
    return vk, 0


def _key_record(ch: str, down: bool) -> INPUT_RECORD:
    vk, state = _vk_for(ch)
    rec = INPUT_RECORD()
    rec.EventType = KEY_EVENT
    ev = rec.Event.KeyEvent
    ev.bKeyDown = 1 if down else 0
    ev.wRepeatCount = 1
    ev.wVirtualKeyCode = vk
    ev.wVirtualScanCode = _scancode(vk)
    ev.uChar.UnicodeChar = ch if down else "\0"
    ev.dwControlKeyState = state if down else 0
    return rec


def send_text(hin, text: str) -> None:
    records = []
    for ch in text:
        records.append(_key_record(ch, True))
        records.append(_key_record(ch, False))
    arr = (INPUT_RECORD * len(records))(*records)
    written = wt.DWORD()
    ok = k32.WriteConsoleInputW(hin, arr, len(records), ctypes.byref(written))
    if not ok:
        raise OSError(f"WriteConsoleInputW fallo (err {ctypes.get_last_error()})")


def send_enter(hin) -> None:
    recs = [_key_record("\r", True), _key_record("\r", False)]
    arr = (INPUT_RECORD * 2)(*recs)
    written = wt.DWORD()
    if not k32.WriteConsoleInputW(hin, arr, 2, ctypes.byref(written)):
        raise OSError(f"WriteConsoleInputW (Enter) fallo (err {ctypes.get_last_error()})")


def wait_for_prompt(hout, timeout: float, baseline: str = "") -> tuple[bool, str]:
    """Espera a que Hermes este REALMENTE leyendo teclado.

    Criterio principal: el marcador propio de Hermes ("to record", del placeholder
    del input) en una pantalla que YA ha cambiado respecto a `baseline` (la captura
    previa al lanzamiento). Respaldo: simbolo de prompt + palabra de su banner.

    Nunca solo un simbolo de prompt: la pantalla ya trae el ">" o el "$" del shell
    y eso hacia que se inyectara el texto antes de que el TUI existiera (quedaba
    escrito sin enviar y habia que pulsar Enter a mano).
    """
    deadline = time.monotonic() + timeout
    seen_foreign_prompt = False
    while time.monotonic() < deadline:
        text = _screen_text(hout)
        nueva = text != baseline
        if nueva and any(m in text for m in READY_MARKERS):
            return True, "marcador de Hermes en pantalla"
        if any(sym in text for sym in PROMPT_SYMBOLS):
            seen_foreign_prompt = True
            if nueva and any(tok in text for tok in HERMES_TOKENS):
                return True, "simbolo de prompt + banner de Hermes"
        time.sleep(0.25)
    if seen_foreign_prompt:
        return False, "solo habia un prompt ajeno (shell o sesion anterior)"
    return False, "sin prompt en pantalla"


def inject_and_verify(hin, hout, text: str, ok_markers, fail_markers, *, echo_marker=None,
                      enter_delay: float = 0.3, verify_wait: float = 10.0,
                      attempts: int = 4) -> str:
    """Inyecta `text` + Enter y confirma en pantalla que Hermes lo ejecuto.

    Devuelve "ok", "error" (Hermes lo rechazo) o "sin_confirmar". La pausa entre el
    texto y el Enter evita el pegado, pero si prompt_toolkit procesa los dos eventos
    en la misma lectura solo inserta un salto de linea: por eso, cuando el texto ya
    esta escrito en pantalla sin ejecutar, se reintenta con un Enter SUELTO.
    """
    for intento in range(1, attempts + 1):
        screen = _screen_text(hout)
        if any(m in screen for m in ok_markers):
            return "ok"
        if any(m in screen for m in fail_markers):
            return "error"
        if echo_marker and echo_marker in screen:
            log(f"aviso: {text!r} estaba escrito sin enviar; mando solo Enter")
            send_enter(hin)
        else:
            send_text(hin, text)
            time.sleep(enter_delay)
            send_enter(hin)
        log(f"inyectado (intento {intento}/{attempts}): {text!r} + Enter")
        deadline = time.monotonic() + verify_wait
        while time.monotonic() < deadline:
            screen = _screen_text(hout)
            if any(m in screen for m in ok_markers):
                return "ok"
            if any(m in screen for m in fail_markers):
                return "error"
            time.sleep(0.25)
    return "sin_confirmar"


def _screen_tail(hout, lines: int = 12) -> str:
    """Ultimas lineas no vacias de la pantalla (diagnostico en el log)."""
    text = _screen_text(hout)
    limpias = [ln.rstrip() for ln in text.splitlines() if ln.strip()]
    return " | ".join(limpias[-lines:])


def main() -> int:
    global _LOG_PATH
    ap = argparse.ArgumentParser(description="Lanzador hvoz (Hermes en modo voz) para Windows")
    ap.add_argument("--cmd", default=os.environ.get("HV_CMD", "hermes"),
                    help="comando a lanzar (por defecto: hermes)")
    ap.add_argument("--text", default="/voice on", help="texto a inyectar al arrancar")
    ap.add_argument("--wait", type=float, default=float(os.environ.get("HV_WAIT", "40")),
                    help="segundos maximos de espera del prompt")
    ap.add_argument("--enter-delay", type=float, default=0.3,
                    help="pausa entre el texto y el Enter (s)")
    ap.add_argument("--verify-wait", type=float, default=10.0,
                    help="segundos de espera de la confirmacion de cada intento")
    ap.add_argument("--nueva-consola", action="store_true",
                    help="lanzar el hijo en una consola nueva (pruebas sin TTY propio)")
    ap.add_argument("--no-wait-prompt", action="store_true",
                    help="inyectar sin esperar a ver el prompt en pantalla")
    ap.add_argument("--sin-verificar", action="store_true",
                    help="no confirmar en pantalla ni reintentar (comportamiento antiguo)")
    ap.add_argument("--hijo-timeout", type=float, default=0,
                    help="segundos maximos de vida del hijo antes de cerrarlo; 0 = sin limite "
                         "(por defecto, para no matar la sesion de Hermes que dejes abierta)")
    ap.add_argument("--captura", metavar="FICHERO",
                    help="volcar el texto de la consola a FICHERO (diagnostico)")
    ap.add_argument("--captura-espera", type=float, default=6.0,
                    help="segundos de espera antes de volcar la captura")
    ap.add_argument("--salir", action="store_true",
                    help="inyectar /exit tras la captura (diagnostico desatendido)")
    args = ap.parse_args()

    _LOG_PATH = os.environ.get("HV_LOG") or os.path.join(
        os.path.expanduser("~"), ".local", "logs", "hvoz.log")
    os.makedirs(os.path.dirname(_LOG_PATH), exist_ok=True)

    have_console = _has_console()
    use_new_console = args.nueva_consola or not have_console
    log(f"inicio: cmd={args.cmd!r} consola_propia={have_console} "
        f"nueva_consola={use_new_console} espera={args.wait}s")

    flags = CREATE_NEW_CONSOLE if use_new_console else 0
    # Captura previa al lanzamiento: en consola compartida la pantalla ya trae el
    # prompt del shell y, si se repite el lanzamiento, los restos de la sesion
    # anterior de Hermes. Solo cuenta como "listo" lo que APARECE despues.
    baseline = ""
    if have_console and not use_new_console:
        try:
            _h0, _ho0 = _open_console_handles()
            baseline = _screen_text(_ho0)
        except Exception:
            baseline = ""
    proc = subprocess.Popen(args.cmd, shell=True, creationflags=flags)
    log(f"hijo lanzado pid={proc.pid}")

    attached = False
    if use_new_console:
        # AttachConsole responde ERROR_ACCESS_DENIED (5) si el proceso llamante ya
        # esta adjunto a una consola (git-bash/mintty dan handles sin consola real,
        # pero el proceso puede seguir teniendo una asignada).
        k32.FreeConsole()
        last_err = None
        for _ in range(40):  # la consola del hijo tarda un instante en existir
            if k32.AttachConsole(proc.pid):
                attached = True
                break
            last_err = ctypes.get_last_error()
            time.sleep(0.1)
        if not attached:
            log(f"AVISO: no se pudo adjuntar a la consola del hijo (err {last_err})")
    elif have_console:
        attached = True  # consola compartida: el hijo hereda la nuestra

    if attached:
        hin, hout = _open_console_handles()
        info = CONSOLE_SCREEN_BUFFER_INFO()
        log("consola: buffer info ok=%s" % bool(k32.GetConsoleScreenBufferInfo(hout, ctypes.byref(info))))
        if not args.no_wait_prompt:
            ready, motivo = wait_for_prompt(hout, args.wait, baseline)
            log(f"prompt detectado: {ready} ({motivo})")
        try:
            if args.sin_verificar:
                send_text(hin, args.text)
                time.sleep(args.enter_delay)
                send_enter(hin)
                log(f"inyectado (sin verificar): {args.text!r} + Enter")
            else:
                estado = inject_and_verify(
                    hin, hout, args.text, VOICE_OK_MARKERS, VOICE_FAIL_MARKERS,
                    echo_marker=VOICE_ECHO if args.text.strip() == VOICE_ECHO else None,
                    enter_delay=args.enter_delay, verify_wait=args.verify_wait)
                log(f"resultado de la inyeccion: {estado}")
                if estado != "ok":
                    log(f"pantalla: {_screen_tail(hout)}")
        except OSError as exc:
            log(f"ERROR al inyectar: {exc}")
        if args.captura:
            time.sleep(args.captura_espera)
            try:
                text = _screen_text(hout)
                with open(args.captura, "w", encoding="utf-8") as fh:
                    fh.write(text)
                log(f"captura -> {args.captura} ({len(text)} caracteres)")
            except OSError as exc:
                log(f"ERROR en la captura: {exc}")
        if args.salir:
            # Mismo patron que /voice on: si prompt_toolkit se traga el Enter (lo
            # lee junto al texto y solo inserta un salto), un Enter SUELTO posterior
            # envia lo que ya esta escrito.
            send_text(hin, "/exit")
            time.sleep(args.enter_delay)
            send_enter(hin)
            log("inyectado '/exit'")
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                log("/exit no surtio efecto; mando un Enter suelto")
                send_enter(hin)

    try:
        code = proc.wait(timeout=args.hijo_timeout or None)
    except subprocess.TimeoutExpired:
        log(f"el hijo no salio en {args.hijo_timeout:g}s; cerrando su arbol de procesos")
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        try:
            code = proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            code = -1
    if attached and use_new_console:
        k32.FreeConsole()
    log(f"fin: codigo de salida {code}")
    return code


if __name__ == "__main__":
    sys.exit(main())
