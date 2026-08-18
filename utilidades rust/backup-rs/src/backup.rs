use anyhow::{Context, Result};
use chrono::Local;
use filetime::FileTime;
use indicatif::{ProgressBar, ProgressStyle};
use regex::Regex;
use std::fs;
use std::path::{Path, PathBuf};
use walkdir::{DirEntry, WalkDir};

use crate::config::{Config, SourceConfig};

pub struct BackupEngine {
    config: Config,
    timestamp: String,
    version_dir: PathBuf,
    stats: BackupStats,
    prev_snapshot: Option<PathBuf>,
}

#[derive(Debug, Default, Clone)]
pub struct BackupStats {
    pub files_copied: u64,
    pub files_skipped: u64,
    pub bytes_copied: u64,
    pub errors: u64,
    pub files_deleted: u64,
}

impl BackupEngine {
    pub fn new(config: Config) -> Self {
        let timestamp = Local::now().format("%Y-%m-%d_%H-%M-%S").to_string();
        let version_dir = config.version_dir(&timestamp);
        Self {
            config,
            timestamp,
            version_dir,
            stats: BackupStats::default(),
            prev_snapshot: None,
        }
    }

    pub fn run(&mut self) -> Result<BackupStats> {
        println!("📦 Iniciando backup versionado: {}", self.timestamp);
        println!("📂 Destino: {}", self.version_dir.display());

        // Verificar que el disco de destino está montado (no crear el directorio
        // en el disco del sistema por error)
        if !self.config.backup.destination.exists() {
            anyhow::bail!(
                "El disco de destino no está montado/accesible: {}. Monta el disco o conéctalo físicamente.",
                self.config.backup.destination.display()
            );
        }

        fs::create_dir_all(&self.version_dir)?;

        // Buscar el snapshot anterior para encadenar por hardlinks
        self.prev_snapshot = self.find_prev_snapshot()?;

        self.sync_all(&self.version_dir.clone())?;

        self.print_stats();
        self.cleanup_old_versions()?;

        Ok(self.stats.clone())
    }

    pub fn sync_mirror(&mut self) -> Result<BackupStats> {
        let mirror = self.config.mirror_dir();
        println!("📦 Sincronizando espejo: {}", mirror.display());

        if !self.config.backup.destination.exists() {
            anyhow::bail!(
                "El disco de destino no está montado/accesible: {}. Monta el disco o conéctalo físicamente.",
                self.config.backup.destination.display()
            );
        }

        fs::create_dir_all(&mirror)?;

        // El espejo NO se encadena, es una copia completa del estado actual
        self.prev_snapshot = None;
        self.sync_all(&mirror)?;

        self.print_stats();

        Ok(self.stats.clone())
    }

    /// Sincroniza un espejo plano que MACHACA los cambios (NTFS, sin versiones).
    /// - Archivo nuevo → se copia
    /// - Archivo modificado → se sobrescribe (machaca)
    /// - Archivo eliminado en origen → se borra del destino
    pub fn sync_mirror_plain(&mut self, mirror: &std::path::Path) -> Result<BackupStats> {
        println!("📦 Sincronizando espejo plano (machacar): {}", mirror.display());

        self.stats = BackupStats::default();
        self.prev_snapshot = None;

        if !mirror.exists() {
            anyhow::bail!("El destino del espejo no está montado/accesible: {}", mirror.display());
        }

        let sources = self.config.sources.clone();

        for source in &sources {
            if source.path.exists() {
                let source_name = source.path
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .to_string();
                let dest_dir = mirror.join(&source_name);
                self.sync_plain_source(&source, &dest_dir)?;
            } else {
                eprintln!("⚠️  Origen no existe: {}", source.path.display());
            }
        }

        self.print_stats();

        Ok(self.stats.clone())
    }

    /// Sincroniza una fuente a su destino espejo, borrando lo que ya no exista
    fn sync_plain_source(&mut self, source: &SourceConfig, dest_dir: &PathBuf) -> Result<()> {
        // 1) Copiar / sobrescribir archivos del origen
        if source.path.is_file() {
            // Fuente = archivo suelto
            let dest_path = dest_dir.clone();
            self.copy_plain(&source.path, &dest_path)?;
            return Ok(());
        }

        let entries: Vec<_> = WalkDir::new(&source.path)
            .follow_links(false)
            .into_iter()
            .filter_map(Result::ok)
            .filter(|e| self.should_include_entry(e, source))
            .collect();

        for entry in &entries {
            if entry.file_type().is_file() {
                let rel = entry.path().strip_prefix(&source.path).unwrap();
                let dest_path = dest_dir.join(rel);
                self.copy_plain(entry.path(), &dest_path)?;
            }
        }

        // 2) Borrar del destino lo que ya no existe en el origen
        if dest_dir.exists() {
            self.remove_extra_files(dest_dir, &source.path)?;
        }

        Ok(())
    }

