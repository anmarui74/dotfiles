#!/usr/bin/env bash
# lm-studio-gui — abre la ventana de LM Studio (y vuelve al modo servicio al cerrarla).
#
#   lm-studio-gui            abre la ventana (para antes el servicio headless)
#   lm-studio-gui parar      cierra la ventana y devuelve el modo servicio
#   lm-studio-gui estado     qué modo está activo
#
# El modo servicio (sin ventana) es el del arranque de sesión y el que sirve el
# API en el 1234 para Hermes/OpenCode; la ventana es solo para gestionar modelos.
set -uo pipefail

SERVICIO="lm-studio-app.service"
VENTANA="lm-studio-gui.service"

case "${1:-abrir}" in
  abrir|abre|start)
    if systemctl --user is-active --quiet "$VENTANA"; then
      echo "La ventana de LM Studio ya está abierta."
      exit 0
    fi
    systemctl --user start "$VENTANA" \
      && echo "Abriendo la ventana de LM Studio (el servicio headless se para mientras tanto)…"
    ;;
  parar|cerrar|stop)
    if systemctl --user is-active --quiet "$VENTANA"; then
      systemctl --user stop "$VENTANA" && echo "Ventana cerrada; vuelve el modo servicio (sin ventana)."
    else
      echo "La ventana de LM Studio no estaba abierta."
    fi
    ;;
  estado|status)
    if systemctl --user is-active --quiet "$VENTANA"; then
      echo "LM Studio: ventana abierta (unidad $VENTANA)."
    elif systemctl --user is-active --quiet "$SERVICIO"; then
      echo "LM Studio: modo servicio sin ventana (unidad $SERVICIO)."
    else
      echo "LM Studio: parado."
    fi
    ;;
  *)
    echo "Uso: lm-studio-gui [abrir|parar|estado]" >&2
    exit 2
    ;;
esac
