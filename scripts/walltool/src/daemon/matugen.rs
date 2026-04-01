use std::path::{Path, PathBuf};
use std::process::Stdio;

use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};
use tokio::process::Command;
use tracing::{debug, info, warn};

// ── Public types ────────────────────────────────────────────────────────────

/// The result of a successful Matugen run: a full Material You color scheme.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ColorScheme {
    pub source_color: String,
    pub mode: SchemeMode,
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

/// Flat set of Material You token colors.
/// Matugen outputs these as hex strings (#RRGGBB).
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

// ── Configuration ───────────────────────────────────────────────────────────

/// Options for a Matugen run.
#[derive(Debug, Clone)]
pub struct MatugenOptions {
    /// dark / light
    pub mode: SchemeMode,
    /// Matugen scheme variant (tonal-spot, fidelity, monochrome, …)
    pub variant: String,
}

impl Default for MatugenOptions {
    fn default() -> Self {
        Self {
            mode: SchemeMode::Dark,
            variant: "scheme-tonal-spot".into(),
        }
    }
}

// ── Media type detection ────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MediaKind {
    Image,
    Video,
    Gif,
    Web,
    Unknown,
}

/// Detect media kind from file path (extension-based for speed,
/// falling back to `infer` crate for magic bytes).
pub fn detect_media_kind(path: &Path) -> MediaKind {
    // Web URLs
    let path_str = path.to_string_lossy();
    if path_str.starts_with("http://") || path_str.starts_with("https://") {
        return MediaKind::Web;
    }

    // Extension-based fast path
    if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
        match ext.to_ascii_lowercase().as_str() {
            "jpg" | "jpeg" | "png" | "bmp" | "webp" | "tiff" | "tif" | "avif" | "heic" => {
                return MediaKind::Image;
            }
            "gif" => return MediaKind::Gif,
            "mp4" | "mkv" | "webm" | "avi" | "mov" | "flv" | "wmv" | "m4v" => {
                return MediaKind::Video;
            }
            "glsl" | "frag" | "html" => return MediaKind::Web,
            _ => {}
        }
    }

    // Fallback: magic bytes via `infer`
    if let Ok(buf) = std::fs::read(path) {
        if let Some(kind) = infer::get(&buf) {
            let mime = kind.mime_type();
            if mime.starts_with("image/gif") {
                return MediaKind::Gif;
            } else if mime.starts_with("image/") {
                return MediaKind::Image;
            } else if mime.starts_with("video/") {
                return MediaKind::Video;
            }
        }
    }

    MediaKind::Unknown
}

// ── FFmpeg frame extraction ─────────────────────────────────────────────────

/// Extract the first frame from a video/GIF file using `ffmpeg`.
/// Returns the path to a temporary `.jpg` file.
///
/// The caller is responsible for cleaning up the temp file.
pub async fn extract_first_frame(source: &Path) -> Result<PathBuf> {
    let cache_dir = cache_dir();
    std::fs::create_dir_all(&cache_dir)
        .with_context(|| format!("create cache dir: {}", cache_dir.display()))?;

    // Unique filename per extraction to avoid races when multiple requests
    // hit the daemon concurrently (e.g. multi-monitor video wallpaper set).
    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_micros();
    let stem = source
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("frame");
    let output = cache_dir.join(format!("_frame_{stem}_{ts}.jpg"));

    info!("extracting first frame: {} → {}", source.display(), output.display());

    let status = Command::new("ffmpeg")
        .args(["-y", "-i"])
        .arg(source)
        .args([
            "-vframes", "1",
            "-q:v", "2",
            "-f", "image2",
        ])
        .arg(&output)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .await
        .context("failed to spawn ffmpeg — is it installed? (pacman -S ffmpeg)")?;

    if !status.success() {
        bail!("ffmpeg exited with status {status} while extracting frame from {}", source.display());
    }

    if !output.exists() {
        bail!("ffmpeg did not produce output file {}", output.display());
    }

    Ok(output)
}

// ── Matugen runner ──────────────────────────────────────────────────────────

/// Run the full Matugen pipeline on a given source path:
///   - If video/GIF → extract frame first.
///   - If web → skip (return error or use fallback).
///   - Run `matugen image <path> --json <mode>` and parse output.
///   - Write `scheme.json` to cache.
pub async fn generate_scheme(
    source: &Path,
    opts: &MatugenOptions,
) -> Result<ColorScheme> {
    let kind = detect_media_kind(source);

    let image_path: PathBuf = match kind {
        MediaKind::Image => source.to_path_buf(),
        MediaKind::Video | MediaKind::Gif => {
            extract_first_frame(source)
                .await
                .context("frame extraction for matugen")?
        }
        MediaKind::Web => {
            bail!("cannot generate theme from web wallpaper (no image to analyse). \
                   Use `th generate <image>` manually or provide a fallback image.");
        }
        MediaKind::Unknown => {
            warn!("unknown media type for {}, trying as image", source.display());
            source.to_path_buf()
        }
    };

    let scheme = run_matugen(&image_path, opts).await?;

    // Persist to cache
    write_scheme_json(&scheme).await?;

    // Cleanup temp frame if we extracted one
    if kind == MediaKind::Video || kind == MediaKind::Gif {
        if let Err(e) = tokio::fs::remove_file(&image_path).await {
            debug!("failed to clean up temp frame: {e}");
        }
    }

    Ok(scheme)
}

