# Configuración de Dropbox en el PC de Antonio

Fecha del arreglo: 07/09/2026

## Estado actual

- **Cliente**: oficial standalone de dropbox.com, binario en `~/.dropbox-dist` (versión 268.4.4124)
- **Estado**: Actualizado, vinculación persistente (`host.db` presente)
- **No pide login al reiniciar** (resuelto)

## Causa raíz del problema (por qué pedía login en cada reinicio)

Conflicto de versiones:
- El paquete `dropbox` 264.4.3421 (chaotic-aur) instalaba un launcher en `/opt/dropbox` y `/usr/bin/dropbox`
- Ese launcher chocaba con la auto-actualización a la 268 que el propio cliente se descargaba a `~/.dropbox-dist` (handover `/newerversion`)
- Al apagar con ese handover a medias, las bases de datos de `~/.dropbox` se corrompían
- El cliente arrancaba en modo `/corruptdball` (reconstrucción = arranque lentísimo)
- PERDÍA el `host.db` (archivo de vinculación del dispositivo) → pedía login cada vez

## Solución aplicada

1. Usar SOLO el binario oficial standalone de dropbox.com en `~/.dropbox-dist`
2. Eliminar por completo el paquete 264 (ya no se usaba)
3. Configurar autostart con el CLI oficial
4. Instalar `python-gpgme` (requisito obligatorio según ArchWiki)

## Archivos implicados

| Archivo | Ruta |
|---|---|
| Binario/cliente | `~/.dropbox-dist/` |
| CLI de gestión | `~/.local/bin/dropbox-cli` |
| Autostart | `~/.config/autostart/dropbox.desktop` |
| Estado/vinculación | `~/.dropbox/` (host.db, config.dbx) |

## Comandos de gestión

```bash
~/.local/bin/dropbox-cli status    # estado
~/.local/bin/dropbox-cli stop      # parar
~/.local/bin/dropbox-cli start     # arrancar
```

## Detalles técnicos

- **Paquete 264 eliminado con**: `pkexec pacman -Rdd --noconfirm dropbox` (usa `-Rdd` = nodeps, para no romper la dependencia de `nautilus-dropbox`)
- **nautilus-dropbox** 2026.05.06-1 (extensión Nautilus, AUR) se mantiene: es un `.so` independiente en `/usr/lib/nautilus/extensions-4/libnautilus-dropbox.so`
- **python-gpgme** 2.0.0-2.1 instalado
- **Servicios systemd**: `dropbox.service` (usuario) y `dropbox@.service` (sistema) ambos deshabilitados — no habilitar (causan el bucle de reinicios documentado en ArchWiki)
- **Autostart**: `Exec=/home/antonio/.local/bin/dropbox-cli start`, retardo 10 s (`X-GNOME-Autostart-Delay=10`)

## Descarga del cliente oficial (por si se necesita reinstalar)

```bash
# Binario
curl -L "https://www.dropbox.com/download?plat=lnx.x86_64" -o /tmp/dropbox-official.tar.gz
tar -xzf /tmp/dropbox-official.tar.gz -C ~/    # crea ~/.dropbox-dist

# CLI de gestión
curl -L "https://www.dropbox.com/download?dl=packages/dropbox.py" -o ~/.local/bin/dropbox-cli
chmod +x ~/.local/bin/dropbox-cli
```
