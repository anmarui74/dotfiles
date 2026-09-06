# Rclone Google Drive 🗂️

Configuración completa de rclone para montar Google Drive en Arch Linux + GNOME con backup automático.

## 📁 Estructura

| Ruta | Descripción |
|------|-------------|
| `~/Config/rclon/setup-rclone.sh` | Instalación desde cero y configuración completa |
| `~/Config/rclon/backup-rclone-weekly.sh` | Script de backup semanal de `rclone.conf` |
| `~/Config/rclon/rclone.conf` | Copia estática actualizada del config |
| `~/Config/rclon/rclone.conf.*` | Backups con fecha |
| `~/GoogleDrive` | Punto de montaje del Drive |

## 🚀 Uso

### Instalación inicial
```bash
bash ~/Config/rclon/setup-rclone.sh
```
El script:
* Instala rclone automáticamente si no está presente (Arch Linux, requiere sudo)
* Restaura `rclone.conf` desde el backup más reciente si falta
* Crea backup con fecha
* Configura remote `gdrive` con Client ID/Secret propios
* Crea servicio usuario `rclone-gdrive.service`
* Crea backup semanal automático con systemd timer

### Backup manual
```bash
~/Config/rclon/backup-rclone-weekly.sh
```

### Servicios
```bash
systemctl --user status rclone-gdrive.service
systemctl --user status rclone-backup.timer
```

## 🔐 Credenciales

Remote `gdrive` usa Client ID propio de Google Cloud para evitar el retiro del client_id compartido de rclone en 2026.

### Obtener Client ID y Secret propios

1. Abre https://console.cloud.google.com/
2. Crea proyecto → `rclone-drive`
3. **APIs y servicios → Biblioteca** → Habilita *Google Drive API*
4. **APIs y servicios → Pantalla de consentimiento de OAuth**
   * Tipo: Externo
   * Añade usuarios de prueba: `anmarui74@gmail.com`
5. **APIs y servicios → Credenciales → + Crear credenciales → ID de cliente de OAuth**
   * Tipo: Aplicación de escritorio
   * Copia **Client ID** y **Client Secret**
6. Actualiza el script `setup-rclone.sh` con los nuevos valores y ejecuta de nuevo

> Guarda las credenciales en un lugar seguro. Nunca las compartas.

**Ubicación segura en este sistema**
Las credenciales están guardadas en `~/Config/rclon/credenciales.txt` con permisos 600. No incluir en el README para evitar exposición.

## 🗓️ Backup automático

* Frecuencia: cada domingo 03:00
* Retención: 30 días
* Ubicación: `~/Config/rclon/`

## 🛠️ Comandos rápidos

| Acción | Comando |
|--------|---------|
| Instalar / reconfigurar todo | `bash ~/Config/rclon/setup-rclone.sh` |
| Estado del montaje | `systemctl --user status rclone-gdrive.service` |
| Iniciar montaje | `systemctl --user start rclone-gdrive.service` |
| Parar montaje | `systemctl --user stop rclone-gdrive.service` |
| Backup manual | `~/Config/rclon/backup-rclone-weekly.sh` |
| Estado del timer semanal | `systemctl --user status rclone-backup.timer` |
| Listar próximos timers | `systemctl --user list-timers` |
| Ver contenido montado | `ls ~/GoogleDrive` |
| Restaurar config desde backup | `cp ~/Config/rclon/rclone.conf ~/.config/rclone/rclone.conf && systemctl --user restart rclone-gdrive.service` |

## 📝 Notas

* No necesita paquetes adicionales más allá de rclone
* Requiere `user_allow_other` en `/etc/fuse.conf`
* Montaje con `--vfs-cache-mode writes`
* Servicio usuario, sin necesidad de root
