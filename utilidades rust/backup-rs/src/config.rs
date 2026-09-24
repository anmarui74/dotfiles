use anyhow::Result;
use dirs::home_dir;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub backup: BackupConfig,
    pub sources: Vec<SourceConfig>,
    pub watch: WatchConfig,
    #[serde(default)]
    pub mirrors: Vec<MirrorConfig>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MirrorConfig {
    pub name: String,
    pub destination: PathBuf,
    /// URI SMB del share de red (p. ej. smb://mycloud-eudvfr.local/antonio/Linux).
    /// Si está presente, el espejo es una "nube" que se monta sin root (CIFS
    /// del kernel vía fstab `users`/automount, o GVFS) y se sincroniza con
    /// `rsync` (mucho más rápido y fiable sobre SMB que la copia archivo a archivo).
    #[serde(default)]
    pub uri: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupConfig {
    pub destination: PathBuf,
    pub folder_name: String,
    pub max_versions: Option<usize>,
    pub compression: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceConfig {
    pub path: PathBuf,
    pub include_hidden: bool,
    pub exclude_patterns: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WatchConfig {
    pub enabled: bool,
    pub debounce_ms: u64,
    pub recursive: bool,
}

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
                SourceConfig {
                    path: home.join("Config"),
                    include_hidden: true,
                    exclude_patterns: vec![],
                },
                SourceConfig {
                    path: home.join("Documentos"),
                    include_hidden: true,
                    exclude_patterns: vec![],
                },
                SourceConfig {
                    path: home.join("Descargas"),
                    include_hidden: true,
                    exclude_patterns: vec![],
                },
                SourceConfig {
                    path: home.join("Imágenes"),
                    include_hidden: true,
                    exclude_patterns: vec![],
                },
                SourceConfig {
                    path: home.join("Vídeos"),
                    include_hidden: true,
                    exclude_patterns: vec![],
                },
                SourceConfig {
                    path: home.join("Cursos informatica"),
                    include_hidden: true,
                    exclude_patterns: vec![],
                },
                SourceConfig {
                    path: home.join("Varios Linux"),
                    include_hidden: true,
                    exclude_patterns: vec![],
                },
                SourceConfig {
                    path: home.join("start-lmstudio.sh"),
                    include_hidden: true,
                    exclude_patterns: vec![],
                },
                SourceConfig {
                    path: home.join("system-info.sh"),
                    include_hidden: true,
                    exclude_patterns: vec![],
                },
            ],
            watch: WatchConfig {
                enabled: true,
                debounce_ms: 1000,
                recursive: true,
            },
            mirrors: vec![
                MirrorConfig {
                    name: "SEAGATE".to_string(),
                    destination: PathBuf::from("/run/media/antonio/SEAGATE/Linux"),
                    uri: None,
                },
            ],
        }
    }
}

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

    pub fn backup_root(&self) -> PathBuf {
        self.backup.destination.join(&self.backup.folder_name)
    }

    pub fn mirror_dir(&self) -> PathBuf {
        self.backup_root().join("actual")
    }

    pub fn version_dir(&self, timestamp: &str) -> PathBuf {
        self.backup_root().join(timestamp)
    }
}