    /// Copia un archivo al espejo machacando (por tamaño para fiabilidad en NTFS)
    fn copy_plain(&mut self, src_path: &Path, dest_path: &Path) -> Result<()> {
        if let Some(parent) = dest_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let src_meta = fs::metadata(src_path)?;

        // Comparar por tamaño: si coincide, consideramos que está actualizado
        let up_to_date = match fs::metadata(dest_path) {
            Ok(d) => d.len() == src_meta.len(),
            Err(_) => false,
        };

        if up_to_date {
            self.stats.files_skipped += 1;
            return Ok(());
        }

        // Machacar: eliminar destino (por si es solo-lectura) y copiar
        fs::remove_file(dest_path).ok();
        fs::copy(src_path, dest_path)?;
        self.stats.files_copied += 1;
        self.stats.bytes_copied += src_meta.len();

        Ok(())
    }

    /// Borra recursivamente del espejo los archivos que no existen en el origen
    fn remove_extra_files(&mut self, dest_dir: &PathBuf, source_root: &PathBuf) -> Result<()> {
        for entry in WalkDir::new(dest_dir).follow_links(false).into_iter().filter_map(Result::ok) {
            if !entry.file_type().is_file() {
                continue;
            }
            let rel = entry.path().strip_prefix(dest_dir).unwrap();
            let src_candidate = source_root.join(rel);

            if !src_candidate.exists() {
                fs::remove_file(entry.path())?;
                println!("   🗑️  Eliminado del espejo (no existe en origen): {}", entry.path().display());
                self.stats.files_deleted += 1;
            }
        }
        Ok(())
    }

