# Copyright (c) 2010 Aldo Cortesi
# Copyright (c) 2010, 2014 dequis
# Copyright (c) 2012 Randall Ma
# Copyright (c) 2012-2014 Tycho Andersen
# Copyright (c) 2012 Craig Barnes
# Copyright (c) 2013 horsik
# Copyright (c) 2013 Tao Sauvage
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import os
import subprocess
from libqtile import hook

from typing import List  # noqa: F401

from libqtile import bar, layout, widget
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy
from libqtile.utils import guess_terminal

# Espacio para las variables
mod = "mod4"
terminal = guess_terminal()
dispositivo_red = "enp0s31f6"
color_barra = "#282a36"
tamaño_barra = 30
tamaño_iconos = 20
fuente_predeterminada = "Ubuntu Mono Nerd Font"
tamaño_fuente = 16
color_activo="#ffffff"
color_fg = "#ffffff"
color_bg = "#282a36"
color_inactivo = "#6272a4"
color_oscuro = "#44475a"
color_claro = "#bd93f9"
color_urgent = "#ff5555"
color_texto1 = "#bd93f9"
color_grupoA = "#025181"
color_grupoC = "#C9912A"
color_grupoM = "#59884B"
color_grupoR = "#3D96CC"
color_grupoS = "#CE89F0"
color_grupoH = "#A4F3FD"
color_grupoE = "#F84A4A"

# Espacio para definir las funciones

# Funcion para insertar un separador
def fc_separador():
    return widget.Sep(
                    linewidth = 0,
                    padding = 20,
                    foreground = color_fg,
                    background = color_bg,
                )

# Funcion inicio y final del rectangulo
def fc_rectangulo(vColor,tipo):
    if tipo == 0:
        icono = ""
    else:
        icono = ""
    return widget.TextBox(
                    text = icono,
                    fontsize = tamaño_barra,
                    foreground = vColor,
                    background = color_bg,
                    padding = 0
                    ,
                )

# Funcion para escribir un icono
def fc_icono(icono,color_grupo):
    return widget.TextBox(
                    text = icono,
                    foreground = color_fg,
                    background = color_grupo,
                    fontsize = tamaño_iconos,
                )

# Combinaciones de teclas
keys = [
    # Switch between windows
    Key([mod], "h", lazy.layout.left(), desc="Move focus to left"),
    Key([mod], "l", lazy.layout.right(), desc="Move focus to right"),
    Key([mod], "j", lazy.layout.down(), desc="Move focus down"),
    Key([mod], "k", lazy.layout.up(), desc="Move focus up"),
    Key([mod], "Left", lazy.layout.left(), desc="Move focus to left"),
    Key([mod], "Right", lazy.layout.right(), desc="Move focus to right"),
    Key([mod], "Down", lazy.layout.down(), desc="Move focus down"),
    Key([mod], "Up", lazy.layout.up(), desc="Move focus up"),
    Key([mod], "space", lazy.layout.next(), desc="Move window focus to other window"),

    # Move windows between left/right columns or move up/down in current stack.
    # Moving out of range in Columns layout will create new column.
    Key([mod, "shift"], "h", lazy.layout.shuffle_left(), desc="Move window to the left"),
    Key([mod, "shift"], "l", lazy.layout.shuffle_right(), desc="Move window to the right"),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down(), desc="Move window down"),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up(), desc="Move window up"),
    Key([mod, "shift"], "Left", lazy.layout.shuffle_left(), desc="Move window to the left"),
    Key([mod, "shift"], "Right", lazy.layout.shuffle_right(), desc="Move window to the right"),
    Key([mod, "shift"], "Down", lazy.layout.shuffle_down(), desc="Move window down"),
    Key([mod, "shift"], "Up", lazy.layout.shuffle_up(), desc="Move window up"),


    # Grow windows. If current window is on the edge of screen and direction
    # will be to screen edge - window would shrink.
    Key([mod, "control"], "h", lazy.layout.grow_left(), desc="Grow window to the left"),
    Key([mod, "control"], "l", lazy.layout.grow_right(), desc="Grow window to the right"),
    Key([mod, "control"], "j", lazy.layout.grow_down(), desc="Grow window down"),
    Key([mod, "control"], "k", lazy.layout.grow_up(), desc="Grow window up"),
    Key([mod, "control"], "Left", lazy.layout.grow_left(), desc="Grow window to the left"),
    Key([mod, "control"], "Right", lazy.layout.grow_right(), desc="Grow window to the right"),
    Key([mod, "control"], "Down", lazy.layout.grow_down(), desc="Grow window down"),
    Key([mod, "control"], "Up", lazy.layout.grow_up(), desc="Grow window up"),
    Key([mod], "n", lazy.layout.normalize(), desc="Reset all window sizes"),
    Key([mod], "o", lazy.layout.maximize(), desc="Maximize window sizes"),


    # Toggle between split and unsplit sides of stack.
    # Split = all windows displayed
    # Unsplit = 1 window displayed, like Max layout, but still with
    # multiple stack panes
    Key([mod, "shift"], "Return", lazy.layout.toggle_split(),
        desc="Toggle between split and unsplit sides of stack"),
    Key([mod], "Return", lazy.spawn("alacritty"), desc="Launch terminal"),

    # Teclas para lanzar menu Rofi
    Key ([mod], "m", lazy.spawn("rofi -show drun"), desc="Abrir menu"),
    
    # Teclas para lanzar navegador Chrome
    Key ([mod], "g", lazy.spawn("google-chrome-stable"), desc="Abrir navegador Chrome"),

    # Teclas para lanzar gestor de archivos PCManFM
    Key ([mod], "p", lazy.spawn("pcmanfm"), desc="Abrir gestor de archivos PCManFM"),

    # Toggle between different layouts as defined below
    Key([mod], "Tab", lazy.next_layout(), desc="Toggle between layouts"),
    Key([mod], "q", lazy.window.kill(), desc="Kill focused window"),
    Key([mod, "control"], "r", lazy.restart(), desc="Restart Qtile"),
    Key([mod, "control"], "q", lazy.shutdown(), desc="Shutdown Qtile"),
    Key([mod], "r", lazy.spawncmd(),
        desc="Spawn a command using a prompt widget"),
]

