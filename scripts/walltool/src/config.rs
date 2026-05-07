//! Configuration module for walltool
//!
//! Parses `~/.config/walltool/config.toml` at daemon startup.
//! CLI flags always override config values.

use std::collections::HashMap;
use std::path::PathBuf;

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use tracing::{debug, info, warn};

use crate::ipc::{AwwwOpts, MatugenParams};

// ══════════════════════════════════════════════════════════════════════════════
//  Config file structure
// ══════════════════════════════════════════════════════════════════════════════

/// Root configuration structure matching config.toml
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Config {
    #[serde(default)]
    pub awww: AwwwConfig,

    #[serde(default)]
    pub matugen: MatugenConfig,

    #[serde(default)]
    pub theme: ThemeConfig,

    #[serde(default)]
    pub slideshow: SlideshowConfig,

    #[serde(default)]
    pub indexer: IndexerConfig,
}

/// awww-related configuration
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AwwwConfig {
    #[serde(default)]
    pub global: AwwwGlobalConfig,

    #[serde(default)]
    pub defaults: AwwwDefaultsConfig,

    /// Per-monitor overrides: [awww.monitor."DP-1"]
    #[serde(default)]
    pub monitor: HashMap<String, AwwwDefaultsConfig>,
}

/// Global awww settings (namespace, etc.)
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AwwwGlobalConfig {
    pub namespace: Option<String>,
}

/// Default awww options (can be overridden per-monitor or via CLI)
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AwwwDefaultsConfig {
    pub resize: Option<String>,
    pub fill_color: Option<String>,
    pub filter: Option<String>,
    pub transition_type: Option<String>,
    pub transition_step: Option<u8>,
    pub transition_duration: Option<f64>,
    pub transition_fps: Option<u32>,
    pub transition_angle: Option<f64>,
    pub transition_pos: Option<String>,
    pub transition_bezier: Option<String>,
    pub transition_wave: Option<String>,
    pub invert_y: Option<bool>,
}

/// matugen-related configuration
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MatugenConfig {
    #[serde(default)]
    pub defaults: MatugenDefaultsConfig,
}

/// Default matugen parameters
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MatugenDefaultsConfig {
    #[serde(default = "default_mode")]
    pub mode: String,

    #[serde(default = "default_scheme_type")]
    pub scheme_type: String,

    pub contrast: Option<f64>,
    pub source_color_index: Option<u8>,
    pub prefer: Option<String>,
    pub fallback_color: Option<String>,
    pub opacity: Option<f64>,
    pub lightness_dark: Option<f64>,
    pub lightness_light: Option<f64>,
}

fn default_mode() -> String {
    "dark".into()
}

fn default_scheme_type() -> String {
    "scheme-tonal-spot".into()
}

impl Default for MatugenDefaultsConfig {
    fn default() -> Self {
        Self {
            mode: default_mode(),
            scheme_type: default_scheme_type(),
            contrast: None,
            source_color_index: None,
            prefer: None,
            fallback_color: None,
            opacity: None,
            lightness_dark: None,
            lightness_light: None,
        }
    }
}

/// Theme auto mode configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThemeConfig {
    #[serde(default)]
    pub auto: ThemeAutoConfig,
}