    /// Encuentra el snapshot más reciente (excluyendo el espejo y el actual)
    fn find_prev_snapshot(&self) -> Result<Option<PathBuf>> {
        let backup_root = self.config.backup_root();
        if !backup_root.exists() {
            return Ok(None);
        }

        let mirror_name = self.config.mirror_dir()
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string();

        let current_name = self.version_dir
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string();

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

    fn sync_all(&mut self, dest_dir: &PathBuf) -> Result<()> {
        let pb = ProgressBar::new_spinner();
        pb.set_style(
            ProgressStyle::default_spinner()
                .template("{spinner:.green} {msg}")
                .unwrap(),
        );

        let sources = self.config.sources.clone();
        let dest_dir = dest_dir.clone();

        for source in &sources {
            if source.path.exists() {
                pb.set_message(format!("Procesando: {}", source.path.display()));
                self.backup_source(source, &dest_dir)
                    .with_context(|| format!("Falló la fuente: {}", source.path.display()))?;
            } else {
                eprintln!("⚠️  Origen no existe: {}", source.path.display());
            }
        }

        pb.finish_with_message("✅ Sincronización completada");
        Ok(())
    }

    fn backup_source(&mut self, source: &SourceConfig, dest_dir: &PathBuf) -> Result<()> {
        // Si la fuente es un archivo individual, copiarlo directamente
        if source.path.is_file() {
            let source_name = source.path
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string();
            let dest_path = dest_dir.join(&source_name);
            self.copy_single(source, &dest_path)?;
            return Ok(());
        }

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

    /// Copia una fuente que es un archivo suelto (sin recorrer directorios)
    fn copy_single(&mut self, source: &SourceConfig, dest_path: &PathBuf) -> Result<()> {
        let src_path = &source.path;

        if let Some(parent) = dest_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let metadata = fs::metadata(src_path)?;
        let dest_metadata = fs::metadata(dest_path).ok();

        // Si ya existe igual, omitir
        let unchanged = match dest_metadata {
            Some(meta) => {
                meta.len() == metadata.len()
                    && meta.modified().ok() == metadata.modified().ok()
            }
            None => false,
        };

        if unchanged {
            self.stats.files_skipped += 1;
            return Ok(());
        }

        // Hardlink si existe igual en el snapshot anterior
        if let Some(prev) = &self.prev_snapshot {
            let prev_path = prev.join(dest_path.file_name().unwrap_or_default());
            if let Ok(prev_meta) = fs::metadata(&prev_path) {
                let same = prev_meta.len() == metadata.len()
                    && prev_meta.modified().ok() == metadata.modified().ok();
                if same {
                    fs::remove_file(dest_path).ok();
                    fs::hard_link(&prev_path, dest_path)?;
                    self.stats.files_skipped += 1;
                    return Ok(());
                }
            }
        }

        // Copia física preservando mtime
        // Eliminamos el destino primero por si es solo-lectura
        fs::remove_file(dest_path).ok();
        fs::copy(src_path, dest_path)?;
        let atime = FileTime::from_last_access_time(&metadata);
        let mtime = FileTime::from_last_modification_time(&metadata);
        filetime::set_file_times(dest_path, atime, mtime)?;
        self.stats.files_copied += 1;
        self.stats.bytes_copied += metadata.len();

        Ok(())
    }

    fn should_include_entry(&self, entry: &DirEntry, source: &SourceConfig) -> bool {
        let file_name = entry.file_name().to_string_lossy();

        if !source.include_hidden && file_name.starts_with('.') {
            return false;
        }

        for pattern in &source.exclude_patterns {
            if let Ok(re) = Regex::new(pattern) {
                if re.is_match(&file_name) {
                    return false;
                }
            }
        }
        true
    }

    fn copy_file(&mut self, entry: &DirEntry, source: &SourceConfig, dest_dir: &PathBuf) -> Result<()> {
        let src_path = entry.path();
        let relative_path = src_path.strip_prefix(&source.path).unwrap();
        let source_name = source.path
            .file_name()
            .unwrap_or_default()
            .to_string_lossy();
        let dest_path = dest_dir.join(&*source_name).join(relative_path);

        if let Some(parent) = dest_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let metadata = fs::metadata(src_path)?;
        let dest_metadata = fs::metadata(&dest_path).ok();

        // Si ya existe en el destino y no ha cambiado, no hacer nada
        let unchanged_in_dest = match dest_metadata {
            Some(meta) => {
                meta.len() == metadata.len()
                    && meta.modified().ok() == metadata.modified().ok()
            }
            None => false,
        };

        if unchanged_in_dest {
            self.stats.files_skipped += 1;
            return Ok(());
        }

        // Si hay un snapshot anterior y el archivo existe igual ahí,
        // crear un hardlink (no duplica espacio) en lugar de copiar
        if let Some(prev) = &self.prev_snapshot {
            let prev_path = prev.join(&*source_name).join(relative_path);
            if let Ok(prev_meta) = fs::metadata(&prev_path) {
                let same = prev_meta.len() == metadata.len()
                    && prev_meta.modified().ok() == metadata.modified().ok();
                if same {
                    // hardlink: mismo inode, no consume espacio nuevo
                    fs::remove_file(&dest_path).ok();
                    fs::hard_link(&prev_path, &dest_path)?;
                    self.stats.files_skipped += 1;
                    return Ok(());
                }
            }
        }

        // Archivo nuevo o modificado → copia física preservando timestamp
        // Eliminamos el destino primero por si es solo-lectura (p. ej. objetos .git)
        fs::remove_file(&dest_path).ok();
        fs::copy(src_path, &dest_path)?;
        let atime = FileTime::from_last_access_time(&metadata);
        let mtime = FileTime::from_last_modification_time(&metadata);
        filetime::set_file_times(&dest_path, atime, mtime)?;
        self.stats.files_copied += 1;
        self.stats.bytes_copied += metadata.len();

        Ok(())
    }

    fn cleanup_old_versions(&self) -> Result<()> {
        if let Some(max_versions) = self.config.backup.max_versions {
            let backup_root = self.config.backup_root();
            if !backup_root.exists() {
                return Ok(());
            }

            let mirror_name = self.config.mirror_dir()
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string();

            let mut versions: Vec<_> = fs::read_dir(&backup_root)?
                .filter_map(Result::ok)
                .filter(|e| {
                    e.file_type().map(|ft| ft.is_dir()).unwrap_or(false)
                        && e.file_name().to_string_lossy() != mirror_name
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

    fn print_stats(&self) {
        println!("\n📊 Estadísticas:");
        println!("   Archivos copiados: {}", self.stats.files_copied);
        println!("   Archivos omitidos: {}", self.stats.files_skipped);
        println!("   Bytes copiados:    {}", format_bytes(self.stats.bytes_copied));
        if self.stats.files_deleted > 0 {
            println!("   Archivos borrados: {}", self.stats.files_deleted);
        }
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