# Grupos
groups = [Group(i) for i in [
    "  ","  ","  ","  ","  "," 嗢 ","  ","  ","  ",
]]

for i, group in enumerate(groups):
    numeroEscritorio =str(i+1)
    keys.extend([
        # mod1 + letter of group = switch to group
        Key([mod], numeroEscritorio, lazy.group[group.name].toscreen(),
            desc="Switch to group {}".format(group.name)),

        # mod1 + shift + letter of group = switch to & move focused window to group
        Key([mod, "shift"], numeroEscritorio, lazy.window.togroup(group.name, switch_group=True),
            desc="Switch to & move focused window to group {}".format(group.name)),
        # Or, use below if you prefer not to switch to that group.
        # # mod1 + shift + letter of group = move focused window to group
        # Key([mod, "shift"], i.name, lazy.window.togroup(i.name),
        #     desc="move focused window to group {}".format(i.name)),
    ])

# Diseño
layouts = [
    layout.Columns(
        border_normal = "#6D6D6D",
        border_focus = "#ff4400",
        border_on_single = True,
        border_width = 4,
        single_border_width = 4,
        margin = 6,
        single_margin = 6,
    ),
    layout.Max(),
    # Try more layouts by unleashing below layouts.
    # layout.Stack(num_stacks=2),
    # layout.Bsp(),
    # layout.Matrix(),
    layout.MonadTall(
        border_normal = "#6D6D6D",
        border_focus = "#ff4400",
        border_on_single = True,
        border_width = 4,
        single_border_width = 4,
        margin = 6,
        single_margin = 6,
    ),
    layout.MonadWide(
        border_normal = "#6D6D6D",
        border_focus = "#ff4400",
        border_on_single = True,
        border_width = 4,
        single_border_width = 4,
        margin = 6,
        single_margin = 6,
    ),
    # layout.RatioTile(),
    # layout.Tile(),
    # layout.TreeTab(),
    layout.VerticalTile(
        border_normal = "#6D6D6D",
        border_focus = "#ff4400",
        border_on_single = True,
        border_width = 4,
        single_border_width = 4,
        margin = 6,
        single_margin = 6,
    ),
    # layout.Zoomy(),
]

widget_defaults = dict(
    font=fuente_predeterminada,
    fontsize=tamaño_fuente,
    padding=3,
)
extension_defaults = widget_defaults.copy()

