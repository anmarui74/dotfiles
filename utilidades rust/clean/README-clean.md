# 🧹 clean — Limpiador de sistema para Arch Linux en Rust

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Operativo | 05/09/2026 | Antonio |

> Utilidad CLI en Rust para mantenimiento básico de Arch Linux: detección y eliminación de paquetes huérfanos y limpieza segura de caché de pacman.

---

## 📑 Índice

1. [¿Qué es clean?](#qué-es-clean)
2. [Requisitos y dependencias](#requisitos-y-dependencias)
3. [Instalación](#instalación)
4. [Modo de uso](#modo-de-uso)
5. [Flujo de limpieza](#flujo-de-limpieza)
6. [Seguridad](#seguridad)
7. [Compilación desde el código fuente](#compilación-desde-el-código-fuente)
8. [Ubicación de los archivos](#ubicación-de-los-archivos)

---

## ¿Qué es clean?

`clean` es una utilidad escrita en **Rust puro** (solo librería estándar) para Arch Linux y derivados que realiza mantenimiento básico del sistema de forma interactiva y segura:

- 🔍 Detecta **paquetes huérfanos** con `pacman -Qdtq`
- 🗑️ Elimina los huérfanos con `pacman -Rns` tras confirmación del usuario
- 🧹 Limpia la **caché de paquetes no instalados** con `pacman -Sc` tras confirmación
- 🛡️ Verifica privilegios de root antes de ejecutar cualquier operación

Se ejecuta desde la terminal con el comando `clean` y pide confirmación `s/N` antes de cada acción destructiva.

---

## Requisitos y dependencias

| Dependencia | ¿Para qué? | ¿Obligatoria? |
|-------------|-----------|---------------|
| `pacman` | Detección y eliminación de huérfanos, limpieza de caché | ✅ Sí |
| `sudo` / root | Ejecutar operaciones del sistema | ✅ Sí |
| `rustc` | Compilar desde el código fuente | ⚠️ Solo para compilar |

> 💡 El programa comprueba si se ejecuta como root leyendo `/proc/self/status`. Si no lo es, muestra error y recomienda `sudo clean`.

---

## Instalación

### Desde el binario compilado

```bash
# Copiar binario a ruta del PATH
sudo cp clean /usr/local/bin/clean
sudo chmod 755 /usr/local/bin/clean

# Verificar
clean --help
```

### Compilando desde el código fuente

```bash
# Con clean.rs en la carpeta actual
rustc --edition 2021 clean.rs -o clean

# Instalar opcionalmente
sudo mv clean /usr/local/bin/clean
sudo chmod 755 /usr/local/bin/clean
```

---

## Modo de uso

```
sudo clean
```

El programa siempre se ejecuta con privilegios de administrador. Al lanzarlo:

1. Verifica root
2. Busca paquetes huérfanos
3. Pregunta si desea eliminarlos con sus configuraciones
4. Pregunta si desea limpiar la caché de paquetes no instalados con `pacman -Sc`
5. Muestra resumen final

No admite argumentos; el flujo es fijo e interactivo.

---

## Flujo de limpieza

### 1. Verificación de root
- Lee UID real desde `/proc/self/status`
- Si UID != 0, muestra error y termina

### 2. Paquetes huérfanos
- Ejecuta `pacman -Qdtq`
- Si no hay huérfanos → mensaje informativo
- Si hay huérfanos → los lista y pide confirmación
- Confirmado → ejecuta `pacman -Rns <paquetes>`

### 3. Limpieza de caché
- Pregunta confirmación para `pacman -Sc`
- `pacman -Sc` elimina solo paquetes de caché que ya no están instalados
- Se evita `-Scc` para no borrar la caché de paquetes activos

---

## Seguridad

- 🚫 **Requiere root:** aborta si no se ejecuta como administrador
- ✅ **Confirmación en todo:** cada acción destructiva pide `s/N`
- 🛡️ **Eliminación segura:** usa `pacman -Rns` (elimina paquete, dependencias no usadas y configuraciones)
- 🧹 **Caché segura:** usa `-Sc` en lugar de `-Scc`

---

## Compilación desde el código fuente

```bash
rustc --version
rustc --edition 2021 clean.rs -o /tmp/clean-test
/tmp/clean-test
sudo cp /tmp/clean-test /usr/local/bin/clean
sudo chmod 755 /usr/local/bin/clean
```

---

## Ubicación de los archivos

| Archivo | Ruta |
|---------|------|
| Código fuente | `/home/antonio/Config/utilidades rust/clean/clean.rs` |
| Binario compilado | `/home/antonio/Config/utilidades rust/clean/clean` |
| Documentación | `/home/antonio/Config/utilidades rust/clean/README-clean.md` |

---

> 📁 Documentación en formato OpenCode. Creado el 05/09/2026.
