#!/usr/bin/env bash
# lm-studio-gui-run — lanza la ventana de LM Studio (lo usa lm-studio-gui.service).
#
# Antes de abrir la app limpia los Singleton* huérfanos (los que apuntan a un PID
# que ya no existe): si se quedan, la app se topa con un candado de un proceso
# muerto y muestra la lista de modelos vacía.
set -uo pipefail

CFG="$HOME/.config/LM Studio"
PID_VIVO=0

if [ -L "$CFG/SingletonLock" ]; then
  pid="$(readlink "$CFG/SingletonLock" 2>/dev/null | sed -n 's/.*-\([0-9]\+\)$/\1/p')"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    PID_VIVO=1
    printf 'lm-studio-gui-run: el candado apunta a un PID vivo (%s); no lo toco.\n' "$pid" >&2
  fi
fi

if [ "$PID_VIVO" -eq 0 ]; then
  rm -f "$CFG/SingletonLock" "$CFG/SingletonSocket" "$CFG/SingletonCookie"
fi

exec /usr/bin/lm-studio
