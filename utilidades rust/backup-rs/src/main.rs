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

    #[command(about = "Sincronizar espejos planos (machacar) definidos en la config")]
    Mirror,

    #[command(name = "_mirror-only", hide = true, about = "Sincronizar SOLO espejos planos (uso interno con sudo)")]
    MirrorOnly,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    init_logging(cli.verbose);

    let config = if let Some(path) = cli.config {
        load_config_from_path(&path)?
    } else {
        Config::load()?
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
        Commands::Mirror => {
            let mut engine = BackupEngine::new(config.clone());
            sync_plain_mirrors(&mut engine, &config, true)?;
        }
        Commands::MirrorOnly => {
            let mut engine = BackupEngine::new(config.clone());
            sync_plain_mirrors(&mut engine, &config, false)?;
        }
    }

    Ok(())
}

fn init_logging(verbose: bool) {
    let filter = if verbose {
        EnvFilter::new("debug")
    } else {
        EnvFilter::new("info")
    };

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

    // Intentar montar el disco principal (Crucial) si no está montado
    let mut config = config.clone();
    if let Some(mount) = ensure_mount(&config.backup.destination, &config.backup.folder_name, true) {
        if mount != config.backup.destination {
            println!("📌 Disco montado en: {}", mount.display());
            config.backup.destination = mount;
        }
    }

    // 1) Snapshot del Crucial como el usuario actual (antonio, sin root)
    let mut engine = BackupEngine::new(config.clone());
    engine.run()?;

    // 2) Espejos planos (machacar, p. ej. SEAGATE/Linux que es de root).
    //    Si el destino no es escribible por antonio (es de root), elevamos con
    //    `sudo backup _mirror-only` UNA sola vez: dentro, como root, se monta el
    //    disco y se copia todo. Así SOLO se pide sudo una vez, nunca pkexec.
    for mirror in &config.mirrors {
        let dest = &mirror.destination;

        // Determinar si este mirror requiere root. El SEAGATE/Linux es de root,
        // así que antonio no puede escribir en él (ni montarlo con udisks sin
        // que dispare pkexec). En ese caso elevamos con sudo directamente.
        // (Comprobamos el disco por label aunque esté desmontado: si el destino
        //  ya existe y no es escribible, o el disco está presente, requiere root.)
        let disk_present = mirror_disk_exists(dest);
        let need_root = !is_root() && (dest.exists() && !is_writable(dest) || disk_present);

        if need_root {
            println!("🔒 El destino del espejo {} requiere root, elevando con sudo (una sola vez)...", mirror.name);
            let config_path = Config::config_path();
            let status = std::process::Command::new("sudo")
                .arg("backup")
                .arg("--config")
                .arg(&config_path)
                .arg("_mirror-only")
                .status();
            if !status.map(|s| s.success()).unwrap_or(false) {
                anyhow::bail!("No se pudo elevar a root la sincronización del espejo {} (sudo cancelado o fallido)", mirror.name);
            }
        } else if dest.exists() {
            // No requiere root: sincronizar directamente (si está montado)
            engine.sync_mirror_plain(dest)?;
        } else {
            // El destino no existe: puede estar desmontado. Intentar montar con
            // udisksctl (sin pkexec gracias a la regla polkit de discos de backup)
            ensure_mount(dest, &config.backup.folder_name, true);
            if dest.exists() {
                engine.sync_mirror_plain(dest)?;
            } else {
                println!("⏭️  Espejo {} no está montado, se omite: {}", mirror.name, dest.display());
            }
        }
    }

    Ok(())
}

/// Comprueba si el disco de un mirror (por su label) está presente físicamente.
fn mirror_disk_exists(dest: &Path) -> bool {
    let components: Vec<String> = dest
        .components()
        .filter_map(|c| c.as_os_str().to_str().map(|s| s.to_string()))
        .collect();
    for comp in components.iter().rev() {
        if comp == "media" || comp == "run" || comp == "antonio" {
            break;
        }
        let dev = format!("/dev/disk/by-label/{}", comp);
        if Path::new(&dev).exists() {
            return true;
        }
    }
    false
}

/// Comprueba si el proceso actual corre como root.
fn is_root() -> bool {
    std::process::Command::new("id")
        .arg("-u")
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim() == "0")
        .unwrap_or(false)
}

/// Comprueba si un directorio es escribible por el usuario actual.
fn is_writable(path: &Path) -> bool {
    let probe = path.join("._probe_write");
    match std::fs::File::create(&probe) {
        Ok(_) => {
            let _ = std::fs::remove_file(&probe);
            true
        }
        Err(_) => false,
    }
}

