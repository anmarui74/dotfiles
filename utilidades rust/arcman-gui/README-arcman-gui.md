# 🦀 arcman-gui — Gestor de paquetes de Arch Linux (Interfaz Gráfica)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Operativo | 10/08/2026 | Antonio |

> Versión con interfaz gráfica del gestor arcman, desarrollada en Rust con Iced. Ofrece las mismas funciones que la CLI con una ventana a colores y diálogos de confirmación.

---

## 📑 Índice

1. [¿Qué es arcman-gui?](#qué-es-arcman-gui)
2. [Diferencia con arcman (CLI)](#diferencia-con-arcman-cli)
3. [Requisitos y dependencias](#requisitos-y-dependencias)
4. [Instalación](#instalación)
5. [La interfaz gráfica](#la-interfaz-gráfica)
6. [Pantallas (funcionalidades)](#pantallas-funcionalidades)
7. [Diálogo de confirmación](#diálogo-de-confirmación)
8. [Flujo interno del programa](#flujo-interno-del-programa)
9. [Seguridad](#seguridad)
10. [Mejoras aplicadas](#mejoras-aplicadas)
11. [Historial de cambios](#historial-de-cambios)
12. [Compilación desde el código fuente](#compilación-desde-el-código-fuente)

---

## ¿Qué es arcman-gui?

`arcman-gui` es la **versión con interfaz gráfica** del gestor de paquetes `arcman`. Está escrita en **Rust** con el framework **Iced** (el toolkit de GUI nativo para Rust), y ofrece las mismas funcionalidades que la versión de terminal pero en una ventana con:

- 🖱️ **Navegación con clic** (barra lateral con 9 secciones)
- 🌗 **Tema claro/oscuro** automático (detecta el esquema de GNOME) y conmutador manual
- 🎨 **Iconos** (Nerd Font) y colores de acento
- ⚡ **Operaciones asíncronas** (la interfaz no se congela mientras pacman trabaja)
- ✅ **Diálogos de confirmación** antes de cada operación privilegiada

La versión CLI (`arcman`) y la GUI (`arcman-gui`) son **herramientas independientes** que comparten la misma lógica de gestión de paquetes.

---

## Diferencia con arcman (CLI)

| Aspecto | `arcman` (CLI) | `arcman-gui` (GUI) |
|---------|----------------|---------------------|
| **Interfaz** | Terminal, colores ANSI | Ventana gráfica (Iced) |
| **Ejecución** | `arcman` en terminal | Clic en icono o `arcman-gui` |
| **Acceso directo** | No | Sí (`arcman.desktop`) |
| **Elevación de permisos** | `sudo` (contraseña en terminal) | **`pkexec`** (ventana gráfica de PolicyKit) |
| **Tema** | Fijo (colores ANSI) | Claro/oscuro (detecta GNOME + botón) |
| **Framework** | Rust estándar | Rust + Iced + Tokio |

---

## Requisitos y dependencias

| Dependencia | ¿Para qué? | ¿Obligatoria? |
|-------------|-----------|---------------|
| `pacman` | Gestor base de paquetes | ✅ Sí |
| `yay` | Actualizar/instalar desde repositorios + AUR | ⚠️ Recomendada (si no, usa `paru`) |
| `paru` | Alternativa a yay para AUR | ⚠️ Alternativa |
| `pacman-contrib` | Proporciona `paccache` (limpieza de caché) | ⚠️ Recomendada |
| `pkexec` (polkit) | Elevar permisos (ventana gráfica) | ✅ Sí |
| `curl` | Comprobación de conexión a internet | ✅ Sí |
| `gsettings` | Detectar tema claro/oscuro (GNOME) | ⚠️ Recomendada |

> 💡 **Detección automática:** igual que en el CLI, detecta `yay` → `paru` → `pacman` en ese orden.

---

## Instalación

### Acceso directo y binario

```
/home/antonio/.local/bin/arcman-gui     ← binario ejecutable
/home/antonio/.local/share/applications/arcman.desktop   ← acceso directo (menú)
/home/antonio/.local/share/icons/.../arcman.png y .svg   ← iconos
```

El `.desktop` apunta a `Exec=/home/antonio/.local/bin/arcman-gui` con `Terminal=false`, así que aparece en el menú de aplicaciones de GNOME.

---

## La interfaz gráfica

```
┌─────────────────────────────────────────────────────────────────────┐
│  arcman                        ┌─────────────────────────────────┐  │
│  Gestor de paquetes            │  (contenido de la pantalla      │  │
│  ─────────────────             │   activa, ver sección siguiente)│  │
│                                │                                 │  │
│  ⚭  Estado                     │                                 │  │
│  ⟳  Actualizar                 │                                 │  │
│  🔍  Buscar                    │                                 │  │
│  ＋  Instalar                  │                                 │  │
│  🗑  Eliminar                  │                                 │  │
│  ⚭  Huérfanos                  │                                 │  │
│  🧹  Limpiar                   │                                 │  │
│  ⭐  Completo                  │                                 │  │
│  ℹ  Acerca de                  │                                 │  │
│                                │                                 │  │
│  Tema: [Oscuro/Claro]          │                                 │  │
└─────────────────────────────────────────────────────────────────────┘
```

- **Ventana:** 1000×725 píxeles (mínimo 720×480)
- **Barra lateral:** 180 px con 9 secciones
- **Salida:** caja de texto con fuente monoespaciada (DroidSansMono Nerd Font) y borde de color primario, desplazable
- **Icono de ventana:** círculo azul degradado (generado por código)

---

## Pantallas (funcionalidades)

### ⚭ Estado — `Screen::Status`

Muestra información del sistema:
- Gestor de paquetes detectado (yay/paru/pacman)
- ¿yay instalado? ✅/❌
- ¿paru instalado? ✅/❌
- ¿paccache instalado? ✅/❌
- Actualizaciones disponibles (vía `pacman -Qu`, muestra hasta 25)

Botón: **"Comprobar estado"**

---

### ⟳ Actualizar — `Screen::Update`

Actualiza todos los paquetes del sistema con el gestor detectado.

- Botón: **"Actualizar sistema"**
- Pide confirmación
- **Comprueba conexión a internet** (desde 10/08/2026)
- Ejecuta: `pkexec yay -Syu --noconfirm` (o paru/pacman)

---

### 🔍 Buscar — `Screen::Search`

Campo de texto para buscar paquetes en los repositorios.

- Input: nombre del paquete (ej: `neovim`)
- Ejecuta: `yay -Ss --color=never <paquete>` (o paru/pacman)

---

### ＋ Instalar — `Screen::Install`

Instala uno o más paquetes (separados por espacio).

- Input: `firefox neovim git`
- Pide confirmación
- Ejecuta: `pkexec yay -S --noconfirm <paquetes>`

---

### 🗑 Eliminar — `Screen::Remove`

Elimina uno o más paquetes.

- Input: `firefox neovim`
- Pide confirmación
- Ejecuta: `pkexec pacman -Rns --noconfirm <paquetes>`

> 🔧 **Desde 10/08/2026** usa `-Rns` (antes `-Rsnc`, demasiado agresivo).

---

### ⚭ Huérfanos — `Screen::Orphans`

Busca y elimina paquetes huérfanos (dependencias no usadas).

1. Botón: **"Buscar huérfanos"** → ejecuta `pacman -Qtdq`
2. Si hay resultados, muestra el número y activa el botón **"Eliminar huérfanos"**
3. Pide confirmación
4. Ejecuta: `pkexec pacman -Rns --noconfirm <huérfanos>`

---

### 🧹 Limpiar — `Screen::Clean`

Limpia la caché de paquetes.

1. Si `paccache` está instalado: botón **"Limpiar caché"** → `pkexec paccache -r` (mantiene 3 versiones)
2. Si no: avisa para instalar `pacman-contrib`
3. **Desde 10/08/2026:** también limpia la caché de AUR → `pkexec yay -Sc` (o paru)

---

### ⭐ Completo — `Screen::Full`

Mantenimiento completo en 3 pasos, con una salida numerada `[1/3]`, `[2/3]`, `[3/3]`:

1. **Actualizar** → `pkexec yay -Syu --noconfirm`
2. **Limpiar caché** → `pkexec paccache -r` + **`pkexec yay -Sc`** (AUR, desde 10/08/2026)
3. **Eliminar huérfanos** → detecta con `pacman -Qtdq` y elimina con `pkexec pacman -Rns`

> 🌐 **Desde 10/08/2026:** comprueba la conexión a internet al inicio y aborta con mensaje claro si no hay.

---

### ℹ Acerca de — `Screen::About`

Información de la aplicación: nombre, versión 0.2.0, framework (Iced) y gestor de paquetes detectado.

---

## Diálogo de confirmación

Toda operación que modifica el sistema (instalar, eliminar, actualizar, limpiar, huérfanos, completo) muestra un **diálogo modal**:

```
┌──────────────────────────────────────┐
│  ⚠    Confirmar operación           │
│  ─────────────────────              │
│                                      │
│  Actualizar todos los paquetes del   │
│  sistema                             │
│                                      │
│    [✗ Cancelar]   [✓ Confirmar]     │
└──────────────────────────────────────┘
```

- El fondo se oscurece con un overlay semitransparente
- El botón **Confirmar** usa el estilo `Destructive` (rojo)
- Mientras se ejecuta, se muestra "Procesando..."

---

## Flujo interno del programa

```
App::new()
  └─ detecta tema (system_is_dark → Dark/Light)
        │
        ▼
  App::update(Message)
  ┌────────────────────────────┐
  │ Navigate(Screen)           │ → cambia de pantalla
  │ RunStatus / RunSearch      │ → operaciones sin privilegios (run_cmd)
  │ RunUpdate/Install/Remove   │ → abre diálogo de confirmación
  │   Clean/Full/OrphansClean  │
  │ ConfirmAction              │ → run_pending_action(action)
  │   ├─ Install  → run_priv(yay -S)
  │   ├─ Remove   → run_priv(pacman -Rns)
  │   ├─ Update   → check_network + run_priv(yay -Syu)
  │   ├─ OrphansClean → run_priv(pacman -Rns)
  │   ├─ Clean    → run_priv(paccache -r) + clean_aur_cache()
  │   └─ Full     → check_network + update + clean + clean_aur_cache() + orphans
  │ TaskResult(Ok/Err)         │ → muestra salida o error
  └────────────────────────────┘
```

### Funciones clave

| Función | Propósito |
|---------|-----------|
| `generate_icon()` | Genera el icono RGBA de 32×32 (círculo azul degradado) por código |
| `strip_ansi()` | Elimina códigos de escape ANSI de la salida de pacman (CSI y OSC) |
| `which(name)` | Comprueba si un binario existe en el PATH |
| `detect_pm()` | Devuelve `yay`, `paru`, `pacman` o `none` |
| `system_is_dark()` | Consulta `gsettings` para detectar el tema de GNOME |
| `run_cmd()` | Ejecuta un comando asíncrono y captura salida + errores (Tokio) |
| `run_priv()` | Ejecuta un comando con **`pkexec`** (ventana gráfica de permisos) |
| `check_network()` | Comprueba conexión a internet con `curl` (timeout 5s) |
| `clean_aur_cache()` | Limpia la caché de AUR (`yay -Sc` / `paru -Sc`) |
| `render_sidebar()` | Dibuja la barra lateral de navegación + selector de tema |
| `render_confirm_dialog()` | Dibuja el diálogo modal de confirmación |

---

## Seguridad

- 🔐 **Permisos con `pkexec`:** todas las operaciones privilegiadas usan **PolicyKit** con ventana gráfica de contraseña (a diferencia del CLI que usa `sudo`). Esto es apropiado para una GUI.
- ❓ **Confirmación obligatoria:** ninguna operación destructiva se ejecuta sin el diálogo de confirmación modal
- ✅ **`--noconfirm` acotado:** se usa dentro de la GUI para que pacman no pregunte interactivamente (la confirmación ya la dio el usuario en el diálogo)
- 🧹 **Eliminación segura:** `-Rns` (sin la `-c` agresiva desde 10/08/2026)
- 🌐 **Comprobación de red:** evita fallos crípticos de pacman sin internet en Actualizar y Completo
- ⚡ **Asíncrono:** las operaciones no bloquean la interfaz (Tokio `spawn_blocking`)

---

## Mejoras aplicadas

### 10/08/2026 — Revisión y mejoras (con asistencia de IA)

| # | Mejora | Detalle |
|---|--------|---------|
| 1 | 🔧 **`-Rsnc` → `-Rns` en Eliminar** | La opción `-c` junto a `-s` eliminaba dependencias de forma demasiado agresiva. Ahora usa `-Rns` (igual que el CLI). |
| 2 | 🌐 **Comprobación de red** | Nueva función `check_network()`: `Actualizar` y `Completo` verifican conexión a internet (curl a archlinux.org, timeout 5s) antes de operar. En `Completo`, si no hay red, aborta con mensaje claro. |
| 3 | 📦 **Limpieza de caché AUR** | Nueva función `clean_aur_cache()`: `Limpiar` y `Completo` ahora también limpian la caché de `yay -Sc` / `paru -Sc` (la que más espacio ocupa). En `Limpiar` se ejecuta después de paccache. |
| 4 | ❓ **Tildes corregidas** | Se corrigieron los textos de la interfaz que no llevaban tilde: "huérfanos", "caché", "término de búsqueda", "más", "está", "información", "actualización", "eliminación", "función", "ningún", "día", "encontró", "gráfica", "Versión", "últimas", "eliminarán", "operación", etc. |

### Notas de la revisión

- El código modificado fue verificado con **rust-analyzer (LSP): 0 diagnósticos** ✅
- El proyecto Cargo original (Cargo.toml + arcman-font.otf) no está en la carpeta, solo el `main.rs` y el binario compilado. Para recompilar, habría que restaurar el proyecto completo (ver sección de compilación).

---

## GPU y renderizado

### Hardware de Antonio

- **GPU activa:** NVIDIA GeForce RTX 4070 Ti SUPER (16 GB, Ada Lovelace) — display conectado por DisplayPort (2 monitores LG 4K)
- **GPU secundaria:** AMD Radeon integrada (Raphael, iGPU del Ryzen 9 7900)
- **Driver NVIDIA:** v610.43.03 (Vulkan 1.4.350, OpenGL 4.6)

### El problema

wgpu (el motor gráfico que usa iced) elige por defecto la GPU de **bajo consumo** (`LowPower`), que en este sistema es la **AMD integrada**. Eso causaba:

| Backend | Síntoma |
|---------|---------|
| OpenGL (`WGPU_BACKEND=gl`) | La app arrancaba, pero al cambiar de tema oscuro→claro aparecían **artefactos en blanco/negro** |
| Vulkan (`WGPU_BACKEND=vulkan`) | **Fallo de arranque**: `failed to import supplied dmabufs: Could not bind the given EGLImage to a CoglTexture2D` (error 7, protocolo Wayland) — Mutter no puede importar los buffers de la iGPU |

### La solución

Forzar la **GPU dedicada NVIDIA** con la variable de entorno `WGPU_POWER_PREF=high` en `main()`:

```rust
pub fn main() -> iced::Result {
    // wgpu por defecto elige LowPower (iGPU AMD integrada); con doble GPU
    // eso causa artefactos al cambiar tema y fallos de dmabuf en Wayland.
    // WGPU_POWER_PREF=high fuerza la GPU dedicada (RTX 4070 Ti SUPER).
    std::env::set_var("WGPU_POWER_PREF", "high");
    ...
}
```

### Verificación

- ✅ La app aparece en `nvidia-smi` usando la RTX 4070 Ti SUPER (37 MiB VRAM)
- ✅ Cambio de tema oscuro→claro **sin artefactos** (verificado por Antonio el 10/08/2026)
- ✅ Sin errores de dmabuf ni de renderizado en el log

> 📌 **Referencia:** [iced issue #3143](https://github.com/iced-rs/iced/issues/3143) — wgpu elige la iGPU por defecto en sistemas con doble GPU; la solución documentada es `WGPU_POWER_PREF=high`.

---

## Historial de cambios

| Fecha | Cambio |
|-------|--------|
| 05/07/2026 | Creación de la GUI con Iced y compilación del binario |
| 05/07/2026 | Instalación en `~/.local/bin` + iconos + acceso directo en GNOME |
| 10/08/2026 | Revisión completa: 4 mejoras aplicadas (ver tabla anterior) y documentación creada |
| 10/08/2026 | **Proyecto Cargo reconstruido** (Cargo.toml + src/main.rs + arcman-font.otf), compilación exitosa con iced 0.12 + tokio, binario nuevo instalado |
| 10/08/2026 | **Fix del cambio de tema** (artefactos blanco/negro): se fuerza la GPU NVIDIA con `WGPU_POWER_PREF=high` (ver sección "GPU y renderizado") |

---

## Compilación desde el código fuente

> ✅ **Proyecto Cargo reconstruido el 10/08/2026** — ahora se puede compilar sin problemas. El proyecto completo está en la carpeta `arcman-gui/`:

```
arcman-gui/
├── Cargo.toml           ← dependencias: iced 0.12 (feature tokio) + tokio 1
├── arcman-font.otf      ← fuente Nerd Font (DroidSansMono, 4,8 MB)
├── arcman.svg           ← icono vectorial
├── arcman.png           ← icono PNG
├── arcman-gui.desktop   ← acceso directo
└── src/
    └── main.rs          ← código fuente (1139 líneas)
```

### Cargo.toml

```toml
[package]
name = "arcman-gui"
version = "0.2.0"
edition = "2021"
description = "Gestor de paquetes para Arch Linux con interfaz gráfica (Iced)"
license = "MIT"

[dependencies]
iced = { version = "0.12", features = ["tokio"] }
tokio = { version = "1", features = ["rt-multi-thread"] }

[profile.release]
lto = true
strip = true
opt-level = 3
```

### Compilar e instalar

```bash
cd "/home/antonio/Documentos/dotfiles/utilidades rust/arcman-gui"
cargo build --release          # ~1 minuto, binario en target/release/
cp target/release/arcman-gui ~/.local/bin/arcman-gui   # instalar
```

> 📌 **Notas:**
> - La fuente `arcman-font.otf` es una copia de `DroidSansMNerdFont-Regular.otf` (la original no se conservó). Contiene los glifos de Nerd Font que usa la interfaz.
> - La versión de iced (0.12) se dedujo del binario original (`iced_core-0.12.3`, `iced_wgpu-0.12.1`, `iced_winit-0.12.2`) y tokio (1.52.3).
> - El binario nuevo compila con `lto` + `strip`, por eso pesa menos (15 MB vs 18 MB del original).

---

## Ubicación de los archivos

| Archivo | Ruta |
|---------|------|
| Binario instalado | `/home/antonio/.local/bin/arcman-gui` |
| Código fuente | `/home/antonio/Documentos/dotfiles/utilidades rust/arcman-gui/src/main.rs` |
| Proyecto Cargo | `/home/antonio/Documentos/dotfiles/utilidades rust/arcman-gui/Cargo.toml` |
| Fuente (Nerd Font) | `/home/antonio/Documentos/dotfiles/utilidades rust/arcman-gui/arcman-font.otf` |
| Acceso directo | `/home/antonio/.local/share/applications/arcman.desktop` |
| Iconos | `/home/antonio/.local/share/icons/hicolor/{scalable,32x32,48x48}/apps/arcman.*` |
| Documentación | `/home/antonio/Documentos/dotfiles/utilidades rust/arcman-gui/README-arcman-gui.md` |

---

> 📁 Este documento se creó el **10/08/2026** siguiendo el mismo estilo de documentación que las configuraciones de OpenCode (`~/Config/opencode/documentacion/`).
