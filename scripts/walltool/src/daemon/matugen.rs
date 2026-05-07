//! Matugen orchestration module
//!
//! Handles Material You theme generation via the `matugen` CLI.
//! Key features:
//! - MatugenParams struct holds full state for all parameters
//! - Abortable task: kills previous matugen before starting new one
//! - `th set <param> <value>` for QML slider integration

use std::path::{Path, PathBuf};
use std::process::Stdio;

use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};
use tokio::process::Command;
use tokio::sync::Mutex;
use tokio::task::JoinHandle;
use tracing::{debug, info, warn};

use crate::ipc::MatugenParams;

// ══════════════════════════════════════════════════════════════════════════════
//  Public types
// ══════════════════════════════════════════════════════════════════════════════

/// Full color scheme result from matugen
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ColorScheme {
    pub source_color: String,
    pub mode: String,
    pub variant: String,
    pub colors: SchemeColors,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum SchemeMode {
    Dark,
    Light,
}

impl std::fmt::Display for SchemeMode {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SchemeMode::Dark => write!(f, "dark"),
            SchemeMode::Light => write!(f, "light"),
        }
    }
}

impl From<&str> for SchemeMode {
    fn from(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "light" => SchemeMode::Light,
            _ => SchemeMode::Dark,
        }
    }
}

/// Material You color tokens
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SchemeColors {
    pub primary: String,
    pub on_primary: String,
    pub primary_container: String,
    pub on_primary_container: String,
    pub secondary: String,
    pub on_secondary: String,
    pub secondary_container: String,
    pub on_secondary_container: String,
    pub tertiary: String,
    pub on_tertiary: String,
    pub tertiary_container: String,
    pub on_tertiary_container: String,
    pub error: String,
    pub on_error: String,
    pub error_container: String,
    pub on_error_container: String,
    pub background: String,
    pub on_background: String,
    pub surface: String,
    pub on_surface: String,
    pub surface_variant: String,
    pub on_surface_variant: String,
    pub outline: String,
    pub outline_variant: String,
    pub shadow: String,
    pub scrim: String,
    pub inverse_surface: String,
    pub inverse_on_surface: String,
    pub inverse_primary: String,
    pub surface_dim: String,
    pub surface_bright: String,
    pub surface_container_lowest: String,
    pub surface_container_low: String,
    pub surface_container: String,
    pub surface_container_high: String,
    pub surface_container_highest: String,
    pub source_color: Option<String>,
}

/// Available palette variants
pub const PALETTE_VARIANTS: &[&str] = &[
    "scheme-tonal-spot",
    "scheme-fidelity",
    "scheme-monochrome",
    "scheme-neutral",
    "scheme-vibrant",
    "scheme-expressive",
    "scheme-content",
    "scheme-rainbow",
    "scheme-fruit-salad",
];

/// Valid prefer values for --prefer flag
pub const PREFER_VALUES: &[&str] = &[
    "darkness",
    "lightness",
    "saturation",
    "less-saturation",
    "value",
    "closest-to-fallback",
];

// ══════════════════════════════════════════════════════════════════════════════
//  Matugen runner with abort support
// ══════════════════════════════════════════════════════════════════════════════

/// Manages the running matugen task to ensure only one runs at a time.
/// When a new task is started, the previous one is aborted.
pub struct MatugenRunner {
    handle: Mutex<Option<JoinHandle<Result<()>>>>,
}

impl MatugenRunner {
    pub fn new() -> Self {
        Self {
            handle: Mutex::new(None),
        }
    }

    /// Run matugen with the given parameters.
    /// Aborts any previously running matugen task first.
    pub async fn run(&self, path: &Path, params: &MatugenParams) {
        // Abort previous task
        {
            let mut handle = self.handle.lock().await;
            if let Some(h) = handle.take() {
                debug!("aborting previous matugen task");
                h.abort();
            }
        }

        // Kill any lingering matugen process (belt and suspenders)
        let _ = Command::new("pkill")
            .args(["-x", "matugen"])
            .status()
            .await;

        let path = path.to_path_buf();
        let params = params.clone();

        // Spawn new task
        let new_handle = tokio::spawn(async move {
            run_matugen_internal(&path, &params).await
        });

        // Store handle
        {
            let mut handle = self.handle.lock().await;
            *handle = Some(new_handle);
        }
    }
}