# 
screens = [
    Screen(
        top=bar.Bar(
            [
                widget.CurrentLayout(),
                fc_separador(),
                widget.GroupBox(
                    active = color_activo,
                    border_width = 1,
                    center_aligned = "true",
                    disable_drag = "true",
                    fontsize = tamaño_iconos,
                    foreground = color_fg,
                    highlight_method = "line",
                    inactive = color_inactivo,
                    margin_x = 1,
                    margin_y = 5,
                    other_current_screen_border = color_oscuro,
                    other_screen_border = color_oscuro,
                    padding_x = 0,
                    padding_y = 10,
                    this_current_screen_border = color_claro,
                    this_screen_border = color_claro,
                    urgent_alert_method = "line",
                    urgent_border = color_urgent,
                ),
                fc_separador(),
                widget.Prompt(),
                widget.WindowName(
                    foreground = color_texto1,
                    background = color_bg,
                ),
                widget.Systray(
                    icon_size = tamaño_iconos,
                    background = color_bg,
                ),
                fc_separador(),
                # Grupo CheckUpdates
                fc_rectangulo(color_grupoA, 0),
                fc_icono("  ", color_grupoA),
                widget.CheckUpdates(
                    # foreground = color_fg,
                    background = color_grupoA,
                    # custom_command = "checkupdates",
                    # Rexecute = "alacritty --command sudo pacman -Syu",
                    color_no_updates = "#F84A4A",
                    colour_have_updates = "#59884B",
                    no_update_string = "  0",
                    display_format = "  {updates}",
                    update_interval = 900,
                    distro = 'Arch_checkupdates'
                ),
                fc_rectangulo(color_grupoA, 1),
                fc_separador(),
                # Grupo CPU
                fc_rectangulo(color_grupoC, 0),
                fc_icono("", color_grupoC),
                widget.CPU(
                    foreground = color_fg,
                    background = color_grupoC,
                    format = " CPU {load_percent}%",
                ),
                fc_icono(" ", color_grupoC),
                widget.ThermalSensor(
                    foreground = color_fg,
                    background = color_grupoC,
                    threshold = 70,
                    tag_sensor = "Package id 0",
                    fmt = " TEMP {}",
                ),
                fc_rectangulo(color_grupoC, 1),
                fc_separador(),
                # Grupo RAM
                fc_rectangulo(color_grupoM, 0),
                fc_icono("", color_grupoM),
                widget.Memory(
                    foreground = color_fg,
                    background = color_grupoM,
                    fmt = " RAM{}",
                ),
                fc_rectangulo(color_grupoM, 1),
                fc_separador(),
                # Grupo RED
                fc_rectangulo(color_grupoR, 0),
                fc_icono(" ", color_grupoR),
                widget.Net(
                    foreground = color_fg,
                    background = color_grupoR,
                    format = " RED  {down}  {up}",
                    interface = dispositivo_red,
                    # use_bits = "true",
                ),
                fc_rectangulo(color_grupoR, 1),
                fc_separador(),
                # Grupo Volumen
                fc_rectangulo(color_grupoS, 0),
                fc_icono("墳 ", color_grupoS),
                widget.Volume(
                    foreground = color_fg,
                    background = color_grupoS,
                    fmt = "{}",
                ),
                fc_rectangulo(color_grupoS, 1),
                fc_separador(),
                # Grupo Hora
                fc_rectangulo(color_grupoH, 0),
                widget.Clock(
                    foreground = color_bg,
                    background = color_grupoH,
                    format=' %Y-%m-%d %a %H:%M %p',
                    ),
                fc_rectangulo(color_grupoH, 1),
                fc_separador(),
                # Grupo Exit
                fc_rectangulo(color_grupoE, 0),
                widget.QuickExit(
                    foreground = color_fg,
                    background = color_grupoE,
                    default_text = " SALIDA ",
                ),
                fc_rectangulo(color_grupoE, 1),              
            ],
            tamaño_barra,
            background=color_barra,
        ),
        x=1440,
        y=560,
        width=2560,
        height=1440,
    ),
    Screen(
        top=bar.Bar(
            [
                widget.CurrentLayout(),
                fc_separador(),
                widget.GroupBox(
                    active = color_activo,
                    border_width = 1,
                    center_aligned = "true",
                    disable_drag = "true",
                    fontsize = tamaño_iconos,
                    foreground = color_fg,
                    highlight_method = "line",
                    inactive = color_inactivo,
                    margin_x = 1,
                    margin_y = 5,
                    other_current_screen_border = color_oscuro,
                    other_screen_border = color_oscuro,
                    padding_x = 0,
                    padding_y = 10,
                    this_current_screen_border = color_claro,
                    this_screen_border = color_claro,
                    urgent_alert_method = "line",
                    urgent_border = color_urgent,
                ),
                fc_separador(),
                widget.Prompt(),
                widget.WindowName(
                    foreground = color_bg,
                    background = color_bg,
                ),
                fc_separador(),
                # Grupo CheckUpdates
                fc_rectangulo(color_grupoA, 0),
                fc_icono("  ", color_grupoA),
                widget.CheckUpdates(
                    # foreground = color_fg,
                    background = color_grupoA,
                    # custom_command = "checkupdates",
                    # Rexecute = "alacritty --command sudo pacman -Syu",
                    color_no_updates = "#F84A4A",
                    colour_have_updates = "#59884B",
                    no_update_string = "  0",
                    display_format = "  {updates}",
                    update_interval = 900,
                    distro = 'Arch_checkupdates'
                ),
                fc_rectangulo(color_grupoA, 1),
                fc_separador(),
                # Grupo CPU
                fc_rectangulo(color_grupoC, 0),
                fc_icono("", color_grupoC),
                widget.CPU(
                    foreground = color_fg,
                    background = color_grupoC,
                    format = " CPU {load_percent}%",
                ),
                fc_icono(" ", color_grupoC),
                widget.ThermalSensor(
                    foreground = color_fg,
                    background = color_grupoC,
                    threshold = 70,
                    tag_sensor = "Package id 0",
                    fmt = " TEMP {}",
                ),
                fc_rectangulo(color_grupoC, 1),
                fc_separador(),
                # Grupo RAM
                fc_rectangulo(color_grupoM, 0),
                fc_icono("", color_grupoM),
                widget.Memory(
                    foreground = color_fg,
                    background = color_grupoM,
                    fmt = " RAM{}",
                ),
                fc_rectangulo(color_grupoM, 1),
                fc_separador(),
                # Grupo RED
                fc_rectangulo(color_grupoR, 0),
                fc_icono(" ", color_grupoR),
                widget.Net(
                    foreground = color_fg,
                    background = color_grupoR,
                    format = " RED  {down}  {up}",
                    interface = dispositivo_red,
                    # use_bits = "true",
                ),
                fc_rectangulo(color_grupoR, 1),
                fc_separador(),
                # Grupo Volumen
                fc_rectangulo(color_grupoS, 0),
                fc_icono("墳 ", color_grupoS),
                widget.Volume(
                    foreground = color_fg,
                    background = color_grupoS,
                    fmt = "{}",
                ),
                fc_rectangulo(color_grupoS, 1),
                fc_separador(),
            ],
            tamaño_barra,
            background=color_barra,
        ),
        x=0,
        y=0,
        width=1440,
        height=2560,
    ),
]

