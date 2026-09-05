# 🖥️ Display Cycle

**Selector visual de modos de pantalla Win+P para GNOME**

| 🧑‍💻 Antonio | 📍 Pechina, Almería | 🖥️ Rust + egui |
|---|---|---|

---

## 📋 Descripción

Aplicación Rust con egui que muestra una ventana sin decoraciones con 4 iconos de modos de pantalla. Se activa con Super+P y aplica la configuración con `gdctl`.

### Modos
| # | Modo | Descripción |
|---|------|-------------|
| 1 | Extendido | DP-1 izquierda + DP-2 derecha, primario DP-2 |
| 2 | Espejado | DP-1 = DP-2, mismo monitor lógico, primario DP-2 |
| 3 | Solo DP-1 | Solo DP-1, primario DP-1 |
| 4 | Solo DP-2 | Solo DP-2, primario DP-2 |

---

## 🛠️ Requisitos

| Requisito | Versión |
|-----------|---------|
| Rust | 1.78+ |
| `gdctl` | instalado |
| GNOME Shell | Wayland |

---

## 🚀 Instalación

```bash
cd /home/antonio/display-cycle
cargo build --release
cp target/release/display-cycle ~/.local/bin/display-cycle-ui
```

---

## ⌨️ Uso

| Acción | Método |
|--------|--------|
| Abrir selector | Super+P |
| Seleccionar modo | Clic o teclas 1-4 |
| Cerrar | Escape |

La ventana se cierra automáticamente tras la selección.

---

## ⚙️ Configuración

| Ruta | Descripción |
|------|-------------|
| `icons/` | PNG de iconos de modos |
| `src/main.rs` | Lógica UI y aplicación de modos |
| `Cargo.toml` | Dependencias |

Atajo dconf: `/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0`

---

## 📌 Notas

- Ventana transparente, sin decoraciones, 560x440.
- Single instance vía `/tmp/display-cycle.lock`.
- Hot-reload de iconos al modificar PNG.
- Modo espejo usa mismo monitor lógico con primario DP-2.

---
> 📁 `/home/antonio/display-cycle/` · 🎯 Super+P
