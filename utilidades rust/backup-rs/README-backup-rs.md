# 🗄️ Proyecto backup-rs — Backup automatizado en Rust

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Operativo | 18/08/2026 | Antonio |

> Herramienta CLI en **Rust** para Arch Linux (CachyOS) que respalda automáticamente los directorios personales
> (`Config`, `Documentos`, `Descargas`, `Imágenes`, `Vídeos`, incluidos archivos
> ocultos) en un disco SSD (Crucial) con espejo siempre al día + snapshots
> **incrementales** (hardlinks) para restauración.

---

## 📑 Índice

1. [Descripción general](#descripción-general)
2. [Por qué Rust y no Python](#por-qué-rust-y-no-python)
3. [Estructura del proyecto](#estructura-del-proyecto)
4. [Cargo.toml (dependencias)](#cargotoml)
5. [src/main.rs (CLI y despacho)](#srcmainrs)
6. [src/config.rs (configuración TOML)](#srcconfigrs)
7. [src/backup.rs (motor de copia)](#srcbackuprs)
8. [src/watcher.rs (vigilancia de cambios)](#srcwatcherrs)
9. [Archivo de configuración](#archivo-de-configuración)
10. [install.sh (instalador)](#installsh)
11. [Servicios systemd](#servicios-systemd)
12. [Flujo completo](#flujo-completo)
13. [Comandos útiles](#comandos-útiles)

---

## Descripción general

**backup-rs** es un binario compilado en Rust que hace copias de seguridad de los
directorios personales de Antonio hacia **dos discos**:

| Disco | Uso | Comportamiento |
|-------|-----|----------------|
| **Crucial** (SSD 1 TB, btrfs) | Backup versionado incremental | Snapshots con hardlinks + espejo `actual/` |
| **SEAGATE** (HDD 4 TB, NTFS) | Espejo plano "machacar" | Copia, sobrescribe y borra según el home (requiere root) |
| **MyCloud** (WD, SMB) | Espejo nube "machacar" | Copia, sobrescribe y borra según el home (**sin root**, vía CIFS + rsync) |

Las **fuentes** son: `Config`, `Documentos`, `Descargas`, `Imágenes`, `Vídeos`,
`Cursos informatica`, `Varios Linux`, `modelos_ia`, `start-lmstudio.sh` y
`system-info.sh` (todos con archivos ocultos incluidos).

Tiene **dos modos complementarios**:

| Modo | Comando | Qué hace |
|------|---------|----------|
| **Backup manual (principal)** | `backup once` | Snapshot incremental del Crucial (sin contraseña) + SEAGATE (pide sudo una vez) + NUBE (sin root) |
| **Actualizar espejos** | `backup mirror` | Sincroniza los espejos machacados: SEAGATE (pide sudo) y NUBE antonio/public (sin root) |
| **Daemon (opcional)** | `backup run` | Sincroniza el espejo `actual/` del Crucial, la NUBE, y vigila cambios en tiempo real (queda corriendo) |

> 🏠 **Uso recomendado (sin daemon):** el servicio systemd está **deshabilitado**.
> No hay vigilancia automática en segundo plano. Los backups se hacen **manualmente**
> con `backup once` (todo) o `backup mirror` (solo SEAGATE) cuando quieras.

> 🔌 **Montaje automático:** tanto `backup once` como `backup run` intentan montar
> automáticamente los discos de destino si están desmontados:
> - El **Crucial** se monta con `udisksctl` **sin contraseña** gracias a una regla
>   polkit **específica solo para ese disco** (`/dev/sda1`). Así queda como sesión
>   de usuario y **Nautilus puede montarlo/desmontarlo sin pedir permisos**.
> - El **SEAGATE** NO tiene regla polkit (no se da privilegio a antonio). Su montaje
>   y copia requieren **`sudo`**.

> 🔒 **Elevación a root (solo SEAGATE):** el espejo plano vive en
> `/SEAGATE/Linux`, que es propiedad de **root**. Cuando `backup once` llega al
> SEAGATE, eleva **solo esa parte** con `sudo backup _mirror-only` (pide la
> contraseña de `sudo` una sola vez, NUNCA pkexec). El proceso root monta y copia
> el SEAGATE. El **Crucial nunca se copia como root**: su snapshot se hace siempre
> como `antonio` antes de la elevación.

> 🖥️ **Daemon (`backup run`, opcional):** si se ejecuta, corre como **`antonio`**
> (no root), gestiona el Crucial (sin privilegios) y **omite el SEAGATE** (requiere
> root y no tiene terminal para sudo). Actualmente **el servicio systemd está
> deshabilitado**: no corre en segundo plano salvo que lo lances manualmente.

### Arquitectura

```
backup once  →  Backup/<YYYY-MM-DD_HH-MM-SS>/   (snapshot de restauración, Crucial)
             +  SEAGATE/Linux                    (espejo machacado, con sudo)
backup run   →  Backup/actual/                  (espejo siempre al día, opcional)
                 └── + vigilancia en tiempo real con notify (solo si se lanza)
```

- **Snapshot (`backup once`):** punto de restauración **incremental** con timestamp;
  los archivos que no cambian se comparten por **hardlinks** con el snapshot anterior
  (no duplican espacio), solo se copian físicamente los archivos nuevos o modificados
- **Espejo `actual/` (`backup run`):** refleja el estado actual de los orígenes.
  Solo existe si se lanza el daemon manualmente (el servicio está deshabilitado)
- **Limpieza:** solo se aplica a snapshots (`max_versions`); el espejo nunca se borra

### Espejos planos (machacar) — opcional

Además del backup versionado en el Crucial, se pueden definir **espejos planos**
(sección `[[mirrors]]` de la config) con comportamiento **machacar**:

| Acción en origen | Resultado en el espejo |
|------------------|------------------------|
| Archivo nuevo | Se copia |
| Archivo modificado | Se sobrescribe (machaca) |
| Archivo eliminado | Se borra del espejo |

- Pensado para discos NTFS (p. ej. el HDD **SEAGATE**) que no soportan hardlinks fiables
- Compara por **tamaño** (fiable en NTFS)
- **Requiere root** (el destino `/SEAGATE/Linux` es de root): `backup once`/`backup mirror`
  lo elevan con `sudo` una sola vez.
- El **daemon lo omite** (si se ejecuta, corre como antonio y no puede escribir en root);
  por eso el SEAGATE se sincroniza **manualmente** con `backup once` o `backup mirror`.
- Ejemplo: `SEAGATE/Linux` mantiene una copia machacada de las 10 fuentes

```toml
[[mirrors]]
name = "SEAGATE"
destination = "/run/media/antonio/SEAGATE/Linux"
```

> ⚠️ **Aviso:** el espejo plano **machaca y borra** — lo que se elimine del origen
> desaparece del espejo. No guarda historial de versiones.

### Espejos de red (nube SMB) — opcional, sin root

Además de los espejos locales (SEAGATE), se pueden definir **espejos de red**
apuntando a shares **SMB/CIFS** (p. ej. el WD My Cloud `mycloud-eudvfr.local`).
Usan la **misma dinámica machacar** que el SEAGATE pero **sin root**:

| Característica | Valor |
|----------------|-------|
| Montaje | CIFS del kernel vía fstab `users` + `x-systemd.automount` (sin root) |
| Motor de copia | **`rsync`** (rápido y fiable sobre SMB; evita chmod/mkstemp de GVFS) |
| Comportamiento | Copia, sobrescribe y borra según el origen (machaca) |
| Daemon | Se sincroniza también en el daemon (no requiere root) |

La clave del rendimiento está en el **montaje CIFS del kernel**: GVFS/SMB (el que
usa Nautilus) va 2-5x más lento y `rsync` falla sobre él con errores de
`Operation not supported` (chmod). Con `mount.cifs` en fstab (opción `users`) se
monta/desmonta **sin root** y `rsync` funciona perfecto.

**Configuración previa (una sola vez, con `pkexec`):**

1. Añadir los puntos de montaje al **fstab**:
   ```
   //mycloud-eudvfr.local/antonio /home/antonio/MyCloud/antonio cifs credentials=/home/antonio/.config/backup-rs/smb-antonio.credentials,uid=1000,gid=1000,file_mode=0664,dir_mode=0775,iocharset=utf8,vers=3.0,noauto,x-systemd.automount,nofail,users,_netdev 0 0
   //mycloud-eudvfr.local/public /home/antonio/MyCloud/public cifs guest,uid=1000,gid=1000,file_mode=0664,dir_mode=0775,iocharset=utf8,vers=3.0,noauto,x-systemd.automount,nofail,users,_netdev 0 0
   ```
2. Crear el archivo de credenciales (solo si el share pide usuario/contraseña):
   ```
   # ~/.config/backup-rs/smb-antonio.credentials  (permisos 600)
   username=antonio
   password=XXXXXXXX
   domain=WORKGROUP
   ```
3. Recargar systemd y activar los automounts:
   ```
   systemctl daemon-reload
   systemctl start home-antonio-MyCloud-antonio.automount home-antonio-MyCloud-public.automount
   ```

**Configuración del espejo nube:**

```toml
[[mirrors]]
name = "NUBE-antonio"
destination = "/home/antonio/MyCloud/antonio/Linux"
uri = "smb://mycloud-eudvfr.local/antonio/Linux"

[[mirrors]]
name = "NUBE-public"
destination = "/home/antonio/MyCloud/public/Linux"
uri = "smb://mycloud-eudvfr.local/public/Linux"
```

- `destination`: punto de montaje CIFS local (con automount se monta al acceder)
- `uri`: share SMB que se monta con GVFS como **fallback** si el punto CIFS no existe

Los mirrors nube se sincronizan con `backup once`/`backup mirror`/`backup run` y
**nunca requieren sudo**. Si el punto CIFS está montado, `backup-rs` usa `rsync`
directamente; si no, intenta GVFS (`gio mount`) como respaldo.

---

## Por qué Rust y no Python

| Criterio | Rust | Python |
|----------|------|--------|
| Rendimiento al copiar miles de archivos | ⚡ Muy rápido (binario nativo) | 🐢 Más lento (interprete) |
| Dependencias en ejecución | Ninguna (estático) | Requiere entorno + librerías |
| Observador de archivos | `notify` (maduro, eficiente) | `watchdog` (válido pero más lento) |
| Seguridad de memoria | Garantizada por el compilador | Errores silenciosos comunes |
| Distribución | Un solo binario | Script + requirements |

Decisión: **Rust** para un daemon ligero y rápido que copia archivos de forma continua.

---

## Estructura del proyecto

```
~/backup-rs/
├── Cargo.toml              # Definición del binario "backup" + dependencias
├── Cargo.lock              # Versiones de dependencias bloqueadas
├── config.example.toml     # Plantilla de configuración documentada
├── install.sh              # Instalador (root): compila, monta SSD, crea systemd
├── README.md               # Este documento
├── src/
│   ├── main.rs             # CLI (clap) + despacho + status/list/restore
│   ├── config.rs           # Estructuras Config/serde + rutas del destino
│   ├── backup.rs           # Motor de copia (snapshot y sync al espejo)
│   └── watcher.rs          # Daemon de vigilancia (notify + debounce)
└── target/release/backup   # Binario compilado en release (~5,6 MB)
```

---

## Cargo.toml

**Archivo:** `~/backup-rs/Cargo.toml`

### Definición del binario

```toml
[package]
name = "backup-rs"
version = "1.0.0"
edition = "2021"
description = "Backup automatizado versionado para Arch Linux con watching de archivos"
license = "MIT"

[[bin]]
name = "backup"        # ← el ejecutable final se llama "backup"
path = "src/main.rs"
```

> ⚠️ **Detalle:** el paquete es `backup-rs` pero el binario se llama `backup`.
> Gracias al bloque `[[bin]]`, al compilar se genera `target/release/backup`.

### Dependencias

```toml
[dependencies]
clap = { version = "4.5", features = ["derive", "env"] }
notify = { version = "6.1", features = ["crossbeam-channel"] }
walkdir = "2.5"
chrono = { version = "0.4", features = ["serde"] }
serde = { version = "1.0", features = ["derive"] }
toml = "1.0"
anyhow = "1.0"
tokio = { version = "1.40", features = ["full"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
dirs = "5.0"
indicatif = "0.17"
humantime = "2.1"
regex = "1.10"
```

| Crate | Uso |
|-------|-----|
| `clap` | CLI con derive (subcomandos, flags, ayuda) |
| `notify` | Observador de cambios en el sistema de archivos |
| `walkdir` | Recorrido recursivo de directorios |
| `chrono` | Marcas de tiempo de las versiones |
| `serde` + `toml` | Lectura/escritura de la configuración |
| `tokio` | Runtime asíncrono del daemon |
| `anyhow` | Errores con contexto |
| `indicatif` | Barra de progreso en consola |
| `regex` | Patrones de exclusión de archivos |
| `dirs` | Rutas de home / XDG |

---

## src/main.rs

**Archivo:** `~/backup-rs/src/main.rs` (617 líneas)

### Imports y módulos

```rust
use anyhow::Result;
use clap::{Parser, Subcommand};
use std::path::{Path, PathBuf};
use tokio::signal;
use tokio::sync::mpsc;
use tracing_subscriber::{EnvFilter, FmtSubscriber};

use crate::config::Config;
use crate::backup::BackupEngine;
use crate::watcher::FileWatcher;

mod config;
mod backup;
mod watcher;
```

### Definición del CLI

```rust
#[derive(Parser)]
#[command(name = "backup")]
#[command(about = "Backup automatizado versionado para Arch Linux", long_about = None)]
#[command(version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    #[arg(short, long, global = true, help = "Ruta al archivo de configuración")]
    config: Option<PathBuf>,

    #[arg(short, long, global = true, help = "Activar logs detallados")]
    verbose: bool,
}

#[derive(Subcommand)]
enum Commands {
    #[command(about = "Crear archivo de configuración por defecto")]
    Init {
        #[arg(short, long, help = "Forzar sobrescritura")]
        force: bool,
    },

    #[command(about = "Ejecutar backup una sola vez (one-shot)")]
    Once,

    #[command(about = "Ejecutar backup y mantener vigilando cambios (daemon)")]
    Run,

    #[command(about = "Mostrar estado y versiones disponibles")]
    Status,

    #[command(about = "Restaurar una versión específica")]
    Restore {
        #[arg(help = "Timestamp de la versión a restaurar (ej: 2024-01-15_14-30-00)")]
        version: String,

        #[arg(short, long, help = "Directorio destino (por defecto: ubicaciones originales)")]
        target: Option<PathBuf>,

        #[arg(short, long, help = "Forzar sobrescritura")]
        force: bool,
    },

    #[command(about = "Listar todas las versiones disponibles")]
    List,
}
```

### Despacho principal

```rust
#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    init_logging(cli.verbose);

    let config = if let Some(path) = cli.config {
        load_config_from_path(&path)?
    } else {
        Config::load()?                    // ~/.config/backup-rs/config.toml
    };

    match cli.command {
        Commands::Init { force } => {
            init_config(&Config::default(), force).await?;
        }
        Commands::Once => {
            run_backup_once(&config).await?;
        }
        Commands::Run => {
            run_daemon(&config).await?;
        }
        Commands::Status => {
            show_status(&config).await?;
        }
        Commands::Restore { version, target, force } => {
            restore_version(&config, &version, target.as_deref(), force).await?;
        }
        Commands::List => {
            list_versions(&config).await?;
        }
    }
    Ok(())
}
```

> Nota: `Init` siempre genera la config con `Config::default()`, sin cargar la
> existente (así no arrastra rutas viejas al regenerar).

### Funciones auxiliares del CLI

```rust
fn init_logging(verbose: bool) {
    let filter = if verbose { EnvFilter::new("debug") } else { EnvFilter::new("info") };
    FmtSubscriber::builder()
        .with_env_filter(filter)
        .with_target(false)
        .compact()
        .init();
}

fn load_config_from_path(path: &PathBuf) -> Result<Config> {
    let content = std::fs::read_to_string(path)?;
    Ok(toml::from_str(&content)?)
}

async fn init_config(config: &Config, force: bool) -> Result<()> {
    let config_path = Config::config_path();

    if config_path.exists() && !force {
        println!("⚠️  Configuración ya existe en: {}", config_path.display());
        println!("   Usa --force para sobrescribir");
        return Ok(());
    }

    if let Some(parent) = config_path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    config.save()?;
    println!("✅ Configuración creada en: {}", config_path.display());
    println!("\n📝 Edita el archivo para personalizar:");
    println!("   - backup.destination: punto de montaje de tu SSD Crucial");
    println!("   - sources: directorios a respaldar");
    println!("   - watch: configuración de vigilancia automática");
    Ok(())
}

async fn run_backup_once(config: &Config) -> Result<()> {
    println!("🚀 Ejecutando backup one-shot...");
    let mut engine = BackupEngine::new(config.clone());
    engine.run()?;                    // → snapshot con timestamp
    Ok(())
}

async fn run_daemon(config: &Config) -> Result<()> {
    println!("🚀 Iniciando backup daemon con watching automático...");

    let mut engine = BackupEngine::new(config.clone());
    engine.sync_mirror()?;            // → espejo Backup/actual/

    let (shutdown_tx, shutdown_rx) = mpsc::channel(1);
    let mut watcher = FileWatcher::new(config.clone());

    tokio::spawn(async move {
        signal::ctrl_c().await.unwrap();   // Ctrl+C → shutdown
        let _ = shutdown_tx.send(()).await;
    });

    watcher.run(shutdown_rx).await?;  // → bucle de vigilancia
    Ok(())
}
```

### status / list (excluyen el espejo)

Ambos leen el directorio raíz del backup y **filtran la carpeta `actual`** para no
contarla como versión:

```rust
async fn list_versions(config: &Config) -> Result<()> {
    let backup_root = config.backup_root();
    if !backup_root.exists() {
        println!("No hay versiones disponibles");
        return Ok(());
    }

    let mirror_name = config.mirror_dir()
        .file_name().unwrap_or_default().to_string_lossy().to_string();

    let mut versions: Vec<_> = std::fs::read_dir(&backup_root)?
        .filter_map(Result::ok)
        .filter(|e| {
            e.file_type().map(|ft| ft.is_dir()).unwrap_or(false)
                && e.file_name().to_string_lossy() != mirror_name
        })
        .collect();

    versions.sort_by_key(|e| e.file_name());
    // ... imprime fecha + tamaño de cada snapshot
}
```

### restore_version

```rust
async fn restore_version(config: &Config, version: &str, target: Option<&Path>, force: bool) -> Result<()> {
    let version_dir = config.backup_root().join(version);

    if !version_dir.exists() {
        anyhow::bail!("Versión no encontrada: {}", version);
    }

    let target_root = target.unwrap_or_else(|| std::path::Path::new("/"));
    println!("🔄 Restaurando versión {} a {}", version, target_root.display());

    // Confirma sobrescritura salvo --force
    if !force {
        print!("⚠️  Esto sobrescribirá archivos. ¿Continuar? [s/N] ");
        use std::io::{self, Write};
        io::stdout().flush()?;
        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        if !input.trim().eq_ignore_ascii_case("s") {
            println!("Cancelado");
            return Ok(());
        }
    }

    let mut restored = 0;
    for entry in walkdir::WalkDir::new(&version_dir).into_iter().filter_map(Result::ok) {
        if entry.file_type().is_file() {
            let rel = entry.path().strip_prefix(&version_dir)?;
            let dest = target_root.join(rel);
            if let Some(parent) = dest.parent() {
                std::fs::create_dir_all(parent)?;
            }
            std::fs::copy(entry.path(), &dest)?;
            restored += 1;
        }
    }
    println!("✅ Restaurados {} archivos", restored);
    Ok(())
}
```

### Utilidades de tamaño

```rust
fn dir_size(path: &Path) -> Result<u64> {
    let mut size = 0;
    for entry in walkdir::WalkDir::new(path).into_iter().filter_map(Result::ok) {
        if entry.file_type().is_file() {
            size += entry.metadata()?.len();
        }
    }
    Ok(size)
}

fn format_bytes(bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
    let mut size = bytes as f64;
    let mut unit_idx = 0;
    while size >= 1024.0 && unit_idx < UNITS.len() - 1 {
        size /= 1024.0;
        unit_idx += 1;
    }
    format!("{:.2} {}", size, UNITS[unit_idx])
}
```

---

## src/config.rs

**Archivo:** `~/backup-rs/src/config.rs` (154 líneas)

### Estructuras de datos (serde)

```rust
use anyhow::Result;
use dirs::home_dir;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub backup: BackupConfig,
    pub sources: Vec<SourceConfig>,
    pub watch: WatchConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupConfig {
    pub destination: PathBuf,     // punto de montaje del SSD
    pub folder_name: String,      // "Backup"
    pub max_versions: Option<usize>, // snapshots a conservar
    pub compression: bool,        // reservado
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceConfig {
    pub path: PathBuf,            // directorio origen
    pub include_hidden: bool,     // incluye archivos .oculto
    pub exclude_patterns: Vec<String>, // regex a excluir
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WatchConfig {
    pub enabled: bool,
    pub debounce_ms: u64,         // agrupación de eventos
    pub recursive: bool,
}
```

### Valores por defecto

```rust
impl Default for Config {
    fn default() -> Self {
        let home = home_dir().unwrap_or_else(|| PathBuf::from("/home/antonio"));

        Config {
            backup: BackupConfig {
                destination: PathBuf::from("/run/media/antonio/CRUCIAL"),
                folder_name: "Backup".to_string(),
                max_versions: Some(50),
                compression: false,
            },
            sources: vec![
                SourceConfig { path: home.join("Config"),     include_hidden: true, exclude_patterns: vec![] },
                SourceConfig { path: home.join("Documentos"), include_hidden: true, exclude_patterns: vec![] },
                SourceConfig { path: home.join("Descargas"),  include_hidden: true, exclude_patterns: vec![] },
                SourceConfig { path: home.join("Imágenes"),   include_hidden: true, exclude_patterns: vec![] },
                SourceConfig { path: home.join("Vídeos"),     include_hidden: true, exclude_patterns: vec![] },
            ],
            watch: WatchConfig { enabled: true, debounce_ms: 1000, recursive: true },
        }
    }
}
```

> ⚠️ **Detalle importante:** las carpetas son `Imágenes` y `Vídeos` **con tilde**,
> tal y como están en `~/.config/user-dirs.dirs`. Sin tilde darían `❌ no existe`.

### Carga, guardado y rutas del destino

```rust
impl Config {
    pub fn load() -> Result<Self> {
        let config_path = Self::config_path();
        if config_path.exists() {
            let content = std::fs::read_to_string(&config_path)?;
            Ok(toml::from_str(&content)?)
        } else {
            Ok(Self::default())
        }
    }

    pub fn save(&self) -> Result<()> {
        let config_path = Self::config_path();
        if let Some(parent) = config_path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let content = toml::to_string_pretty(self)?;
        std::fs::write(config_path, content)?;
        Ok(())
    }

    pub fn config_path() -> PathBuf {
        dirs::config_dir()
            .unwrap_or_else(|| PathBuf::from("/home/antonio/.config"))
            .join("backup-rs")
            .join("config.toml")
    }

    pub fn backup_root(&self) -> PathBuf {          // <dest>/<folder_name>
        self.backup.destination.join(&self.backup.folder_name)
    }

    pub fn mirror_dir(&self) -> PathBuf {           // <dest>/<folder_name>/actual
        self.backup_root().join("actual")
    }

    pub fn version_dir(&self, timestamp: &str) -> PathBuf {  // <dest>/<folder_name>/<ts>
        self.backup_root().join(timestamp)
    }
}
```

---

## src/backup.rs

**Archivo:** `~/backup-rs/src/backup.rs` (476 líneas)

### Motor de backup

```rust
use anyhow::Result;
use chrono::Local;
use indicatif::{ProgressBar, ProgressStyle};
use regex::Regex;
use std::fs;
use std::path::PathBuf;
use walkdir::{DirEntry, WalkDir};

use crate::config::{Config, SourceConfig};

pub struct BackupEngine {
    config: Config,
    timestamp: String,          // YYYY-MM-DD_HH-MM-SS del snapshot
    version_dir: PathBuf,       // Backup/<timestamp> para "once"
    stats: BackupStats,
}

#[derive(Debug, Default, Clone)]
pub struct BackupStats {
    pub files_copied: u64,
    pub files_skipped: u64,
    pub bytes_copied: u64,
    pub errors: u64,
}
```

### run() → snapshot incremental

```rust
    pub fn run(&mut self) -> Result<BackupStats> {
        println!("📦 Iniciando backup versionado: {}", self.timestamp);
        println!("📂 Destino: {}", self.version_dir.display());

        fs::create_dir_all(&self.version_dir)?;

        // Busca el snapshot anterior para encadenar por hardlinks
        self.prev_snapshot = self.find_prev_snapshot()?;
        self.sync_all(&self.version_dir.clone())?;   // copia incremental

        self.print_stats();
        self.cleanup_old_versions()?;                // limpia sobrantes
        Ok(self.stats.clone())
    }
```

### find_prev_snapshot() → localiza el snapshot anterior

```rust
    fn find_prev_snapshot(&self) -> Result<Option<PathBuf>> {
        let backup_root = self.config.backup_root();
        if !backup_root.exists() {
            return Ok(None);
        }
        let mirror_name = self.config.mirror_dir()
            .file_name().unwrap_or_default().to_string_lossy().to_string();
        let current_name = self.version_dir
            .file_name().unwrap_or_default().to_string_lossy().to_string();

        let mut versions: Vec<_> = fs::read_dir(&backup_root)?
            .filter_map(Result::ok)
            .filter(|e| {
                e.file_type().map(|ft| ft.is_dir()).unwrap_or(false)
                    && e.file_name().to_string_lossy() != mirror_name
                    && e.file_name().to_string_lossy() != current_name
            })
            .collect();
        versions.sort_by_key(|e| e.file_name());
        Ok(versions.last().map(|e| e.path()))
    }
```

### sync_mirror() → espejo actual

```rust
    pub fn sync_mirror(&mut self) -> Result<BackupStats> {
        let mirror = self.config.mirror_dir();
        println!("📦 Sincronizando espejo: {}", mirror.display());

        fs::create_dir_all(&mirror)?;

        // El espejo NO se encadena: es copia completa del estado actual
        self.prev_snapshot = None;
        self.sync_all(&mirror)?;

        self.print_stats();
        Ok(self.stats.clone())
    }
```

### sync_all() → recorrido de fuentes

```rust
    fn sync_all(&mut self, dest_dir: &PathBuf) -> Result<()> {
        let pb = ProgressBar::new_spinner();
        pb.set_style(
            ProgressStyle::default_spinner()
                .template("{spinner:.green} {msg}").unwrap(),
        );

        let sources = self.config.sources.clone();
        let dest_dir = dest_dir.clone();

        for source in &sources {
            if source.path.exists() {
                pb.set_message(format!("Procesando: {}", source.path.display()));
                self.backup_source(source, &dest_dir)?;
            } else {
                eprintln!("⚠️  Origen no existe: {}", source.path.display());
            }
        }

        pb.finish_with_message("✅ Sincronización completada");
        Ok(())
    }
```

### backup_source() → filtra y copia archivos

```rust
    fn backup_source(&mut self, source: &SourceConfig, dest_dir: &PathBuf) -> Result<()> {
        let entries: Vec<_> = WalkDir::new(&source.path)
            .follow_links(false)
            .into_iter()
            .filter_map(Result::ok)
            .filter(|e| self.should_include_entry(e, source))
            .collect();

        for entry in entries {
            if entry.file_type().is_file() {
                self.copy_file(&entry, source, dest_dir)?;
            }
        }
        Ok(())
    }
```

### should_include_entry() → ocultos y exclusiones

```rust
    fn should_include_entry(&self, entry: &DirEntry, source: &SourceConfig) -> bool {
        let file_name = entry.file_name().to_string_lossy();

        // Excluye ocultos SOLO si include_hidden = false
        if !source.include_hidden && file_name.starts_with('.') {
            return false;
        }

        // Excluye los que casen con algún regex
        for pattern in &source.exclude_patterns {
            if let Ok(re) = Regex::new(pattern) {
                if re.is_match(&file_name) {
                    return false;
                }
            }
        }
        true
    }
```

### copy_file() → copia incremental (prefijando la fuente)

```rust
    fn copy_file(&mut self, entry: &DirEntry, source: &SourceConfig, dest_dir: &PathBuf) -> Result<()> {
        let src_path = entry.path();
        let relative_path = src_path.strip_prefix(&source.path).unwrap();
        let source_name = source.path.file_name().unwrap_or_default().to_string_lossy();
        // dest_dir/<nombre fuente>/<ruta relativa>
        let dest_path = dest_dir.join(&*source_name).join(relative_path);

        if let Some(parent) = dest_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let metadata = fs::metadata(src_path)?;
        let dest_metadata = fs::metadata(&dest_path).ok();

        // 1) Si ya existe en el destino y no cambió (tamaño + mtime) → omitir
        let unchanged_in_dest = match dest_metadata {
            Some(meta) => meta.len() == metadata.len()
                && meta.modified().ok() == metadata.modified().ok(),
            None => false,
        };
        if unchanged_in_dest {
            self.stats.files_skipped += 1;
            return Ok(());
        }

        // 2) Si existe IGUAL en el snapshot anterior → HARDLINK (no duplica espacio)
        if let Some(prev) = &self.prev_snapshot {
            let prev_path = prev.join(&*source_name).join(relative_path);
            if let Ok(prev_meta) = fs::metadata(&prev_path) {
                let same = prev_meta.len() == metadata.len()
                    && prev_meta.modified().ok() == metadata.modified().ok();
                if same {
                    fs::remove_file(&dest_path).ok();
                    fs::hard_link(&prev_path, &dest_path)?;   // mismo inode
                    self.stats.files_skipped += 1;
                    return Ok(());
                }
            }
        }

        // 3) Nuevo o modificado → copia física preservando el mtime original
        fs::copy(src_path, &dest_path)?;
        let atime = FileTime::from_last_access_time(&metadata);
        let mtime = FileTime::from_last_modification_time(&metadata);
        filetime::set_file_times(&dest_path, atime, mtime)?;
        self.stats.files_copied += 1;
        self.stats.bytes_copied += metadata.len();
        Ok(())
    }
```

> 💡 **Incremental por hardlinks (esquema rsnapshot):** cada snapshot es un punto
> de restauración completo, pero los archivos que no cambian se comparten por
> **hardlink** (mismo inode) con el snapshot anterior. Solo los archivos nuevos o
> modificados ocupan espacio real. Se compara por **tamaño + mtime** (por eso la
> copia física preserva el mtime con `filetime`).
>
> 💡 **Por qué el prefijo de fuente:** evita colisiones entre rutas relativas
> iguales de orígenes distintos (p. ej. `Documentos/nota.txt` y `Descargas/nota.txt`).

### cleanup_old_versions() → poda de snapshots

```rust
    fn cleanup_old_versions(&self) -> Result<()> {
        if let Some(max_versions) = self.config.backup.max_versions {
            let backup_root = self.config.backup_root();
            if !backup_root.exists() {
                return Ok(());
            }

            let mirror_name = self.config.mirror_dir()
                .file_name().unwrap_or_default().to_string_lossy().to_string();

            let mut versions: Vec<_> = fs::read_dir(&backup_root)?
                .filter_map(Result::ok)
                .filter(|e| {
                    e.file_type().map(|ft| ft.is_dir()).unwrap_or(false)
                        && e.file_name().to_string_lossy() != mirror_name  // nunca toca el espejo
                })
                .collect();

            versions.sort_by_key(|e| e.file_name());

            while versions.len() > max_versions {
                if let Some(oldest) = versions.first() {
                    fs::remove_dir_all(oldest.path())?;
                    println!("🗑️  Eliminada versión antigua: {}", oldest.file_name().to_string_lossy());
                    versions.remove(0);
                }
            }
        }
        Ok(())
    }
```

### print_stats() y format_bytes()

```rust
    fn print_stats(&self) {
        println!("\n📊 Estadísticas:");
        println!("   Archivos copiados: {}", self.stats.files_copied);
        println!("   Archivos omitidos: {}", self.stats.files_skipped);
        println!("   Bytes copiados:    {}", format_bytes(self.stats.bytes_copied));
        if self.stats.errors > 0 {
            println!("   Errores:           {}", self.stats.errors);
        }
    }
}

fn format_bytes(bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
    let mut size = bytes as f64;
    let mut unit_idx = 0;
    while size >= 1024.0 && unit_idx < UNITS.len() - 1 {
        size /= 1024.0;
        unit_idx += 1;
    }
    format!("{:.2} {}", size, UNITS[unit_idx])
}
```

---

## src/watcher.rs

**Archivo:** `~/backup-rs/src/watcher.rs` (264 líneas)

### Estructura del vigilante

```rust
use anyhow::Result;
use notify::{Config as NotifyConfig, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};
use tokio::sync::mpsc;
use tokio::time::sleep;

use crate::config::Config;

pub struct FileWatcher {
    config: Config,
    pending: HashSet<PathBuf>,      // archivos con cambios sin procesar
    last_event: Option<Instant>,    // momento del último evento
    debounce_ms: u64,
}
```

### run() → bucle principal

```rust
impl FileWatcher {
    pub fn new(config: Config) -> Self {
        let debounce_ms = config.watch.debounce_ms;
        Self { config, pending: HashSet::new(), last_event: None, debounce_ms }
    }

    pub async fn run(&mut self, mut shutdown_rx: mpsc::Receiver<()>) -> Result<()> {
        let (tx, mut rx) = mpsc::channel::<Event>(1000);

        let mut watcher = RecommendedWatcher::new(
            move |res: Result<Event, notify::Error>| {
                if let Ok(event) = res {
                    let _ = tx.blocking_send(event);   // eventos al canal
                }
            },
            NotifyConfig::default(),
        )?;

        // Vigila cada fuente de forma recursiva
        for source in &self.config.sources {
            if source.path.exists() {
                watcher.watch(&source.path, RecursiveMode::Recursive)?;
                println!("👀 Vigilando: {}", source.path.display());
            }
        }

        println!("🔄 Modo watch activo. Presiona Ctrl+C para detener.");

        loop {
            tokio::select! {
                _ = shutdown_rx.recv() => {
                    println!("\n🛑 Deteniendo watcher...");
                    self.flush_pending().await;   // procesa lo pendiente y sale
                    break;
                }
                event = rx.recv() => {
                    if let Some(event) = event {
                        self.handle_event(&event);
                    }
                }
                _ = sleep(Duration::from_millis(100)), if !self.pending.is_empty() => {
                    if self.should_flush() { self.flush_pending().await; }
                }
            }
        }
        Ok(())
    }
```

### handle_event / should_flush → debounce

```rust
    fn handle_event(&mut self, event: &Event) {
        match event.kind {
            EventKind::Create(_) | EventKind::Modify(_) | EventKind::Remove(_) => {
                for path in &event.paths {
                    if self.should_process(path) {
                        self.pending.insert(path.clone());
                        self.last_event = Some(Instant::now());
                    }
                }
            }
            _ => {}
        }
    }

    // Se vacía la cola cuando lleva debounce_ms sin nuevos eventos
    fn should_flush(&self) -> bool {
        match self.last_event {
            Some(t) => t.elapsed() >= Duration::from_millis(self.debounce_ms),
            None => true,
        }
    }
```

### should_process → filtra como en el backup

```rust
    fn should_process(&self, path: &Path) -> bool {
        for source in &self.config.sources {
            if path.starts_with(&source.path) {
                let file_name = path.file_name().unwrap_or_default().to_string_lossy();
                if !source.include_hidden && file_name.starts_with('.') {
                    return false;
                }
                for pattern in &source.exclude_patterns {
                    if let Ok(re) = regex::Regex::new(pattern) {
                        if re.is_match(&file_name) {
                            return false;
                        }
                    }
                }
                return true;
            }
        }
        false
    }
```

### flush_pending / sync_to_mirror → aplica los cambios

```rust
    async fn flush_pending(&mut self) {
        if self.pending.is_empty() {
            return;
        }
        println!("📝 Procesando {} cambio(s) detectado(s)", self.pending.len());

        let paths: Vec<PathBuf> = self.pending.drain().collect();

        // Solo se propagan los cambios a los espejos planos en los que PODEMOS
        // escribir. El daemon corre como antonio y el SEAGATE/Linux es de root,
        // así que se omite (sin errores). Se sincroniza con "backup once/mirror".
        let mirrors: Vec<_> = self.config.mirrors.iter()
            .filter(|m| m.destination.exists() && is_writable_path(&m.destination))
            .cloned()
            .collect();

        for path in &paths {
            if let Err(e) = self.sync_to_mirror(path) {
                eprintln!("❌ Error en {}: {}", path.display(), e);
            }
            // Propagar el cambio a cada espejo plano montado y escribible
            for m in &mirrors {
                if let Err(e) = self.sync_to_plain(m, path) {
                    eprintln!("❌ Error en espejo {} para {}: {}", m.name, path.display(), e);
                }
            }
        }
        self.last_event = None;
    }

    fn sync_to_mirror(&self, src_path: &Path) -> Result<()> {
        for source in &self.config.sources {
            if src_path.starts_with(&source.path) {
                let relative = src_path.strip_prefix(&source.path)?;
                let source_name = source.path.file_name().unwrap_or_default().to_string_lossy();
                let dest_path = self.config.mirror_dir().join(&*source_name).join(relative);

                if src_path.is_dir() {
                    return Ok(());              // solo archivos
                }

                if src_path.exists() {
                    if let Some(parent) = dest_path.parent() {
                        std::fs::create_dir_all(parent)?;
                    }
                    std::fs::copy(src_path, &dest_path)?;
                    println!("   ✅ Guardado: {}", dest_path.display());
                } else if dest_path.exists() {
                    std::fs::remove_file(&dest_path)?;   // borrado en origen
                    println!("   🗑️  Eliminado del espejo: {}", dest_path.display());
                }
                break;
            }
        }
        Ok(())
    }
}
```

> 💡 **Espejos planos en el daemon:** el watcher solo propaga los cambios a los
> espejos planos en los que puede escribir. Como el daemon corre como `antonio` y
> `/SEAGATE/Linux` es de root, lo **omite silenciosamente** (sin errores de
> permisos). El SEAGATE se actualiza con `backup once` o `backup mirror` manual.
```

---

## Archivo de configuración

**Ubicación:** `~/.config/backup-rs/config.toml` (generado con `backup init`)

```toml
[backup]
destination = "/run/media/antonio/CRUCIAL"
folder_name = "Backup"
max_versions = 50
compression = false

[[sources]]
path = "/home/antonio/Config"
include_hidden = true
exclude_patterns = []

[[sources]]
path = "/home/antonio/Documentos"
include_hidden = true
exclude_patterns = []

[[sources]]
path = "/home/antonio/Descargas"
include_hidden = true
exclude_patterns = []

[[sources]]
path = "/home/antonio/Imágenes"
include_hidden = true
exclude_patterns = []

[[sources]]
path = "/home/antonio/Vídeos"
include_hidden = true
exclude_patterns = []

# Modelos de IA locales (GGUF) — p. ej. Qwen3.5-9B Q6_K
[[sources]]
path = "/home/antonio/modelos_ia"
include_hidden = true
exclude_patterns = []

[watch]
enabled = true
debounce_ms = 1000
recursive = true
```

> Nota: la config real de Antonio incluye además las fuentes `Cursos informatica`,
> `Varios Linux`, `modelos_ia`, `start-lmstudio.sh` y `system-info.sh`, y los
> espejos planos `SEAGATE` (local, requiere root) y `NUBE-antonio`/`NUBE-public`
> (nube SMB, sin root).

| Campo | Descripción |
|-------|-------------|
| `destination` | Punto de montaje del SSD Crucial |
| `folder_name` | Carpeta raíz del backup en el destino |
| `max_versions` | Snapshots a conservar (`null` = ilimitado) |
| `compression` | Reservado (de momento sin efecto) |
| `include_hidden` | Incluye archivos `.oculto` |
| `exclude_patterns` | Regex de nombres a excluir |
| `debounce_ms` | Tiempo de espera para agrupar cambios |
| `recursive` | Vigilancia recursiva |

---

## install.sh

**Archivo:** `~/backup-rs/install.sh` (instalador como root)

### Pasos del instalador

```
1. check_root + check_arch
2. install_rust   → pacman -S rust (si falta cargo)
3. build_project  → cargo build --release
4. install_binary → copia a /usr/local/bin/backup
5. setup_ssd_mount
   ├── blkid -L CRUCIAL (verifica el disco)
   └── crea la regla polkit 50-antonio-crucial.rules (Nautilus monta/desmonta el Crucial sin contraseña)
6. create_config → copia config.example.toml
7. install_systemd_service → crea backup-rs.service (NO habilitado; corre como antonio si se activa)
8. setup_bash_completion
9. print_summary
```

> ⚠️ **fstab:** el Crucial NO usa `/etc/fstab`: se monta/desmonta con `udisksctl` +
> regla polkit (para Nautilus). El SEAGATE se monta con sudo solo en `backup once/mirror`.
> La **nube MyCloud SÍ usa `/etc/fstab`** con opciones `users` + `x-systemd.automount`
> (montaje sin root). El daemon corre como `antonio` y omite el SEAGATE (requiere root).

---

## Servicios systemd

> 🚫 **Deshabilitado por defecto:** el servicio `backup-rs.service` está
> **deshabilitado** (`systemctl is-enabled backup-rs` → `disabled`). No arranca al
> iniciar el sistema ni corre en segundo plano. El backup se hace **manualmente**
> con `backup once`/`backup mirror`. Solo se habilita si se quiere vigilancia
> automática del Crucial en tiempo real.

### `backup-rs.service` (daemon de backup, opcional)

```ini
[Unit]
Description=Backup automático versionado (backup-rs)
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=antonio
Group=antonio
Environment=HOME=/home/antonio
WorkingDirectory=/home/antonio
ExecStart=/usr/local/bin/backup run
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=backup-rs

# Corre como antonio (el Crucial se monta sin privilegios). El SEAGATE
# (root) se omite en el daemon; se sincroniza con "backup once"/"backup mirror".
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
```

> 🖥️ **Si se habilita**, el daemon corre como `antonio` (no root), gestiona el
> Crucial sin privilegios y omite el SEAGATE (requiere root). Para habilitarlo:
> `sudo systemctl enable --now backup-rs`. Para deshabilitarlo:
> `sudo systemctl disable --now backup-rs`.

### Montaje del Crucial (Nautilus sin contraseña)

El Crucial (`/dev/sda1`) se monta/desmonta desde **Nautilus sin contraseña** gracias
a una **regla polkit específica solo para ese disco**:

**Archivo:** `/etc/polkit-1/rules.d/50-antonio-crucial.rules`

```js
polkit.addRule(function(action, subject) {
    if (subject.user == "antonio") {
        var dev = "";
        try { dev = action.lookup("device"); } catch (e) {}
        var isCrucial = (dev && (dev.indexOf("/dev/sda1") !== -1 || dev.indexOf("a78a8d29-6938-44c6-906e-8b41c6982e31") !== -1));
        if (isCrucial) {
            if (action.id == "org.freedesktop.udisks2.filesystem-mount" ||
                action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
                action.id == "org.freedesktop.udisks2.filesystem-mount-other-seat" ||
                action.id == "org.freedesktop.udisks2.filesystem-unmount-others" ||
                action.id == "org.freedesktop.udisks2.filesystem-unmount-system" ||
                action.id == "org.freedesktop.udisks2.filesystem-unmount") {
                return polkit.Result.YES;
            }
        }
    }
});
```

> 🔒 **Solo cubre el Crucial** (`/dev/sda1`). El **SEAGATE NO está incluido**: su
> montaje y copia requieren `sudo` (no se da privilegio de montaje a `antonio`).

---

## Flujo completo

```
1. Instalación
   ├── sudo bash install.sh
   ├── compila → /usr/local/bin/backup
   └── crea regla polkit (Nautilus monta el Crucial sin contraseña)
   ↓
2. Uso diario (MANUAL — no hay daemon, el servicio está deshabilitado)

3. backup once (desde la terminal, el comando principal)
   ├── 3.1. monta el Crucial con udisksctl (sin contraseña, regla polkit)
   ├── 3.2. snapshot versionado del Crucial como antonio (sin root)
   ├── 3.3. SEAGATE: detecta que requiere root → "sudo backup _mirror-only"
   │        (pide sudo UNA vez) → como root monta y machaca en SEAGATE/Linux
   ├── 3.4. NUBE (antonio + public): monta los shares CIFS (fstab users/automount,
   │        sin root) y machaca con rsync en MyCloud/<share>/Linux
   └── 3.5. termina (el Crucial NO se reprocesa como root)
   ↓
4. Actualizar solo el SEAGATE (opcional, si el Crucial ya está al día)
   └── backup mirror   (pide sudo una vez; los espejos nube se hacen sin root)
   ↓
5. Restauración (manual)
   └── backup list
       backup restore <YYYY-MM-DD_HH-MM-SS> --target <destino>
   ↓
6. (Opcional) Vigilancia automática del Crucial y la nube
   └── sudo systemctl enable --now backup-rs   # habilita el daemon
       # o en primer plano: backup run
```

> 🚫 **Sin daemon por defecto:** el servicio `backup-rs.service` está deshabilitado.
> No vigila nada en segundo plano. Los backups se hacen cuando tú ejecutas
> `backup once`/`backup mirror`.

---

## Comandos útiles

```bash
# Compilar en release
cd ~/backup-rs && cargo build --release

# Ayuda / versión
backup --help
backup --version

# Generar configuración (--force sobrescribe)
backup init
backup init --force

# Backup completo: snapshot del Crucial (sin contraseña) + SEAGATE (pide sudo una vez) + NUBE (sin root)
backup once

# Daemon de vigilancia (Crucial + nube en tiempo real; omite el SEAGATE que requiere root)
backup run

# Sincronizar manualmente los espejos planos (machacar, p. ej. SEAGATE) — pide sudo
# (los espejos nube se sincronizan también aquí, sin root)
backup mirror

# Estado y versiones
backup status
backup list

# Restaurar un snapshot
backup restore 2026-08-18_17-01-21 --target /tmp/restaurado --force

# Usar configuración alternativa (p. ej. pruebas)
backup --config /tmp/config.toml once

# Montar el Crucial desde la terminal (también se monta/desmonta desde Nautilus sin contraseña)
udisksctl mount -b /dev/disk/by-label/CRUCIAL

# (Solo si habilitas el daemon) Ver logs del daemon
# sudo systemctl enable --now backup-rs
# journalctl -u backup-rs -f
```

---

> 📁 `~/backup-rs/` · ⚙️ `~/.config/backup-rs/config.toml` · 💽 `/run/media/antonio/CRUCIAL/Backup`
