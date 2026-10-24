use anyhow::{Context, Result};
use chrono::Local;
use filetime::{set_file_mtime, FileTime};
use indicatif::{ProgressBar, ProgressStyle};
use regex::Regex;
use std::fs;
use std::path::{Path, PathBuf};
use walkdir::{DirEntry, WalkDir};

use crate::config::{Config, SourceConfig};

/// Nombres vetados por el firmware de los NAS WD MyCloud (Samba `veto files`).
/// El servidor SMB los reserva para el sistema y devuelve
/// `NT_STATUS_OBJECT_NAME_NOT_FOUND` al intentar crearlos, lo que hace fallar
/// rsync con código 23. Se excluyen automáticamente en los espejos SMB.
const SMB_VETOED_NAMES: &[&str] = &[
    ".bin",
    ".DS_Store",
    "Network Trash Folder",
    ".systemfile",
    "lost+found",
    "Nas_Prog",
    "mirrored",
    "uploaded",
    ".wdmc",
    ".AppleDouble",
];

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
    pub dirs_deleted: u64,
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

    /// Sincroniza un espejo de red (nube SMB) con `rsync`, que es mucho más
    /// rápido y fiable sobre SMB/CIFS que la copia archivo a archivo de Rust.
    /// - Archivo nuevo → se copia
    /// - Archivo modificado → se sobrescribe (machaca)
    /// - Archivo eliminado en origen → se borra del destino
    ///
    /// Las opciones evitan chmod/mkstemp (no soportados por GVFS/SMB) y comparan
    /// por tamaño. Sobre CIFS del kernel (fstab users/automount) funciona sin root.
    ///
    /// Además de las `[[sources]]`, sincroniza las rutas de `extra_sources`
    /// (p. ej. `/mnt/seagate/Windows`) si existen.
    pub fn sync_network_mirror(
        &mut self,
        mirror_dest: &std::path::Path,
        extra_sources: &[std::path::PathBuf],
        extra_dest: Option<&std::path::Path>,
    ) -> Result<BackupStats> {
        println!("📦 Sincronizando espejo nube (rsync): {}", mirror_dest.display());

        self.stats = BackupStats::default();

        if !mirror_dest.exists() {
            anyhow::bail!("El destino del espejo nube no está montado/accesible: {}", mirror_dest.display());
        }

        let sources = self.config.sources.clone();

        for source in &sources {
            self.rsync_source(&source.path, &source.exclude_patterns, mirror_dest)?;
        }

        // Rutas adicionales propias de este mirror (p. ej. SEAGATE/Windows).
        // Se copian a `extra_dest` si se indica (p. ej. la raíz del share en vez
        // de dentro de `Linux`); si no, al propio destino del mirror.
        let extra_base = extra_dest.unwrap_or(mirror_dest);
        for extra in extra_sources {
            self.rsync_source(extra, &[], extra_base)?;
        }

        self.print_stats();

        println!("✅ Sincronización nube completada (rsync).");

        Ok(self.stats.clone())
    }

    /// Sincroniza UNA ruta (fichero o directorio) a `mirror_dest/<nombre>` con
    /// `rsync`. Si la ruta no existe, se omite con aviso.
    fn rsync_source(
        &mut self,
        source_path: &Path,
        exclude_patterns: &[String],
        mirror_dest: &Path,
    ) -> Result<()> {
        if !source_path.exists() {
            eprintln!("⚠️  Origen no existe: {}", source_path.display());
            return Ok(());
        }

        // Destino: mirror/<nombre fuente> (mismo esquema que el espejo plano)
        let source_name = source_path
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string();
        let dest_dir = mirror_dest.join(&source_name);

        let src_arg = source_path.to_string_lossy().to_string();
        let dst_arg = dest_dir.to_string_lossy().to_string();

        // El origen se pasa con "/" al final para copiar su contenido
        // dentro de <dest> (mismo comportamiento que el espejo plano).
        let src_with_slash = if source_path.is_dir() {
            format!("{}/", src_arg)
        } else {
            src_arg.clone()
        };

        println!("🔗 rsync: {} → {}", src_with_slash, dst_arg);
        let mut cmd = std::process::Command::new("rsync");
        // NO se usa --inplace sobre SMB: escribe directamente sobre el archivo
        // destino existente y hace ftruncate() al final, que en CIFS (WD MyCloud)
        // puede devolver EBADF/EIO y dejar el archivo TRUNCADO y corrupto en la nube.
        // Sin --inplace, rsync escribe a un temporal y hace rename: si falla,
        // el destino conserva intacto su contenido anterior.
        cmd.arg("-r")
            .arg("--no-perms")
            .arg("--no-owner")
            .arg("--no-group")
            .arg("--no-times")
            .arg("--size-only")
            .arg("--delete")
            .arg("--stats");

        // Aplicar exclusiones (pattern es regex; rsync espera globs).
        // Los patrones simples (nombres o rutas) funcionan como globs de rsync.
        for pattern in exclude_patterns {
            cmd.arg("--exclude").arg(pattern);
        }

        // Los NAS WD MyCloud tienen `veto files` en su Samba: nombres como
        // `.bin`, `uploaded`, `Nas_Prog`... están reservados y el servidor
        // rechaza crearlos (NT_STATUS_OBJECT_NAME_NOT_FOUND), haciendo que
        // rsync aborte con código 23. Se excluyen siempre para que la
        // sincronización a la nube no falle.
        for name in SMB_VETOED_NAMES {
            cmd.arg("--exclude").arg(format!("{name}/"));
            cmd.arg("--exclude").arg(name);
        }

        // Locale C para que las cifras de --stats sean estables (sin . miles)
        cmd.env("LC_ALL", "C");

        let output = cmd.arg(&src_with_slash).arg(&dst_arg).output();

        match output {
            Ok(o) if o.status.success() => {
                // rsync imprime las estadísticas en stdout con --stats
                let stdout = String::from_utf8_lossy(&o.stdout);
                parse_rsync_stats(&stdout, &mut self.stats);
            }
            Ok(o) => {
                let stderr = String::from_utf8_lossy(&o.stderr);
                // Mostrar las líneas de error reales de rsync (las que
                // empiezan por "rsync:"), no solo el resumen final.
                let errores: Vec<&str> = stderr
                    .lines()
                    .filter(|l| l.starts_with("rsync:"))
                    .collect();
                if errores.is_empty() {
                    anyhow::bail!(
                        "rsync del espejo {} falló con código {}: {}",
                        mirror_dest.display(),
                        o.status.code().unwrap_or(-1),
                        stderr.lines().last().unwrap_or_default()
                    );
                } else {
                    let detalle = errores.join("\n");
                    anyhow::bail!(
                        "rsync del espejo {} falló con código {}:\n{}",
                        mirror_dest.display(),
                        o.status.code().unwrap_or(-1),
                        detalle
                    );
                }
            }
            Err(e) => anyhow::bail!("No se pudo ejecutar rsync para {}: {}", mirror_dest.display(), e),
        }

        Ok(())
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
                self.sync_plain_source(source, &dest_dir)?;
            } else {
                eprintln!("⚠️  Origen no existe: {}", source.path.display());
            }
        }

        self.print_stats();

        Ok(self.stats.clone())
    }

    /// Sincroniza un espejo **disco-a-disco**: copia desde `source_root` hacia
    /// `dest_root` solo las entradas de `include` (o todas las de nivel superior
    /// si `include` está vacío), con la MISMA lógica "machacar" **incremental**
    /// que `sync_mirror_plain`: solo copia lo modificado (tamaño + fecha) y borra
    /// dentro de cada carpeta lo que ya no existe. No toca las demás entradas de
    /// `dest_root` (p. ej. carpetas propias del USB).
    pub fn sync_path_mirror(
        &mut self,
        source_root: &Path,
        dest_root: &Path,
        include: &[String],
    ) -> Result<BackupStats> {
        println!(
            "📦 Sincronizando espejo disco-a-disco (machacar incremental): {} → {}",
            source_root.display(),
            dest_root.display()
        );

        self.stats = BackupStats::default();
        self.prev_snapshot = None;

        if !dest_root.exists() {
            anyhow::bail!("El destino del espejo no está montado/accesible: {}", dest_root.display());
        }
        if !source_root.exists() {
            anyhow::bail!("El origen del espejo no está montado/accesible: {}", source_root.display());
        }

        // Entradas a espejar: las de `include` o, si está vacío, todas las de
        // nivel superior del origen.
        let items: Vec<String> = if include.is_empty() {
            std::fs::read_dir(source_root)?
                .filter_map(Result::ok)
                .filter_map(|e| e.file_name().to_str().map(|s| s.to_string()))
                .collect()
        } else {
            include.to_vec()
        };

        for item in &items {
            let src = source_root.join(item);
            let dst = dest_root.join(item);
            if !src.exists() {
                eprintln!("⚠️  Origen no existe, se omite: {}", src.display());
                continue;
            }
            // Reutiliza la misma lógica incremental + borrado de sobrantes.
            let source_cfg = SourceConfig {
                path: src,
                include_hidden: true,
                exclude_patterns: vec![],
            };
            self.sync_plain_source(&source_cfg, &dst)?;
        }

        self.print_stats();

        Ok(self.stats.clone())
    }

    /// Sincroniza una fuente a su destino espejo, borrando lo que ya no exista
    fn sync_plain_source(&mut self, source: &SourceConfig, dest_dir: &Path) -> Result<()> {
        // 1) Copiar / sobrescribir archivos del origen
        if source.path.is_file() {
            // Fuente = archivo suelto
            self.copy_plain(&source.path, dest_dir)?;
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

    /// Copia un archivo al espejo machacando. Espejo **incremental**: si el
    /// destino ya existe con el **mismo tamaño y fecha** (o más nueva), se omite;
    /// solo se copian los archivos modificados y se preserva el `mtime`.
    fn copy_plain(&mut self, src_path: &Path, dest_path: &Path) -> Result<()> {
        if let Some(parent) = dest_path.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("create_dir_all: {}", parent.display()))?;
        }

        let src_meta = fs::metadata(src_path)
            .with_context(|| format!("metadata src: {}", src_path.display()))?;
        let src_mtime = FileTime::from_last_modification_time(&src_meta);

        // Sin cambios si el destino existe con el MISMO tamaño y una fecha de
        // modificación >= a la del origen (espejo: solo lo necesario, no todo).
        let up_to_date = match fs::metadata(dest_path) {
            Ok(d) => {
                if d.len() != src_meta.len() {
                    false
                } else if src_mtime > FileTime::now() {
                    // Origen con mtime "en el futuro" (raro): no usar la fecha para
                    // no recopiar indefinidamente; basta con que coincida el tamaño.
                    true
                } else {
                    // La comparación va en SEGUNDOS, no al nanosegundo: un destino
                    // NTFS (SEAGATE) guarda el mtime con precisión de 100 ns, así que
                    // la fecha escrita queda unos ns por DEBAJO de la del origen y
                    // comparar al ns hace que el fichero se recopie en cada pasada
                    // (~11 GB por pasada en este home). A segundos el desfase
                    // desaparece; es el mismo criterio que usa rsync.
                    FileTime::from_last_modification_time(&d).seconds() >= src_mtime.seconds()
                }
            }
            Err(_) => false,
        };

        if up_to_date {
            self.stats.files_skipped += 1;
            return Ok(());
        }

        // Machacar: eliminar destino (por si es solo-lectura) y copiar solo el
        // contenido (sin chmod: los shares SMB/GVFS no soportan permisos)
        fs::remove_file(dest_path).ok();
        copy_contents(src_path, dest_path)
            .with_context(|| format!("copy_contents {} → {}", src_path.display(), dest_path.display()))?;
        // Preservar la fecha de modificación del origen para que las próximas
        // ejecuciones detecten "sin cambios" (tamaño + fecha) y no recopien.
        let _ = set_file_mtime(dest_path, src_mtime);
        self.stats.files_copied += 1;
        self.stats.bytes_copied += src_meta.len();

        Ok(())
    }

    /// Borra recursivamente del espejo los archivos **y directorios** que no
    /// existen en el origen (espejo fiel a la estructura del origen).
    ///
    /// Un directorio solo se elimina si está vacío (`remove_dir`), así que nunca
    /// se pierde contenido: si queda algo que no se puede borrar (un fichero
    /// excluido por `exclude_patterns`, un enlace, un fallo de red en un share
    /// SMB...), el directorio se queda y se reintenta en la siguiente pasada.
    fn remove_extra_files(&mut self, dest_dir: &Path, source_root: &Path) -> Result<()> {
        for entry in WalkDir::new(dest_dir).follow_links(false).into_iter().filter_map(Result::ok) {
            if !entry.file_type().is_file() {
                continue;
            }
            let rel = entry.path().strip_prefix(dest_dir).unwrap();
            let src_candidate = source_root.join(rel);

            if !src_candidate.exists() {
                // En shares SMB/GVFS una entrada puede "desaparecer" entre el
                // listado y el borrado (caché del filesystem) → ignoramos ENOENT.
                match fs::remove_file(entry.path()) {
                    Ok(()) => {
                        println!("   🗑️  Eliminado del espejo (no existe en origen): {}", entry.path().display());
                        self.stats.files_deleted += 1;
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
                    Err(e) => return Err(e.into()),
                }
            }
        }

        // 2) Directorios sobrantes: los que ya no existen en el origen. Se recorren
        //    con `contents_first` (hijos antes que padres), de modo que un árbol
        //    huérfano se vacía de dentro hacia fuera en la misma pasada.
        for entry in WalkDir::new(dest_dir)
            .follow_links(false)
            .contents_first(true)
            .into_iter()
            .filter_map(Result::ok)
        {
            // La raíz del espejo nunca se borra; los symlinks tampoco (no se gestionan).
            if entry.path() == dest_dir || !entry.file_type().is_dir() {
                continue;
            }
            let rel = match entry.path().strip_prefix(dest_dir) {
                Ok(rel) => rel,
                Err(_) => continue,
            };
            // Si existe en el origen se conserva, aunque esté vacío (fidelidad).
            if source_root.join(rel).exists() {
                continue;
            }
            match fs::remove_dir(entry.path()) {
                Ok(()) => {
                    println!("   🗑️  Eliminado del espejo (no existe en origen): {}/", entry.path().display());
                    self.stats.dirs_deleted += 1;
                }
                Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
                // No está vacío: contiene algo que no se puede borrar (excluido por
                // patrón, vetado por SMB...). Se deja y se reintenta más adelante.
                Err(e) if e.kind() == std::io::ErrorKind::DirectoryNotEmpty => {}
                Err(e) => return Err(e.into()),
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

    fn sync_all(&mut self, dest_dir: &Path) -> Result<()> {
        let pb = ProgressBar::new_spinner();
        pb.set_style(
            ProgressStyle::default_spinner()
                .template("{spinner:.green} {msg}")
                .unwrap(),
        );

        let sources = self.config.sources.clone();

        for source in &sources {
            if source.path.exists() {
                pb.set_message(format!("Procesando: {}", source.path.display()));
                self.backup_source(source, dest_dir)
                    .with_context(|| format!("Falló la fuente: {}", source.path.display()))?;
            } else {
                eprintln!("⚠️  Origen no existe: {}", source.path.display());
            }
        }

        pb.finish_with_message("✅ Sincronización completada");
        Ok(())
    }

    fn backup_source(&mut self, source: &SourceConfig, dest_dir: &Path) -> Result<()> {
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

    fn copy_file(&mut self, entry: &DirEntry, source: &SourceConfig, dest_dir: &Path) -> Result<()> {
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
        if self.stats.dirs_deleted > 0 {
            println!("   Directorios borrados: {}", self.stats.dirs_deleted);
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

/// Copia el contenido de un archivo sin tocar permisos ni mtime.
/// Necesario para shares SMB/GVFS (fuse) que no soportan chmod (ENOTSUP).
fn copy_contents(src: &Path, dst: &Path) -> std::io::Result<()> {
    let mut reader = std::fs::File::open(src)?;
    let mut writer = std::fs::File::create(dst)?;
    std::io::copy(&mut reader, &mut writer)?;
    writer.sync_all()?;
    Ok(())
}

/// Parsea la salida `--stats` de rsync (stderr) y acumula los contadores.
/// Formato con LC_ALL=C: números con coma como separador de miles.
fn parse_rsync_stats(stderr: &str, stats: &mut BackupStats) {
    let mut transferred: u64 = 0;
    let mut deleted: u64 = 0;
    let mut transferred_bytes: u64 = 0;
    let mut total_regular: u64 = 0;

    for line in stderr.lines() {
        let clean = line.trim();
        let num = |pat: &str| -> Option<u64> {
            let rest = clean.strip_prefix(pat)?;
            let value: String = rest
                .trim_start()
                .chars()
                .take_while(|c| c.is_ascii_digit() || *c == ',')
                .collect();
            value.replace(',', "").parse().ok()
        };

        if let Some(v) = num("Number of regular files transferred:") {
            transferred += v;
        } else if let Some(v) = num("Number of deleted files:") {
            deleted += v;
        } else if let Some(v) = num("Total transferred file size:") {
            transferred_bytes += v;
        } else if clean.starts_with("Number of files:") {
            // Línea "Number of files: N (reg: R, dir: D)" → extraer el (reg: R)
            if let Some(open) = clean.find("(reg:") {
                let rest = &clean[open + 5..];
                let value: String = rest
                    .trim_start()
                    .chars()
                    .take_while(|c| c.is_ascii_digit() || *c == ',')
                    .collect();
                if let Ok(v) = value.replace(',', "").parse::<u64>() {
                    total_regular += v;
                }
            }
        }
    }

    // Copiados = transferidos (nuevos o modificados); omitidos = total - transferidos
    stats.files_copied += transferred;
    stats.files_deleted += deleted;
    stats.bytes_copied += transferred_bytes;
    stats.files_skipped += total_regular.saturating_sub(transferred);
}
#[cfg(test)]
mod tests {
    use super::*;

    /// Prepara un directorio temporal limpio para un test.
    fn tmpdir(nombre: &str) -> PathBuf {
        let base = std::env::temp_dir().join(format!(
            "backup-rs-test-{}-{}",
            nombre,
            std::process::id()
        ));
        fs::remove_dir_all(&base).ok();
        fs::create_dir_all(&base).unwrap();
        base
    }

    /// El espejo debe perder los directorios que no existen en el origen (aunque
    /// estén vacíos o anidados) y conservar los que sí existen, vacíos incluidos.
    #[test]
    fn borra_directorios_huerfanos_y_conserva_los_del_origen() {
        let base = tmpdir("dirs");
        let origen = base.join("origen");
        let espejo = base.join("espejo");

        // Origen real: a/f.txt, b/c/f.txt y un directorio vacío legítimo
        fs::create_dir_all(origen.join("a")).unwrap();
        fs::create_dir_all(origen.join("b/c")).unwrap();
        fs::create_dir_all(origen.join("vacio_real")).unwrap();
        fs::write(origen.join("a/f.txt"), "a").unwrap();
        fs::write(origen.join("b/c/f.txt"), "c").unwrap();

        // Espejo: lo mismo + huérfanos (vacío, anidado y con fichero dentro)
        fs::create_dir_all(espejo.join("a")).unwrap();
        fs::create_dir_all(espejo.join("b/c")).unwrap();
        fs::create_dir_all(espejo.join("vacio_real")).unwrap();
        fs::write(espejo.join("a/f.txt"), "a").unwrap();
        fs::write(espejo.join("b/c/f.txt"), "c").unwrap();
        fs::create_dir_all(espejo.join("huerfano/references")).unwrap();
        fs::create_dir_all(espejo.join("huerfano2/sub/deep")).unwrap();
        fs::create_dir_all(espejo.join("huerfano3")).unwrap();
        fs::write(espejo.join("huerfano3/f.txt"), "x").unwrap();

        let mut engine = BackupEngine::new(Config::default());
        engine.remove_extra_files(&espejo, &origen).unwrap();

        assert!(!espejo.join("huerfano").exists(), "huérfano vacío debe desaparecer");
        assert!(!espejo.join("huerfano2").exists(), "huérfano anidado debe desaparecer");
        assert!(!espejo.join("huerfano3").exists(), "huérfano con fichero debe desaparecer");
        assert!(espejo.join("vacio_real").is_dir(), "el vacío que existe en origen se conserva");
        assert!(espejo.join("a/f.txt").is_file(), "el contenido válido no se toca");
        assert!(espejo.join("b/c/f.txt").is_file(), "el contenido válido no se toca");

        assert_eq!(engine.stats.files_deleted, 1, "solo el fichero huérfano");
        assert_eq!(engine.stats.dirs_deleted, 6, "references, huerfano, deep, sub, huerfano2, huerfano3");

        fs::remove_dir_all(&base).ok();
    }

    /// Un directorio huérfano que no se puede vaciar del todo NO debe borrarse
    /// (defensa: nunca perder contenido por un borrado parcial).
    #[cfg(unix)]
    #[test]
    fn conserva_huerfano_no_vaciable() {
        use std::os::unix::fs::symlink;

        let base = tmpdir("no-vaciable");
        let origen = base.join("origen");
        let espejo = base.join("espejo");
        fs::create_dir_all(&origen).unwrap();
        fs::create_dir_all(espejo.join("huerfano")).unwrap();
        // Un symlink no es `is_file()` para WalkDir → la fase de ficheros no lo
        // toca; el directorio queda no vacío y `remove_dir` falla con ENOTEMPTY.
        symlink("/ruta/inexistente", espejo.join("huerfano/enlace")).unwrap();

        let mut engine = BackupEngine::new(Config::default());
        engine.remove_extra_files(&espejo, &origen).unwrap();

        assert!(espejo.join("huerfano").is_dir(), "no se borra un directorio que aún tiene contenido");
        assert_eq!(engine.stats.dirs_deleted, 0);

        fs::remove_dir_all(&base).ok();
    }

    /// Prueba de integración del espejo completo: copia lo nuevo y limpia los
    /// restos (ficheros y directorios huérfanos) en la misma pasada.
    #[test]
    fn sync_mirror_plain_copia_y_limpia_restos() {
        use crate::config::{BackupConfig, WatchConfig};

        let base = tmpdir("mirror");
        let origen = base.join("origen");
        let espejo = base.join("espejo");

        fs::create_dir_all(origen.join("a")).unwrap();
        fs::create_dir_all(origen.join("vacio_real")).unwrap();
        fs::write(origen.join("a/f.txt"), "hola").unwrap();

        // Espejo previo: contenido válido, un vacío legítimo, un fichero obsoleto
        // y un directorio huérfano (la carpeta fantasma que dejaban las skills).
        fs::create_dir_all(espejo.join("origen/a")).unwrap();
        fs::create_dir_all(espejo.join("origen/vacio_real")).unwrap();
        fs::create_dir_all(espejo.join("origen/vieja/references")).unwrap();
        fs::write(espejo.join("origen/obsoleto.txt"), "x").unwrap();

        let config = Config {
            backup: BackupConfig {
                destination: base.join("crucial"),
                folder_name: "Backup".to_string(),
                max_versions: Some(1),
                compression: false,
            },
            sources: vec![SourceConfig {
                path: origen.clone(),
                include_hidden: true,
                exclude_patterns: vec![],
            }],
            watch: WatchConfig { enabled: false, debounce_ms: 0, recursive: false },
            mirrors: vec![],
        };

        let mut engine = BackupEngine::new(config);
        let stats = engine.sync_mirror_plain(&espejo).unwrap();

        assert!(espejo.join("origen/a/f.txt").is_file(), "el fichero del origen se copia");
        assert!(!espejo.join("origen/obsoleto.txt").exists(), "el fichero obsoleto se borra");
        assert!(!espejo.join("origen/vieja").exists(), "la carpeta huérfana desaparece");
        assert!(espejo.join("origen/vacio_real").is_dir(), "el vacío legítimo se conserva");
        assert_eq!(stats.files_deleted, 1);
        assert_eq!(stats.dirs_deleted, 2, "references y vieja");

        fs::remove_dir_all(&base).ok();
    }
}