# Drag floating layouts.
mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(),
         start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(),
         start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front())
]

dgroups_key_binder = None
dgroups_app_rules = []  # type: List
follow_mouse_focus = True
bring_front_click = False
cursor_warp = False
floating_layout = layout.Floating(float_rules=[
    # Run the utility of `xprop` to see the wm class and name of an X client.
    *layout.Floating.default_float_rules,
    Match(wm_class='confirmreset'),  # gitk
    Match(wm_class='makebranch'),  # gitk
    Match(wm_class='maketag'),  # gitk
    Match(wm_class='ssh-askpass'),  # ssh-askpass
    Match(title='branchdialog'),  # gitk
    Match(title='pinentry'),  # GPG key password entry
])
auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = True

# If things like steam games want to auto-minimize themselves when losing
# focus, should we respect this or not?
auto_minimize = True

# XXX: Gasp! We're lying here. In fact, nobody really uses or cares about this
# string besides java UI toolkits; you can see several discussions on the
# mailing lists, GitHub issues, and other WM documentation that suggest setting
# this string if your java app doesn't work correctly. We may as well just lie
# and say that we're a working one by default.
#
# We choose LG3D to maximize irony: it is a 3D non-reparenting WM written in
# java that happens to be on java's whitelist.
wmname = "LG3D"

@hook.subscribe.startup_once
def autostart():
    home = os.path.expanduser('~')
    subprocess.Popen([home + '/.config/qtile/autostart.sh'])
