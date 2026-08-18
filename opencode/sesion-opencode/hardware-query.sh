#!/bin/bash
# ============================================================
# hardware-query.sh — Wrapper de hardware-query.py
# (consulta rápida de hardware via index.json)
#
# Uso: source ~/.config/opencode/hardware-query.sh && hw_query <campo>
# Campos: status, cpu, gpu, ram, motherboard, wifi, bluetooth, all
# ============================================================

HW_PY="/home/antonio/.config/opencode/hardware-query.py"

hw_query() {
    if [ -x "$HW_PY" ]; then
        python3 "$HW_PY" "$1"
    else
        echo "❌ No se encontró $HW_PY"
        return 1
    fi
}