impl Default for MatugenRunner {
    fn default() -> Self {
        Self::new()
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MatugenParams helpers
// ══════════════════════════════════════════════════════════════════════════════

impl Default for MatugenParams {
    fn default() -> Self {
        Self {
            mode: "dark".to_string(),
            scheme_type: "scheme-tonal-spot".to_string(),
            contrast: None,
            source_color_index: Some(0),
            prefer: Some("saturation".to_string()),  // Always set prefer to avoid matugen errors
            fallback_color: None,
            opacity: None,
            lightness_dark: None,
            lightness_light: None,
        }
    }
}

impl MatugenParams {
    /// Set a parameter by name (for `th set <param> <value>`)
    pub fn set_param(&mut self, param: &str, value: &str) -> Result<()> {
        match param {
            "mode" => {
                if value != "dark" && value != "light" {
                    bail!("mode must be 'dark' or 'light'");
                }
                self.mode = value.to_string();
            }
            "scheme-type" => {
                let normalized = if value.starts_with("scheme-") {
                    value.to_string()
                } else {
                    format!("scheme-{value}")
                };
                if !PALETTE_VARIANTS.contains(&normalized.as_str()) {
                    bail!("unknown scheme type: {value}. Valid: {}", PALETTE_VARIANTS.join(", "));
                }
                self.scheme_type = normalized;
            }
            "contrast" => {
                let v: f64 = value.parse().context("contrast must be a number")?;
                if !(-1.0..=1.0).contains(&v) {
                    bail!("contrast must be between -1.0 and 1.0");
                }
                self.contrast = Some(v);
            }
            "source-color-index" => {
                let v: u8 = value.parse().context("source-color-index must be 0-4")?;
                if v > 4 {
                    bail!("source-color-index must be 0-4");
                }
                self.source_color_index = Some(v);
            }
            "prefer" => {
                if !PREFER_VALUES.contains(&value) {
                    bail!("unknown prefer value: {value}. Valid: {}", PREFER_VALUES.join(", "));
                }
                self.prefer = Some(value.to_string());
            }
            "fallback-color" => {
                // Normalize color
                let color = normalize_color(value)?;
                self.fallback_color = Some(color);
            }
            "opacity" => {
                let v: f64 = value.parse().context("opacity must be a number")?;
                if !(0.0..=1.0).contains(&v) {
                    bail!("opacity must be between 0.0 and 1.0");
                }
                self.opacity = Some(v);
            }
            "lightness-dark" => {
                let v: f64 = value.parse().context("lightness-dark must be a number")?;
                self.lightness_dark = Some(v);
            }
            "lightness-light" => {
                let v: f64 = value.parse().context("lightness-light must be a number")?;
                self.lightness_light = Some(v);
            }
            _ => bail!("unknown parameter: {param}"),
        }
        Ok(())
    }

    /// Build matugen CLI arguments from params
    pub fn to_args(&self) -> Vec<String> {
        let mut args = Vec::new();

        args.push("-m".to_string());
        args.push(self.mode.clone());

        args.push("-t".to_string());
        args.push(self.scheme_type.clone());

        if let Some(c) = self.contrast {
            args.push("--contrast".to_string());
            args.push(c.to_string());
        }

        if let Some(idx) = self.source_color_index {
            args.push("--source-color-index".to_string());
            args.push(idx.to_string());
        }

        if let Some(ref p) = self.prefer {
            args.push("--prefer".to_string());
            args.push(p.clone());
        }

        if let Some(ref c) = self.fallback_color {
            args.push("--fallback-color".to_string());
            args.push(c.clone());
        }

        if let Some(o) = self.opacity {
            args.push("--opacity".to_string());
            args.push(o.to_string());
        }

        if let Some(ld) = self.lightness_dark {
            args.push("--lightness-dark".to_string());
            args.push(ld.to_string());
        }

        if let Some(ll) = self.lightness_light {
            args.push("--lightness-light".to_string());
            args.push(ll.to_string());
        }

        args
    }
}

/// Normalize color: accepts #rrggbb, rrggbb, rrggbbaa → rrggbb (matugen format)
fn normalize_color(s: &str) -> Result<String> {
    let s = s.trim_start_matches('#');
    match s.len() {
        6 | 8 => {
            if s.chars().all(|c| c.is_ascii_hexdigit()) {
                // matugen wants just rrggbb without alpha
                Ok(s[..6].to_string())
            } else {
                bail!("invalid hex color: {s}")
            }
        }
        _ => bail!("color must be 6 or 8 hex digits"),
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Internal matugen execution
// ══════════════════════════════════════════════════════════════════════════════

async fn run_matugen_internal(path: &Path, params: &MatugenParams) -> Result<()> {
    // Handle video/gif: extract first frame
    let image_path = match detect_media_kind(path) {
        MediaKind::Video | MediaKind::Gif => {
            extract_first_frame(path).await?
        }
        MediaKind::Web => {
            warn!("cannot generate theme from web wallpaper");
            return Ok(());
        }
        _ => path.to_path_buf(),
    };

    let mut args = vec!["image".to_string()];
    args.push(image_path.to_string_lossy().to_string());
    args.extend(params.to_args());

    info!("matugen {}", args.join(" "));

    let mut cmd = Command::new("matugen");
    cmd.args(&args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .kill_on_drop(true);

    let child = cmd.spawn().context("failed to spawn matugen")?;
    let output = child.wait_with_output().await.context("matugen wait")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        warn!("matugen failed: {stderr}");
    } else {
        info!("matugen completed successfully");
    }

    // Cleanup temp frame if extracted
    if image_path != path {
        let _ = tokio::fs::remove_file(&image_path).await;
    }

    Ok(())
}

// ══════════════════════════════════════════════════════════════════════════════
//  Media type detection and frame extraction
// ══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MediaKind {
    Image,
    Video,
    Gif,
    Web,
    Unknown,
}

pub fn detect_media_kind(path: &Path) -> MediaKind {
    let path_str = path.to_string_lossy();
    if path_str.starts_with("http://") || path_str.starts_with("https://") {
        return MediaKind::Web;
    }

    if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
        match ext.to_ascii_lowercase().as_str() {
            "jpg" | "jpeg" | "png" | "bmp" | "webp" | "tiff" | "tif" | "avif" | "heic" => {
                return MediaKind::Image;
            }
            "gif" => return MediaKind::Gif,
            "mp4" | "mkv" | "webm" | "avi" | "mov" | "flv" | "wmv" | "m4v" => {
                return MediaKind::Video;
            }
            "html" | "glsl" | "frag" => return MediaKind::Web,
            _ => {}
        }
    }

    MediaKind::Unknown
}

fn cache_dir() -> PathBuf {
    directories::BaseDirs::new()
        .map(|d| d.cache_dir().join("walltool"))
        .unwrap_or_else(|| PathBuf::from("/tmp/walltool"))
}

async fn extract_first_frame(source: &Path) -> Result<PathBuf> {
    let cache = cache_dir();
    tokio::fs::create_dir_all(&cache).await?;

    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_micros();
    let stem = source.file_stem().and_then(|s| s.to_str()).unwrap_or("frame");
    let output = cache.join(format!("_frame_{stem}_{ts}.jpg"));

    info!("extracting frame: {} → {}", source.display(), output.display());

    let status = Command::new("ffmpeg")
        .args(["-y", "-i"])
        .arg(source)
        .args(["-vframes", "1", "-q:v", "2", "-f", "image2"])
        .arg(&output)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .await
        .context("ffmpeg not found")?;

    if !status.success() || !output.exists() {
        bail!("failed to extract frame from {}", source.display());
    }

    Ok(output)
}

// ══════════════════════════════════════════════════════════════════════════════
//  Generate scheme with JSON output (for API responses)
// ══════════════════════════════════════════════════════════════════════════════

/// Generate scheme and return the full color scheme (for th generate)
pub async fn generate_scheme(path: &Path, params: &MatugenParams) -> Result<ColorScheme> {
    // Handle video/gif
    let image_path = match detect_media_kind(path) {
        MediaKind::Video | MediaKind::Gif => extract_first_frame(path).await?,
        MediaKind::Web => bail!("cannot generate theme from web wallpaper"),
        _ => path.to_path_buf(),
    };

    let mut args = vec!["image".to_string()];
    args.push(image_path.to_string_lossy().to_string());
    args.push("--json".to_string());
    args.push("hex".to_string());
    args.extend(params.to_args());

    debug!("matugen {}", args.join(" "));

    let output = Command::new("matugen")
        .args(&args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await
        .context("failed to spawn matugen")?;

    // Cleanup temp frame
    if image_path != path {
        let _ = tokio::fs::remove_file(&image_path).await;
    }

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!("matugen failed: {stderr}");
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let raw: serde_json::Value = serde_json::from_str(&stdout).context("parse matugen JSON")?;

    let colors_map = raw
        .get("colors")
        .and_then(|v| v.as_object())
        .context("missing 'colors' in matugen output")?;

    let mode_key = &params.mode;

    let pick = |token: &str| -> String {
        colors_map
            .get(token)
            .and_then(|v| v.get(mode_key).or_else(|| v.get("default")).and_then(|h| h.as_str()))
            .unwrap_or_default()
            .to_string()
    };

    let colors = SchemeColors {
        primary: pick("primary"),
        on_primary: pick("on_primary"),
        primary_container: pick("primary_container"),
        on_primary_container: pick("on_primary_container"),
        secondary: pick("secondary"),
        on_secondary: pick("on_secondary"),
        secondary_container: pick("secondary_container"),
        on_secondary_container: pick("on_secondary_container"),
        tertiary: pick("tertiary"),
        on_tertiary: pick("on_tertiary"),
        tertiary_container: pick("tertiary_container"),
        on_tertiary_container: pick("on_tertiary_container"),
        error: pick("error"),
        on_error: pick("on_error"),
        error_container: pick("error_container"),
        on_error_container: pick("on_error_container"),
        background: pick("background"),
        on_background: pick("on_background"),
        surface: pick("surface"),
        on_surface: pick("on_surface"),
        surface_variant: pick("surface_variant"),
        on_surface_variant: pick("on_surface_variant"),
        outline: pick("outline"),
        outline_variant: pick("outline_variant"),
        shadow: pick("shadow"),
        scrim: pick("scrim"),
        inverse_surface: pick("inverse_surface"),
        inverse_on_surface: pick("inverse_on_surface"),
        inverse_primary: pick("inverse_primary"),
        surface_dim: pick("surface_dim"),
        surface_bright: pick("surface_bright"),
        surface_container_lowest: pick("surface_container_lowest"),
        surface_container_low: pick("surface_container_low"),
        surface_container: pick("surface_container"),
        surface_container_high: pick("surface_container_high"),
        surface_container_highest: pick("surface_container_highest"),
        source_color: Some(pick("source_color")),
    };

    let source_color = colors.source_color.clone()
        .filter(|s| !s.is_empty())
        .or_else(|| raw.get("source_color").and_then(|v| v.as_str()).map(str::to_string))
        .unwrap_or_else(|| "#000000".to_string());

    Ok(ColorScheme {
        source_color,
        mode: params.mode.clone(),
        variant: params.scheme_type.clone(),
        colors,
    })
}
