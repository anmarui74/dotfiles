use anyhow::Result;
use notify::{Config as NotifyConfig, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};
use tokio::sync::mpsc;
use tokio::time::sleep;

use crate::config::Config;
use crate::backup::BackupEngine;

pub struct FileWatcher {
    config: Config,
    pending: HashSet<PathBuf>,
    last_event: Option<Instant>,
    debounce_ms: u64,
    mirror_was_mounted: std::collections::HashMap<String, bool>,
}

impl FileWatcher {
    pub fn new(config: Config) -> Self {
        let debounce_ms = config.watch.debounce_ms;
        let mut mirror_was_mounted = std::collections::HashMap::new();
        for m in &config.mirrors {
            mirror_was_mounted.insert(m.name.clone(), m.destination.exists());
        }
        Self {
            config,
            pending: HashSet::new(),
            last_event: None,
            debounce_ms,
            mirror_was_mounted,
        }
    }

    pub async fn run(&mut self, mut shutdown_rx: mpsc::Receiver<()>) -> Result<()> {
        let (tx, mut rx) = mpsc::channel::<Event>(1000);

        let mut watcher = RecommendedWatcher::new(
            move |res: Result<Event, notify::Error>| {
                if let Ok(event) = res {
                    let _ = tx.blocking_send(event);
                }
            },
            NotifyConfig::default(),
        )?;

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
                    self.flush_pending().await;
                    break;
                }
                event = rx.recv() => {
                    if let Some(event) = event {
                        self.handle_event(&event);
                    }
                }
                _ = sleep(Duration::from_millis(100)), if !self.pending.is_empty() => {
                    if self.should_flush() {
                        self.flush_pending().await;
                    }
                }
                _ = sleep(Duration::from_secs(30)) => {
                    self.check_mirrors().await;
                }
            }
        }

        Ok(())
    }

    /// Comprueba periódicamente si algún espejo plano se ha montado para sincronizarlo
    async fn check_mirrors(&mut self) {
        let mirrors = self.config.mirrors.clone();
        let mut engine = BackupEngine::new(self.config.clone());

        for m in &mirrors {
            let now_mounted = m.destination.exists();
            let was_mounted = self.mirror_was_mounted.get(&m.name).copied().unwrap_or(false);

            // Si acaba de montarse → sincronizar
            if now_mounted && !was_mounted {
                println!("🔌 Disco montado, sincronizando espejo: {} ({})", m.name, m.destination.display());
                if m.uri.is_some() {
                    if let Err(e) = engine.sync_network_mirror(&m.destination) {
                        eprintln!("❌ Error sincronizando espejo nube {}: {}", m.name, e);
                    }
                } else if let Err(e) = engine.sync_mirror_plain(&m.destination) {
                    eprintln!("❌ Error sincronizando espejo {}: {}", m.name, e);
                }
            }

            self.mirror_was_mounted.insert(m.name.clone(), now_mounted);
        }
    }

    fn handle_event(&mut self, event: &Event) {
        match event.kind {
            EventKind::Create(_) | EventKind::Modify(_) | EventKind::Remove(_) => {
                for path in &event.paths {
                    if self.should_process(path) {
                        self.pending.insert(path.clone());
                        self.last_event = Some(Instant::now());
                    }                }
            }
            _ => {}
        }
    }

    fn should_flush(&self) -> bool {
        match self.last_event {
            Some(t) => t.elapsed() >= Duration::from_millis(self.debounce_ms),
            None => true,
        }
    }

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

    async fn flush_pending(&mut self) {
        if self.pending.is_empty() {
            return;
        }

        println!(
            "📝 Procesando {} cambio(s) detectado(s)",
            self.pending.len()
        );

        let paths: Vec<PathBuf> = self.pending.drain().collect();
        // Filtrar los espejos planos en los que podemos escribir. El daemon corre
        // como antonio, y el SEAGATE/Linux es de root → no puede escribir → se omite
        // (se sincroniza manualmente con "backup once"/"backup mirror" con sudo).
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

    /// Propaga un cambio concreto a un espejo plano (machacar)
    fn sync_to_plain(&self, mirror: &crate::config::MirrorConfig, src_path: &Path) -> Result<()> {
        for source in &self.config.sources {
            if src_path.starts_with(&source.path) {
                let source_name = source.path
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy();

                let dest_path = if source.path.is_file() {
                    mirror.destination.join(&*source_name)
                } else {
                    let relative = src_path.strip_prefix(&source.path)?;
                    mirror.destination.join(&*source_name).join(relative)
                };

                if src_path.is_dir() {
                    return Ok(());
                }

                if src_path.exists() {
                    if let Some(parent) = dest_path.parent() {
                        std::fs::create_dir_all(parent)?;
                    }
                    std::fs::remove_file(&dest_path).ok();
                    copy_contents_plain(src_path, &dest_path)?;
                    println!("   ✅ Guardado en {}: {}", mirror.name, dest_path.display());
                } else if dest_path.exists() {
                    std::fs::remove_file(&dest_path)?;
                    println!("   🗑️  Eliminado de {}: {}", mirror.name, dest_path.display());
                }
                break;
            }
        }
        Ok(())
    }

    fn sync_to_mirror(&self, src_path: &Path) -> Result<()> {
        for source in &self.config.sources {
            if src_path.starts_with(&source.path) {
                let source_name = source.path
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy();

                let dest_path = if source.path.is_file() {
                    // Fuente = archivo suelto → dest_dir/<nombre>
                    self.config.mirror_dir().join(&*source_name)
                } else {
                    // Fuente = directorio → dest_dir/<nombre>/<ruta relativa>
                    let relative = src_path.strip_prefix(&source.path)?;
                    self.config.mirror_dir().join(&*source_name).join(relative)
                };

                if src_path.is_dir() {
                    return Ok(());
                }

                if src_path.exists() {
                    if let Some(parent) = dest_path.parent() {
                        std::fs::create_dir_all(parent)?;
                    }
                    std::fs::remove_file(&dest_path).ok();
                    copy_contents_plain(src_path, &dest_path)?;
                    println!("   ✅ Guardado: {}", dest_path.display());
                } else if dest_path.exists() {
                    std::fs::remove_file(&dest_path)?;
                    println!("   🗑️  Eliminado del espejo: {}", dest_path.display());
                }
                break;
            }
        }
        Ok(())
    }
}

/// Comprueba si un directorio es escribible por el usuario actual.
fn is_writable_path(path: &Path) -> bool {
    let probe = path.join("._probe_write");
    match std::fs::File::create(&probe) {
        Ok(_) => {
            let _ = std::fs::remove_file(&probe);
            true
        }
        Err(_) => false,
    }
}

/// Copia el contenido de un archivo sin tocar permisos ni mtime.
/// Necesario para shares SMB/GVFS (fuse) que no soportan chmod (ENOTSUP).
fn copy_contents_plain(src: &Path, dst: &Path) -> std::io::Result<()> {
    let mut reader = std::fs::File::open(src)?;
    let mut writer = std::fs::File::create(dst)?;
    std::io::copy(&mut reader, &mut writer)?;
    writer.sync_all()?;
    Ok(())
}