/// Intenta montar un disco por etiqueta si su punto de montaje no existe.
/// Devuelve la ruta de montaje real del disco (puede diferir del destino
/// configurado si udisks2 eligió un nombre alternativo, p. ej. CRUCIAL1).
///
/// Estrategia: primero `udisksctl` (no pide nada para discos extraíbles). Si
/// falla por ser un disco de sistema (exige auth) y `can_use_sudo` es true,
/// usa `sudo mount` (pedirá la contraseña de sudo en la terminal, NO pkexec).
/// En el daemon (`can_use_sudo=false`) no usa sudo (no hay terminal) y omite.
fn ensure_mount(destination: &Path, _folder_name: &str, can_use_sudo: bool) -> Option<PathBuf> {
    // El punto de montaje de udisks2 es /run/media/<usuario>/<ETIQUETA>.
    // Buscamos, en la ruta del destino, el primer componente (desde la derecha)
    // que corresponda a una etiqueta de disco real.
    let components: Vec<String> = destination
        .components()
        .filter_map(|c| c.as_os_str().to_str().map(|s| s.to_string()))
        .collect();

    // Recorremos de derecha a izquierda buscando /dev/disk/by-label/<comp> real
    for comp in components.iter().rev() {
        if comp == "media" || comp == "run" {
            break;
        }
        let dev = format!("/dev/disk/by-label/{}", comp);
        if !Path::new(&dev).exists() {
            continue;
        }

        // Si ya hay un montaje real del disco, devolver su ruta
        if let Some(target) = find_mount_target(&dev) {
            return Some(target);
        }

        // Punto de montaje SIEMPRE en /run/media/antonio/<label> (el usuario real),
        // incluso cuando el proceso corre como root (_mirror-only / daemon root).
        // Así el disco queda accesible en la sesión de antonio y Nautilus lo ve.
        let base = Path::new("/run/media/antonio").join(comp);

        println!("🔌 Montando disco {}...", comp);

        // CASO 1: Si somos root (daemon), montar directamente con `mount`
        // (sin udisksctl, que en un proceso sin sesión gráfica dispararía pkexec).
        if is_root() {
            std::process::Command::new("mkdir").arg("-p").arg(&base).status().ok();
            let ok = std::process::Command::new("mount")
                .arg(&dev)
                .arg(&base)
                .status()
                .map(|s| s.success())
                .unwrap_or(false);
            if ok {
                println!("✅ Disco {} montado (root)", comp);
                return Some(base);
            } else {
                eprintln!("⚠️  No se pudo montar {} (root)", comp);
                return None;
            }
        }

        // CASO 2: No somos root (antonio interactivo).
        // a) Intentar udisksctl primero (para el Crucial hay una regla polkit que lo
        //    permite sin permisos; queda como sesión de usuario y Nautilus lo maneja).
        let udisks_ok = std::process::Command::new("udisksctl")
            .arg("mount")
            .arg("-b")
            .arg(&dev)
            .status()
            .map(|s| s.success())
            .unwrap_or(false);

        if udisks_ok {
            println!("✅ Disco {} montado", comp);
            return find_mount_target(&dev);
        }

        // b) Si udisksctl falló (p. ej. SEAGATE, que no tiene regla polkit), usar
        //    `sudo mount` (pedirá la contraseña de sudo en la terminal, NO pkexec).
        //    Solo en modo interactivo (backup once / mirror).
        if !can_use_sudo {
            eprintln!("⚠️  No se pudo montar {} (sin terminal para sudo)", comp);
            return None;
        }

        let mkdir_ok = std::process::Command::new("sudo")
            .arg("mkdir")
            .arg("-p")
            .arg(&base)
            .status()
            .map(|s| s.success())
            .unwrap_or(false);

        if !mkdir_ok {
            eprintln!("⚠️  No se pudo crear el punto de montaje {} (¿permisos?)", base.display());
            return None;
        }

        let mount_ok = std::process::Command::new("sudo")
            .arg("mount")
            .arg(&dev)
            .arg(&base)
            .status()
            .map(|s| s.success())
            .unwrap_or(false);

        if mount_ok {
            println!("✅ Disco {} montado (sudo)", comp);
            return Some(base);
        } else {
            eprintln!("⚠️  No se pudo montar {} (¿permisos?)", comp);
            return None;
        }
    }
    None
}

/// Devuelve el punto de montaje real de un dispositivo (findmnt), o None si no está montado.
fn find_mount_target(dev: &str) -> Option<PathBuf> {
    let output = std::process::Command::new("findmnt")
        .arg("-n")
        .arg("-o")
        .arg("TARGET")
        .arg(dev)
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let target = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if target.is_empty() {
        None
    } else {
        Some(PathBuf::from(target))
    }
}

/// Comprueba si una ruta es un punto de montaje real (no un directorio vacío residual).
fn is_mount_point(path: &Path) -> bool {
    let output = std::process::Command::new("findmnt")
        .arg("-n")
        .arg(path)
        .output();

    match output {
        Ok(o) => o.status.success(),
        Err(_) => false,
    }
}