impl Default for ThemeConfig {
    fn default() -> Self {
        Self {
            auto: ThemeAutoConfig::default(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThemeAutoConfig {
    #[serde(default = "default_sunrise")]
    pub sunrise: String,

    #[serde(default = "default_sunset")]
    pub sunset: String,
}

fn default_sunrise() -> String {
    "07:00".into()
}

fn default_sunset() -> String {
    "19:00".into()
}

impl Default for ThemeAutoConfig {
    fn default() -> Self {
        Self {
            sunrise: default_sunrise(),
            sunset: default_sunset(),
        }
    }
}

/// Slideshow configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SlideshowConfig {
    /// Default directory for slideshow
    #[serde(default)]
    pub dir: Option<PathBuf>,

    /// Interval between wallpaper changes in seconds (default: 900 = 15 min)
    #[serde(default = "default_slideshow_interval")]
    pub interval: u64,

    /// Include hidden (dot) files
    #[serde(default)]
    pub include_hidden: bool,

    /// Only show hidden (dot) files
    #[serde(default)]
    pub only_hidden: bool,

    /// Only show favorites
    #[serde(default)]
    pub only_favorites: bool,

    /// Text filter query
    #[serde(default)]
    pub text_filter: Option<String>,
}

fn default_slideshow_interval() -> u64 {
    900
}

impl Default for SlideshowConfig {
    fn default() -> Self {
        Self {
            dir: None,
            interval: default_slideshow_interval(),
            include_hidden: false,
            only_hidden: false,
            only_favorites: false,
            text_filter: None,
        }
    }
}

/// Indexer configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IndexerConfig {
    /// Directories to watch for new wallpapers
    #[serde(default)]
    pub watch_dirs: Vec<PathBuf>,

    /// Enable AI tagging (requires candle/moondream)
    #[serde(default)]
    pub ai_tagging: bool,
}

impl Default for IndexerConfig {
    fn default() -> Self {
        Self {
            watch_dirs: Vec::new(),
            ai_tagging: false,
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Config loading
// ══════════════════════════════════════════════════════════════════════════════

impl Config {
    /// Default config path: `~/.config/walltool/config.toml`
    pub fn default_path() -> PathBuf {
        directories::ProjectDirs::from("", "", "walltool")
            .map(|d| d.config_dir().to_path_buf())
            .unwrap_or_else(|| {
                let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
                PathBuf::from(home).join(".config").join("walltool")
            })
            .join("config.toml")
    }

    /// Load config from default path. Returns default config if file doesn't exist.
    pub fn load() -> Result<Self> {
        Self::load_from(&Self::default_path())
    }

    /// Load config from a specific path. Returns default config if file doesn't exist.
    pub fn load_from(path: &PathBuf) -> Result<Self> {
        if !path.exists() {
            debug!("config file not found at {}, using defaults", path.display());
            return Ok(Self::default());
        }

        let content = std::fs::read_to_string(path)
            .with_context(|| format!("failed to read config from {}", path.display()))?;

        let config: Config = toml::from_str(&content)
            .with_context(|| format!("failed to parse config from {}", path.display()))?;

        info!("loaded config from {}", path.display());
        Ok(config)
    }

    /// Save config to default path
    pub fn save(&self) -> Result<()> {
        self.save_to(&Self::default_path())
    }

    /// Save config to a specific path
    pub fn save_to(&self, path: &PathBuf) -> Result<()> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)
                .with_context(|| format!("failed to create config directory {}", parent.display()))?;
        }

        let content = toml::to_string_pretty(self)
            .context("failed to serialize config")?;

        std::fs::write(path, content)
            .with_context(|| format!("failed to write config to {}", path.display()))?;

        info!("saved config to {}", path.display());
        Ok(())
    }

    /// Get default AwwwOpts from config
    pub fn default_awww_opts(&self) -> AwwwOpts {
        AwwwOpts {
            outputs: None,
            namespace: self.awww.global.namespace.clone(),
            resize: self.awww.defaults.resize.clone(),
            fill_color: self.awww.defaults.fill_color.clone(),
            filter: self.awww.defaults.filter.clone(),
            transition_type: self.awww.defaults.transition_type.clone(),
            transition_step: self.awww.defaults.transition_step,
            transition_duration: self.awww.defaults.transition_duration,
            transition_fps: self.awww.defaults.transition_fps,
            transition_angle: self.awww.defaults.transition_angle,
            transition_pos: self.awww.defaults.transition_pos.clone(),
            transition_bezier: self.awww.defaults.transition_bezier.clone(),
            transition_wave: self.awww.defaults.transition_wave.clone(),
            invert_y: self.awww.defaults.invert_y.unwrap_or(false),
        }
    }

    /// Get AwwwOpts for a specific monitor (merges defaults with monitor overrides)
    pub fn awww_opts_for_monitor(&self, monitor: &str) -> AwwwOpts {
        let mut opts = self.default_awww_opts();

        if let Some(mon_cfg) = self.awww.monitor.get(monitor) {
            // Merge monitor-specific overrides
            if let Some(v) = &mon_cfg.resize {
                opts.resize = Some(v.clone());
            }
            if let Some(v) = &mon_cfg.fill_color {
                opts.fill_color = Some(v.clone());
            }
            if let Some(v) = &mon_cfg.filter {
                opts.filter = Some(v.clone());
            }
            if let Some(v) = &mon_cfg.transition_type {
                opts.transition_type = Some(v.clone());
            }
            if let Some(v) = mon_cfg.transition_step {
                opts.transition_step = Some(v);
            }
            if let Some(v) = mon_cfg.transition_duration {
                opts.transition_duration = Some(v);
            }
            if let Some(v) = mon_cfg.transition_fps {
                opts.transition_fps = Some(v);
            }
            if let Some(v) = mon_cfg.transition_angle {
                opts.transition_angle = Some(v);
            }
            if let Some(v) = &mon_cfg.transition_pos {
                opts.transition_pos = Some(v.clone());
            }
            if let Some(v) = &mon_cfg.transition_bezier {
                opts.transition_bezier = Some(v.clone());
            }
            if let Some(v) = &mon_cfg.transition_wave {
                opts.transition_wave = Some(v.clone());
            }
            if let Some(v) = mon_cfg.invert_y {
                opts.invert_y = v;
            }
        }

        opts
    }

    /// Get default MatugenParams from config
    pub fn default_matugen_params(&self) -> MatugenParams {
        MatugenParams {
            mode: self.matugen.defaults.mode.clone(),
            scheme_type: self.matugen.defaults.scheme_type.clone(),
            contrast: self.matugen.defaults.contrast,
            source_color_index: self.matugen.defaults.source_color_index,
            prefer: self.matugen.defaults.prefer.clone(),
            fallback_color: self.matugen.defaults.fallback_color.clone(),
            opacity: self.matugen.defaults.opacity,
            lightness_dark: self.matugen.defaults.lightness_dark,
            lightness_light: self.matugen.defaults.lightness_light,
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  AwwwOpts merge utility
// ══════════════════════════════════════════════════════════════════════════════

/// Merge AwwwOpts: later values override earlier ones (CLI > per_wallpaper > monitor > defaults)
pub fn merge_awww_opts(base: &AwwwOpts, overlay: &AwwwOpts) -> AwwwOpts {
    AwwwOpts {
        outputs: overlay.outputs.clone().or_else(|| base.outputs.clone()),
        namespace: overlay.namespace.clone().or_else(|| base.namespace.clone()),
        resize: overlay.resize.clone().or_else(|| base.resize.clone()),
        fill_color: overlay.fill_color.clone().or_else(|| base.fill_color.clone()),
        filter: overlay.filter.clone().or_else(|| base.filter.clone()),
        transition_type: overlay.transition_type.clone().or_else(|| base.transition_type.clone()),
        transition_step: overlay.transition_step.or(base.transition_step),
        transition_duration: overlay.transition_duration.or(base.transition_duration),
        transition_fps: overlay.transition_fps.or(base.transition_fps),
        transition_angle: overlay.transition_angle.or(base.transition_angle),
        transition_pos: overlay.transition_pos.clone().or_else(|| base.transition_pos.clone()),
        transition_bezier: overlay.transition_bezier.clone().or_else(|| base.transition_bezier.clone()),
        transition_wave: overlay.transition_wave.clone().or_else(|| base.transition_wave.clone()),
        invert_y: if overlay.invert_y { true } else { base.invert_y },
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Time parsing for auto mode
// ══════════════════════════════════════════════════════════════════════════════

/// Parse time string "HH:MM" into (hour, minute)
pub fn parse_time(s: &str) -> Option<(u32, u32)> {
    let parts: Vec<&str> = s.split(':').collect();
    if parts.len() != 2 {
        return None;
    }

    let hour: u32 = parts[0].parse().ok()?;
    let minute: u32 = parts[1].parse().ok()?;

    if hour > 23 || minute > 59 {
        return None;
    }

    Some((hour, minute))
}

/// Check if current time is in "light" period (between sunrise and sunset)
pub fn is_light_time(sunrise: &str, sunset: &str) -> bool {
    use chrono::Timelike;

    let Some((sr_h, sr_m)) = parse_time(sunrise) else {
        warn!("invalid sunrise time: {sunrise}, defaulting to dark");
        return false;
    };
    let Some((ss_h, ss_m)) = parse_time(sunset) else {
        warn!("invalid sunset time: {sunset}, defaulting to dark");
        return false;
    };

    let now = chrono::Local::now();
    let current_minutes = now.hour() * 60 + now.minute();
    let sunrise_minutes = sr_h * 60 + sr_m;
    let sunset_minutes = ss_h * 60 + ss_m;

    current_minutes >= sunrise_minutes && current_minutes < sunset_minutes
}

// ══════════════════════════════════════════════════════════════════════════════
//  Tests
// ══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_time() {
        assert_eq!(parse_time("07:00"), Some((7, 0)));
        assert_eq!(parse_time("19:30"), Some((19, 30)));
        assert_eq!(parse_time("23:59"), Some((23, 59)));
        assert_eq!(parse_time("00:00"), Some((0, 0)));
        assert_eq!(parse_time("24:00"), None);
        assert_eq!(parse_time("12:60"), None);
        assert_eq!(parse_time("invalid"), None);
        assert_eq!(parse_time("12"), None);
    }

    #[test]
    fn test_default_config() {
        let config = Config::default();
        assert_eq!(config.matugen.defaults.mode, "dark");
        assert_eq!(config.matugen.defaults.scheme_type, "scheme-tonal-spot");
        assert_eq!(config.theme.auto.sunrise, "07:00");
        assert_eq!(config.theme.auto.sunset, "19:00");
    }

    #[test]
    fn test_merge_awww_opts() {
        let base = AwwwOpts {
            resize: Some("crop".into()),
            fill_color: Some("000000ff".into()),
            transition_type: Some("simple".into()),
            ..Default::default()
        };

        let overlay = AwwwOpts {
            resize: Some("fit".into()),
            transition_fps: Some(60),
            ..Default::default()
        };

        let merged = merge_awww_opts(&base, &overlay);

        assert_eq!(merged.resize, Some("fit".into())); // overlay wins
        assert_eq!(merged.fill_color, Some("000000ff".into())); // base preserved
        assert_eq!(merged.transition_type, Some("simple".into())); // base preserved
        assert_eq!(merged.transition_fps, Some(60)); // overlay added
    }

    #[test]
    fn test_parse_toml() {
        let toml_str = r#"
[awww.global]
namespace = "walltool-main"

[awww.defaults]
resize = "crop"
transition_type = "fade"

[awww.monitor."DP-1"]
resize = "fit"

[matugen.defaults]
mode = "light"
scheme_type = "scheme-vibrant"
contrast = 0.5

[theme.auto]
sunrise = "06:30"
sunset = "20:00"
"#;

        let config: Config = toml::from_str(toml_str).unwrap();

        assert_eq!(config.awww.global.namespace, Some("walltool-main".into()));
        assert_eq!(config.awww.defaults.resize, Some("crop".into()));
        assert_eq!(config.awww.defaults.transition_type, Some("fade".into()));
        assert_eq!(
            config.awww.monitor.get("DP-1").unwrap().resize,
            Some("fit".into())
        );
        assert_eq!(config.matugen.defaults.mode, "light");
        assert_eq!(config.matugen.defaults.scheme_type, "scheme-vibrant");
        assert_eq!(config.matugen.defaults.contrast, Some(0.5));
        assert_eq!(config.theme.auto.sunrise, "06:30");
        assert_eq!(config.theme.auto.sunset, "20:00");
    }
}
