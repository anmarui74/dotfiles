# 🦀 arcman — Gestor de paquetes de Arch Linux en Rust

> **Usuario:** Antonio 🧑‍💻
> **Ubicación:** Pechina, Almería, España 📍
> **Fecha creación:** 04/07/2026 (última actualización: 10/08/2026)
> **Binario instalado:** `/usr/local/bin/arcman`

---

## Índice

1. [¿Qué es arcman?](#qué-es-arcman)
2. [Requisitos y dependencias](#requisitos-y-dependencias)
3. [Instalación](#instalación)
4. [Modo de uso](#modo-de-uso)
5. [Comandos](#comandos)
6. [Menú interactivo](#menú-interactivo)
7. [Flujo interno del programa](#flujo-interno-del-programa)
8. [Seguridad](#seguridad)
9. [Mejoras aplicadas](#mejoras-aplicadas)
10. [Historial de cambios](#historial-de-cambios)
11. [Compilación desde el código fuente](#compilación-desde-el-código-fuente)

---

## ¿Qué es arcman?

`arcman` es una utilidad escrita en **Rust puro** (sin dependencias externas, solo la librería estándar) que gestiona el sistema de paquetes de **Arch Linux y sus derivados** (CachyOS, EndeavourOS, Manjaro...). Combina:

- 📦 El gestor base **pacman**
- 🚀 Los asistentes AUR **yay** y **paru**
- 🧹 Herramientas de limpieza como **paccache** (pacman-contrib)

Su propósito es ofrecer una interfaz **sencilla, interactiva y con colores** para las tareas de mantenimiento más habituales: actualizar, instalar, eliminar, limpiar caché y eliminar paquetes huérfanos — sin tener que recordar las opciones de pacman.

Se ejecuta desde la terminal con el comando `arcman` y funciona en cualquier directorio (está instalado en `/usr/local/bin`).

---

## Requisitos y dependencias

| Dependencia | ¿Para qué? | ¿Obligatoria? |
|-------------|-----------|---------------|
| `pacman` | Gestor base de paquetes | ✅ Sí |
| `yay` | Actualizar/instalar desde repositorios + AUR | ⚠️ Recomendada (si no, usa `paru`) |
| `paru` | Alternativa a yay para AUR | ⚠️ Alternativa |
| `pacman-contrib` | Proporciona `paccache` (limpieza de caché) | ⚠️ Recomendada |
| `curl` | Comprobación de conexión a internet | ✅ Sí |
| `sudo` | Elevar permisos para operaciones del sistema | ✅ Sí |

> 💡 **Detección automática:** arcman detecta en este orden: `yay` → `paru` → `pacman`. Usará el primero que encuentre en el PATH.

---

## Instalación

### Desde el binario compilado

```bash
# El binario ya compilado se copia a la carpeta de binarios del sistema
sudo cp arcman /usr/local/bin/arcman
sudo chmod 755 /usr/local/bin/arcman

# Verificar
arcman --help
```

### Compilando desde el código fuente

```bash
# Con el archivo arcman.rs en la carpeta actual
rustc --edition 2021 arcman.rs -o /usr/local/bin/arcman
```

---

## Modo de uso

```
arcman [opción]
```

- **Con argumentos:** ejecuta la operación directamente
- **Sin argumentos:** abre un **menú interactivo** con todas las opciones

---

## Comandos

### `update`, `-u` — Actualizar el sistema

```
arcman update
```

1. Detecta el gestor de paquetes (yay/paru/pacman)
2. Pide confirmación: *"¿Deseas actualizar todos los paquetes?"*
3. **Comprueba la conexión a internet** (curl a archlinux.org)
4. Ejecuta la actualización con `sudo`:
   - `sudo yay -Syu` (si hay yay)
   - `sudo paru -Syu` (si hay paru)
   - `sudo pacman -Syu` (solo pacman)

> 🔄 Actualiza tanto los paquetes oficiales como los del AUR (con yay/paru).

---

### `search <paquete>` — Buscar un paquete

```
arcman search neovim
```

1. Busca en repositorios con `-Ss` (el gestor detectado):
   - `yay -Ss neovim`
   - `paru -Ss neovim`
   - `pacman -Ss neovim`
2. Muestra los resultados en pantalla

> Si se ejecuta `arcman search` **sin argumentos**, entra en modo interactivo pidiendo el nombre del paquete.

---

### `install <paquete...>` — Instalar paquetes

```
arcman install firefox vim
```

1. Acepta **uno o varios paquetes** (separados por espacio)
2. Pide confirmación: *"¿Instalar 'firefox vim'?"*
3. Ejecuta con `sudo`:
   - Con yay/paru: `sudo yay -S firefox vim` (busca en oficial + AUR)
   - Solo pacman: `sudo pacman -S firefox vim`

> Si se ejecuta `arcman install` **sin argumentos**, pide los nombres interactivamente.

---

### `remove <paquete...>` — Eliminar paquetes

```
arcman remove firefox
```

1. Acepta **uno o varios paquetes**
2. Pide confirmación: *"¿Eliminar 'firefox'?"*
3. Ejecuta con `sudo`: `sudo pacman -Rns <paquete>`

> 🔧 **Nota:** usa `-Rns` (elimina el paquete, sus dependencias no usadas y archivos de configuración). Desde la versión del 10/08/2026 ya no se usa `-Rsnc`, que era demasiado agresivo.

---

### `orphans` — Paquetes huérfanos

```
arcman orphans
```

1. Busca paquetes huérfanos: `pacman -Qtdq` (dependencias que ya no usa ningún paquete)
2. Si no hay: muestra *"No hay paquetes huérfanos"*
3. Si hay: **los lista en rojo** y pide confirmación para eliminarlos
4. Si confirmas: `sudo pacman -Rns <huérfanos...>`

> 🛡️ Siempre pide confirmación antes de eliminar.

---

### `clean` — Limpiar caché

```
arcman clean
```

1. Si hay `paccache`: pregunta *"¿Limpiar caché (manteniendo 3 versiones)?"* y ejecuta `sudo paccache -r`
2. Si no hay `paccache`: avisa y ofrece `sudo pacman -Sc` como alternativa
3. **Nuevo (10/08/2026):** si hay `yay`, pregunta *"¿Limpiar también la caché de yay (AUR)?"* y ejecuta `sudo yay -Sc`
4. Si hay `paru`: pregunta *"¿Limpiar también la caché de paru (AUR)?"* y ejecuta `sudo paru -Sc`

> 🧹 La caché de AUR (yay/paru) suele ocupar más espacio que la de pacman, por eso ahora se limpia también.

---

### `full` — Mantenimiento completo

```
arcman full
```

Realiza **3 operaciones en cadena**:

1. **Actualizar:** `sudo yay -Syu` (o paru/pacman)
2. **Limpiar caché:** `sudo paccache -r` (manteniendo 3 versiones)
3. **Limpiar caché AUR:** `sudo yay -Sc` (o paru) — nuevo
4. **Eliminar huérfanos:** lista y pide confirmación antes de `sudo pacman -Rns`

Antes de empezar:
- Pide confirmación general
- **Comprueba la conexión a internet** (nuevo)

> 🛡️ Desde el 10/08/2026, la eliminación de huérfanos en `full` **pide confirmación** (antes se hacía automáticamente).

---

### `status`, `-s` — Estado del sistema

```
arcman status
```

Muestra:

| Dato | Fuente |
|------|--------|
| Gestor de paquetes principal | Detección automática |
| ¿yay instalado? | Búsqueda en PATH |
| ¿paru instalado? | Búsqueda en PATH |
| ¿paccache instalado? | Búsqueda en PATH |
| Actualizaciones disponibles | `pacman -Qu` |

Lista las actualizaciones pendientes en formato `paquete: versión_actual → versión_nueva`.

---

### `help`, `-h`, `--help` — Ayuda

```
arcman help
```

Muestra la ayuda completa con todas las opciones y ejemplos.

---

## Menú interactivo

Al ejecutar `arcman` **sin argumentos** se abre el menú:

```
============================================
  Arch Linux — Gestor de paquetes (Rust)
============================================
    1. Comprobar actualizaciones
    2. Actualizar el sistema
    3. Buscar un paquete
    4. Instalar un paquete
    5. Eliminar un paquete
    6. Limpiar sistema (update + clean + orphans)
    7. Ayuda
    8. Salir

  Elige una opción [1-8]:
```

Después de cada operación vuelve al menú (o sale con la opción 8).

---

## Flujo interno del programa

```
arcman (sin args)          arcman <comando>
      │                          │
      ▼                          ▼
  check_root()              check_root()
  (rechaza si eres root)    (rechaza si eres root)
      │                          │
      ▼                          ▼
     menú ──────────► comando específico
      │                    (do_update, do_clean...)
      │                          │
      │                          ▼
      │                  detect_pkg_manager()
      │                  (yay → paru → pacman)
      │                          │
      │                          ▼
      │                  confirm() / check_network()
      │                          │
      │                          ▼
      │                  run_sudo([...]) con sudo
      │
      ▼
   (vuelve al menú)
```

### Funciones clave

| Función | Propósito |
|---------|-----------|
| `check_root()` | Rechaza ejecutar como root/sudo (el programa pide permisos él mismo) |
| `detect_pkg_manager()` | Devuelve `Yay`, `Paru`, `Pacman` o `None` según lo que haya en el PATH |
| `which(name)` | Comprueba si un binario existe en el PATH |
| `run_sudo(args)` | Ejecuta un comando con `sudo` (entrada/salida heredadas) |
| `run_cmd(args)` | Ejecuta un comando y captura su salida (para `status`) |
| `check_network()` | Comprueba conexión a internet con `curl` (5s de timeout) |
| `confirm(msg)` | Pregunta sí/no (por defecto **No**). Acepta `s`/`S` |
| `clear()` / `pause()` | Limpia pantalla / espera Enter |

---

## Seguridad

- 🚫 **No se ejecuta como root:** `check_root()` aborta si se lanza con sudo o como root
- ✅ **Permisos bajo demanda:** cada operación usa `sudo` internamente (solo cuando es necesario)
- ❓ **Confirmación en todo:** ninguna operación destructiva se ejecuta sin confirmar (s/N)
- 🧹 **Eliminación segura:** `-Rns` (sin la `-c` agresiva desde el 10/08/2026)
- 🌐 **Comprobación de red:** antes de actualizar evita fallos crípticos de pacman sin internet
- 🛡️ **Huérfanos con confirmación:** incluso dentro de `full`

> ⚠️ **Nota:** arcman usa `sudo` (no `pkexec`) porque es una herramienta de terminal interactiva que ejecuta el propio usuario, que introduce la contraseña cómodamente en la consola. `pkexec` se reserva para las herramientas de OpenCode que requieren ventana gráfica.

---

## Mejoras aplicadas

### 10/08/2026 — Revisión y mejoras (con asistencia de IA)

| # | Mejora | Detalle |
|---|--------|---------|
| 1 | 🧹 **Funciones muertas eliminadas** | Se quitaron `print_bold`, `print_green`, `print_yellow` y `print_red` (definidas pero nunca usadas). Queda `print_cyan`, que sí se usa en `show_status`. |
| 2 | 🔧 **`-Rsnc` → `-Rns`** | La opción `-c` de pacman junto a `-s` eliminaba dependencias de forma demasiado agresiva. Ahora `remove` usa `-Rns` (más seguro). |
| 3 | 🛡️ **Confirmación de huérfanos en `full`** | Antes `do_full()` eliminaba los huérfanos automáticamente. Ahora los lista y pide confirmación (coherente con `do_orphans()`). |
| 4 | 📦 **Limpieza de caché AUR** | Nueva función `clean_aur_cache()`: `clean` y `full` ahora también limpian la caché de `yay -Sc` / `paru -Sc`, que suele ser la que más espacio ocupa. |
| 5 | 🚨 **Errores más claros** | `run_sudo()` ahora muestra el **código de salida real** del comando si falla (antes decía solo "El comando falló"). |
| 6 | 🌐 **Comprobación de red** | Nueva función `check_network()`: `update` y `full` verifican conexión a internet (curl a archlinux.org, timeout 5s) antes de empezar. |
| 7 | ❓ **Signos de interrogación corregidos** | Se corrigieron todas las confirmaciones para que muestren `¿...?` correctamente. De paso se arregló un bug heredado: antes la función `confirm()` añadía otro `¿` al principio, produciendo `¿¿...?` en pantalla. |

### Resultado de las verificaciones (10/08/2026)

- ✅ **rustc 1.96.1**: compila sin errores ni warnings
- ✅ **rust-analyzer (LSP)**: 0 diagnósticos — código limpio
- ✅ **Pruebas funcionales**: `status`, `help` y gestión de opciones desconocidas correctas
- ✅ **Binario sustituido** en `/usr/local/bin/arcman` (con `pkexec`)

---

## Historial de cambios

| Fecha | Cambio |
|-------|--------|
| 03/07/2026 | Creación del código fuente `arcman.rs` |
| 04/07/2026 | Compilación del binario y primera instalación en `/usr/local/bin` |
| 10/08/2026 | Revisión completa: 7 mejoras aplicadas (ver tabla anterior) y documentación creada |

---

## Compilación desde el código fuente

```bash
# Requisito: rustc instalado
rustc --version

# Compilar (salida a /tmp para probar)
rustc --edition 2021 arcman.rs -o /tmp/arcman-test

# Probar
/tmp/arcman-test status

# Instalar
sudo cp /tmp/arcman-test /usr/local/bin/arcman
sudo chmod 755 /usr/local/bin/arcman
```

---

## Ubicación de los archivos

| Archivo | Ruta |
|---------|------|
| Binario instalado | `/usr/local/bin/arcman` |
| Código fuente | `/home/antonio/Documentos/dotfiles/utilidades rust/arcman/arcman.rs` |
| Binario del repositorio | `/home/antonio/Documentos/dotfiles/utilidades rust/arcman/arcman` |
| Documentación | `/home/antonio/Documentos/dotfiles/utilidades rust/arcman/README-arcman.md` |

---

> 📁 Este documento se creó el **10/08/2026** siguiendo el mismo estilo de documentación que las configuraciones de OpenCode (`~/Config/opencode/documentacion/`).
