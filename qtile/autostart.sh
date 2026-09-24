#!/bin/sh

# Configuracion teclado espanol
setxkbmap es &

# Configuracion de Pantalla
xrandr --output DVI-D-0 --off --output HDMI-0 --off --output HDMI-1 --off --output DP-0 --mode 2560x1440 --pos 0x0 --rotate right --output DP-1 --off --output DP-2 --mode 2560x1440 --pos 1440x560 --rotate normal --output DP-3 --off

# Iconos del sistema

udiskie -t &

nm-applet &

dropbox &

megasync &

nitrogen --restore &

xscreensaver -no-splash &

# Programas al inicio

picom -b -f