async fn run_daemon(config: &Config) -> Result<()> {
    println!("🚀 Iniciando backup daemon con watching automático...");

    // Intentar montar el disco principal y los espejos al arrancar (sin sudo:
    // el daemon no tiene terminal para pedir la contraseña)
    let mut config = config.clone();
    if let Some(mount) = ensure_mount(&config.backup.destination, &config.backup.folder_name, false) {
        if mount != config.backup.destination {
            println!("📌 Disco principal montado en: {}", mount.display());
            config.backup.destination = mount;
        }
    }

    let mut engine = BackupEngine::new(config.clone());
    engine.sync_mirror()?;

    // Sincronizar los espejos planos (machacar) si están montados (sin sudo en el daemon)
    sync_plain_mirrors(&mut engine, &config, false)?;

    let (shutdown_tx, shutdown_rx) = mpsc::channel(1);

    let mut watcher = FileWatcher::new(config.clone());

    tokio::spawn(async move {
        signal::ctrl_c().await.unwrap();
        let _ = shutdown_tx.send(()).await;
    });

    watcher.run(shutdown_rx).await?;
    Ok(())
}

/// Sincroniza los espejos planos definidos en la config (solo si están montados)
fn sync_plain_mirrors(engine: &mut BackupEngine, config: &Config, can_use_sudo: bool) -> Result<()> {
    // En el daemon (can_use_sudo=false, corre como antonio) los espejos planos
    // (SEAGATE/Linux, propiedad de root) NO se sincronizan en segundo plano:
    // requieren elevación a root y el daemon no tiene terminal para sudo.
    // Se sincronizan manualmente con "backup once"/"backup mirror".
    // (Si corremos como root, p. ej. vía `_mirror-only`, sí se sincronizan.)
    if !can_use_sudo && !is_root() {
        if !config.mirrors.is_empty() {
            println!("⏭️  Espejos planos omitidos en el daemon (requieren root). Sincronízalos con 'backup mirror'.");
        }
        return Ok(());
    }

    for mirror in &config.mirrors {
        let dest = &mirror.destination;

        // ensure_mount garantiza que el disco esté montado
        ensure_mount(&mirror.destination, &config.backup.folder_name, true);

        if !dest.exists() {
            println!("⏭️  Espejo {} no está montado, se omite: {}", mirror.name, dest.display());
            continue;
        }

        println!("🔗 Sincronizando espejo plano: {} ({})", mirror.name, dest.display());
        engine.sync_mirror_plain(dest)?;
    }
    Ok(())
}

async fn show_status(config: &Config) -> Result<()> {
    let backup_root = config.backup_root();

    println!("📋 Estado del Backup");
    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    println!("📂 Destino: {}", backup_root.display());
    println!("📁 Orígenes configurados:");

    for source in &config.sources {
        let exists = if source.path.exists() { "✅" } else { "❌" };
        println!("   {} {}", exists, source.path.display());
    }

    println!("\n⚙️  Watch: {} (debounce: {}ms)", 
        if config.watch.enabled { "Activado" } else { "Desactivado" },
        config.watch.debounce_ms
    );

    if backup_root.exists() {
        let mirror_name = config.mirror_dir()
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string();

        let versions: Vec<_> = std::fs::read_dir(&backup_root)?
            .filter_map(Result::ok)
            .filter(|e| {
                e.file_type().map(|ft| ft.is_dir()).unwrap_or(false)
                    && e.file_name().to_string_lossy() != mirror_name
            })
            .collect();

        println!("\n📦 Versiones disponibles: {}", versions.len());
        for v in versions.iter().rev().take(10) {
            let meta = v.metadata()?;
            let modified = meta.modified()?;
            let dt: chrono::DateTime<chrono::Local> = modified.into();
            println!("   📅 {}", dt.format("%Y-%m-%d %H:%M:%S"));
        }

        if versions.len() > 10 {
            println!("   ... y {} más", versions.len() - 10);
        }
    } else {
        println!("\n📦 No hay backups aún");
    }

    Ok(())
}

async fn list_versions(config: &Config) -> Result<()> {
    let backup_root = config.backup_root();

    if !backup_root.exists() {
        println!("No hay versiones disponibles");
        return Ok(());
    }

    let mirror_name = config.mirror_dir()
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();

    let mut versions: Vec<_> = std::fs::read_dir(&backup_root)?
        .filter_map(Result::ok)
        .filter(|e| {
            e.file_type().map(|ft| ft.is_dir()).unwrap_or(false)
                && e.file_name().to_string_lossy() != mirror_name
        })
        .collect();

    versions.sort_by_key(|e| e.file_name());

    println!("📦 Versiones disponibles ({}):", versions.len());
    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    for v in versions.iter().rev() {
        let meta = v.metadata()?;
        let modified = meta.modified()?;
        let dt: chrono::DateTime<chrono::Local> = modified.into();
        let size = dir_size(&v.path())?;
        println!("   {}  ({})", dt.format("%Y-%m-%d %H:%M:%S"), format_bytes(size));
    }

    Ok(())
}

async fn restore_version(config: &Config, version: &str, target: Option<&Path>, force: bool) -> Result<()> {
    let version_dir = config.backup_root().join(version);

    if !version_dir.exists() {
        anyhow::bail!("Versión no encontrada: {}", version);
    }

    let target_root = target.unwrap_or_else(|| std::path::Path::new("/"));

    println!("🔄 Restaurando versión {} a {}", version, target_root.display());

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