/// Actually invoke `matugen` CLI and parse its JSON output.
async fn run_matugen(image_path: &Path, opts: &MatugenOptions) -> Result<ColorScheme> {
    info!(
        "running matugen: image={} mode={} variant={}",
        image_path.display(),
        opts.mode,
        opts.variant,
    );

    let output = Command::new("pkill").arg("matugen").output().await;
    let output = Command::new("matugen")
        .arg("image")
        .arg(image_path)
        .arg("--source-color-index")
        .arg("0")
        .args(["--json", "hex"])
        .args(["-t", &matugen_type_arg(&opts.variant)])
        .args(["-m", &opts.mode.to_string()])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await
        .context("failed to spawn matugen — is it installed? (pacman -S matugen)")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!("matugen failed (exit {}):\n{stderr}", output.status);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    debug!("matugen raw output length: {} bytes", stdout.len());

    // Matugen ≥0.10 with `--json hex` outputs:
    //   { "colors": { "<token>": { "dark": "#hex", "default": "#hex", "light": "#hex" }, … }, … }
    // We pick opts.mode ("dark" or "light") from each token's sub-object.
    let raw: serde_json::Value =
        serde_json::from_str(&stdout).context("failed to parse matugen JSON output")?;

    let colors_map = raw
        .get("colors")
        .and_then(|v| v.as_object())
        .with_context(|| "matugen output missing 'colors' object")?;

    let mode_key = opts.mode.to_string(); // "dark" or "light"

    // Helper: extract a hex string for `token` from the map.
    // Falls back to "default" key, then to empty string so deserialisation
    // never hard-fails on missing/new tokens.
    let pick = |token: &str| -> String {
        colors_map
            .get(token)
            .and_then(|v| {
                v.get(&mode_key)
                    .or_else(|| v.get("default"))
                    .and_then(|h| h.as_str())
            })
            .unwrap_or_default()
            .to_string()
    };

    let colors = SchemeColors {
        primary:                    pick("primary"),
        on_primary:                 pick("on_primary"),
        primary_container:          pick("primary_container"),
        on_primary_container:       pick("on_primary_container"),
        secondary:                  pick("secondary"),
        on_secondary:               pick("on_secondary"),
        secondary_container:        pick("secondary_container"),
        on_secondary_container:     pick("on_secondary_container"),
        tertiary:                   pick("tertiary"),
        on_tertiary:                pick("on_tertiary"),
        tertiary_container:         pick("tertiary_container"),
        on_tertiary_container:      pick("on_tertiary_container"),
        error:                      pick("error"),
        on_error:                   pick("on_error"),
        error_container:            pick("error_container"),
        on_error_container:         pick("on_error_container"),
        background:                 pick("background"),
        on_background:              pick("on_background"),
        surface:                    pick("surface"),
        on_surface:                 pick("on_surface"),
        surface_variant:            pick("surface_variant"),
        on_surface_variant:         pick("on_surface_variant"),
        outline:                    pick("outline"),
        outline_variant:            pick("outline_variant"),
        shadow:                     pick("shadow"),
        scrim:                      pick("scrim"),
        inverse_surface:            pick("inverse_surface"),
        inverse_on_surface:         pick("inverse_on_surface"),
        inverse_primary:            pick("inverse_primary"),
        surface_dim:                pick("surface_dim"),
        surface_bright:             pick("surface_bright"),
        surface_container_lowest:   pick("surface_container_lowest"),
        surface_container_low:      pick("surface_container_low"),
        surface_container:          pick("surface_container"),
        surface_container_high:     pick("surface_container_high"),
        surface_container_highest:  pick("surface_container_highest"),
        source_color:               Some(pick("source_color")),
    };

    // Top-level source_color field (may live outside colors map in some versions)
    let source_color = colors.source_color.clone()
        .filter(|s| !s.is_empty())
        .or_else(|| {
            raw.get("source_color")
                .and_then(|v| v.as_str())
                .map(str::to_string)
        })
        .unwrap_or_else(|| "#000000".to_string());

    Ok(ColorScheme {
        source_color,
        mode: opts.mode,
        variant: opts.variant.clone(),
        colors,
    })
}

// ── scheme.json persistence ─────────────────────────────────────────────────

/// Write the scheme to `~/.cache/walltool/scheme.json`.
pub async fn write_scheme_json(scheme: &ColorScheme) -> Result<()> {
    let path = scheme_json_path();

    if let Some(parent) = path.parent() {
        tokio::fs::create_dir_all(parent)
            .await
            .with_context(|| format!("create dir {}", parent.display()))?;
    }

    let json = serde_json::to_string_pretty(scheme).context("serialize scheme")?;
    tokio::fs::write(&path, &json)
        .await
        .with_context(|| format!("write {}", path.display()))?;

    info!("wrote scheme to {}", path.display());
    Ok(())
}

/// Read current scheme from disk (if it exists).
pub async fn read_scheme_json() -> Result<Option<ColorScheme>> {
    let path = scheme_json_path();
    if !path.exists() {
        return Ok(None);
    }

    let data = tokio::fs::read_to_string(&path)
        .await
        .with_context(|| format!("read {}", path.display()))?;

    let scheme: ColorScheme = serde_json::from_str(&data).context("parse scheme.json")?;
    Ok(Some(scheme))
}

// ── Helpers ─────────────────────────────────────────────────────────────────

fn cache_dir() -> PathBuf {
    directories::BaseDirs::new()
        .map(|d| d.cache_dir().join("walltool"))
        .unwrap_or_else(|| PathBuf::from("/tmp/walltool"))
}

fn scheme_json_path() -> PathBuf {
    cache_dir().join("scheme.json")
}

/// List of known Matugen palette variants (for `th palette list`).
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

/// Normalise a variant name to the `scheme-*` form that matugen CLI expects.
/// Accepts both `tonal-spot` (legacy) and `scheme-tonal-spot` (current).
fn matugen_type_arg(variant: &str) -> String {
    if variant.starts_with("scheme-") {
        variant.to_string()
    } else {
        format!("scheme-{variant}")
    }
}
