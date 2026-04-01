use std::collections::HashMap;
use std::path::PathBuf;
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use tracing::{debug, info, warn};

use crate::ipc::{DisplayOpts, MediaOpts, MonitorWallpaperState};

// ── Cache directory layout ──────────────────────────────────────────────────

fn cache_dir() -> PathBuf {
    directories::BaseDirs::new()
        .map(|d| d.cache_dir().join("walltool"))
        .unwrap_or_else(|| {
            let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
            PathBuf::from(home).join(".cache/walltool")
        })
}

fn state_file_path() -> PathBuf {
    cache_dir().join("wallpaper_state.json")
}

fn scheme_file_path() -> PathBuf {
    cache_dir().join("scheme.json")
}

// ── Persisted state structures ──────────────────────────────────────────────

/// Full persisted state written to `wallpaper_state.json`.
/// QML reads this file to know what to render and how.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersistedState {
    /// Per-monitor wallpaper configuration, keyed by monitor name (e.g. "DP-1")
    pub monitors: HashMap<String, MonitorState>,

    /// Global fallback used when a monitor has no specific entry
    #[serde(default)]
    pub fallback: Option<MonitorState>,
}

impl Default for PersistedState {
    fn default() -> Self {
        Self {
            monitors: HashMap::new(),
            fallback: None,
        }
    }
}

/// State for a single monitor's wallpaper.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MonitorState {
    /// Absolute path or URL to the wallpaper source
    pub path: Option<String>,

    /// Detected media type: "image", "video", "gif", "web"
    pub media_type: String,

    /// Display mode: "fill", "fit", "center", "stretch", "span"
    pub mode: String,

    /// Horizontal pixel offset for span/bridging mode
    #[serde(default)]
    pub offset_x: f64,

    /// Vertical pixel offset for span/bridging mode
    #[serde(default)]
    pub offset_y: f64,

    /// Whether audio is muted (video/web)
    #[serde(default)]
    pub muted: bool,

    /// Volume level 0–100
    #[serde(default = "default_volume")]
    pub volume: u8,

    /// Whether playback is paused
    #[serde(default)]
    pub paused: bool,
}

fn default_volume() -> u8 {
    100
}

impl Default for MonitorState {
    fn default() -> Self {
        Self {
            path: None,
            media_type: "image".into(),
            mode: "fill".into(),
            offset_x: 0.0,
            offset_y: 0.0,
            muted: false,
            volume: 100,
            paused: false,
        }
    }
}

// ── Media type detection ────────────────────────────────────────────────────

/// Determine media type from a path string.
/// Returns one of: "image", "video", "gif", "web"
fn detect_media_type(path: &str) -> String {
    // URL → web
    if path.starts_with("http://") || path.starts_with("https://") {
        return "web".into();
    }

    let lower = path.to_ascii_lowercase();

    // GIF is special — it's technically an image but needs a player
    if lower.ends_with(".gif") {
        return "gif".into();
    }

    // Try the `infer` crate for content sniffing
    if let Ok(buf) = std::fs::read(path) {
        if let Some(kind) = infer::get(&buf) {
            let mime = kind.mime_type();
            if mime.starts_with("video/") {
                return "video".into();
            }
            if mime == "image/gif" {
                return "gif".into();
            }
            if mime.starts_with("image/") {
                return "image".into();
            }
        }
    }

    // Fallback: extension-based heuristic
    const VIDEO_EXTS: &[&str] = &[
        ".mp4", ".mkv", ".webm", ".avi", ".mov", ".wmv", ".flv", ".m4v",
    ];
    const IMAGE_EXTS: &[&str] = &[
        ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff", ".tif", ".avif", ".heic", ".heif",
    ];

    if VIDEO_EXTS.iter().any(|e| lower.ends_with(e)) {
        return "video".into();
    }
    if IMAGE_EXTS.iter().any(|e| lower.ends_with(e)) {
        return "image".into();
    }

    // Unknown → treat as image
    warn!("could not detect media type for '{path}', defaulting to image");
    "image".into()
}

// ── State manager ───────────────────────────────────────────────────────────

/// In-memory manager for wallpaper state.
/// Handles reading/writing the persisted JSON, per-monitor tracking,
/// and converting between internal and IPC types.
pub struct WallpaperStateManager {
    state: PersistedState,
    dirty: bool,
}

impl WallpaperStateManager {
    /// Create a new manager, loading existing state from disk if present.
    pub fn new() -> Self {
        let state = Self::load_from_disk().unwrap_or_default();
        Self {
            state,
            dirty: false,
        }
    }

    /// Try to load persisted state from `wallpaper_state.json`.
    fn load_from_disk() -> Option<PersistedState> {
        let path = state_file_path();
        if !path.exists() {
            debug!("no existing state file at {}", path.display());
            return None;
        }

        let data = std::fs::read_to_string(&path)
            .inspect_err(|e| warn!("failed to read state file: {e}"))
            .ok()?;

        serde_json::from_str(&data)
            .inspect_err(|e| warn!("failed to parse state file: {e}"))
            .ok()
    }

    /// Persist current state to disk.
    pub fn flush(&mut self) -> Result<()> {
        if !self.dirty {
            return Ok(());
        }

        let dir = cache_dir();
        std::fs::create_dir_all(&dir)
            .with_context(|| format!("failed to create cache dir: {}", dir.display()))?;

        let path = state_file_path();
        let json = serde_json::to_string_pretty(&self.state)
            .context("failed to serialize wallpaper state")?;

        std::fs::write(&path, &json)
            .with_context(|| format!("failed to write state file: {}", path.display()))?;

        self.dirty = false;
        debug!("state flushed to {}", path.display());

        Ok(())
    }

    /// Set wallpaper for a specific monitor (or all monitors if `display.monitor` is None).
    pub async fn set_wallpaper(
        &mut self,
        path: &str,
        display: &DisplayOpts,
        media: &MediaOpts,
    ) -> Result<()> {
        let media_type = detect_media_type(path);

        let entry = MonitorState {
            path: Some(path.to_string()),
            media_type,
            mode: display.mode.clone(),
            offset_x: 0.0,
            offset_y: 0.0,
            muted: media.mute,
            volume: media.volume.unwrap_or(100),
            paused: false,
        };

        match &display.monitor {
            Some(monitor_name) => {
                info!("setting wallpaper on [{monitor_name}]: {path}");
                self.state.monitors.insert(monitor_name.clone(), entry);
            }
            None => {
                info!("setting wallpaper on all monitors: {path}");
                // When no specific monitor is given, update fallback and clear
                // per-monitor overrides so every screen shows the same thing.
                self.state.fallback = Some(entry.clone());

                // If we already track monitors, update them all
                let names: Vec<String> = self.state.monitors.keys().cloned().collect();
                for name in names {
                    self.state.monitors.insert(name, entry.clone());
                }

                // If no monitors tracked yet, at least set fallback
                if self.state.monitors.is_empty() {
                    // Will be picked up when monitors are discovered
                    debug!("no monitors tracked yet, wallpaper stored as fallback");
                }
            }
        }

        self.dirty = true;
        self.flush()?;

        Ok(())
    }

    /// Clear wallpaper on a specific monitor or all.
    pub fn clear_wallpaper(&mut self, monitor: Option<&str>) {
        match monitor {
            Some(name) => {
                if let Some(entry) = self.state.monitors.get_mut(name) {
                    entry.path = None;
                    entry.paused = true;
                }
            }
            None => {
                for entry in self.state.monitors.values_mut() {
                    entry.path = None;
                    entry.paused = true;
                }
                if let Some(fb) = &mut self.state.fallback {
                    fb.path = None;
                    fb.paused = true;
                }
            }
        }

        self.dirty = true;
        if let Err(e) = self.flush() {
            warn!("failed to flush state after clear: {e}");
        }
    }

    /// Get current wallpaper state for IPC response.
    /// If `monitor` is Some, return only that monitor.
    /// Otherwise, return all tracked monitors.
    pub fn get_current(&self, monitor: Option<&str>) -> Vec<MonitorWallpaperState> {
        let convert = |name: &str, s: &MonitorState| MonitorWallpaperState {
            monitor: name.to_string(),
            path: s.path.clone(),
            media_type: s.media_type.clone(),
            mode: s.mode.clone(),
            offset_x: s.offset_x,
            offset_y: s.offset_y,
            muted: s.muted,
            volume: s.volume,
            paused: s.paused,
        };

        match monitor {
            Some(name) => {
                if let Some(entry) = self.state.monitors.get(name) {
                    vec![convert(name, entry)]
                } else if let Some(fb) = &self.state.fallback {
                    vec![convert(name, fb)]
                } else {
                    vec![convert(name, &MonitorState::default())]
                }
            }
            None => {
                if self.state.monitors.is_empty() {
                    if let Some(fb) = &self.state.fallback {
                        vec![convert("*", fb)]
                    } else {
                        vec![]
                    }
                } else {
                    self.state
                        .monitors
                        .iter()
                        .map(|(name, entry)| convert(name, entry))
                        .collect()
                }
            }
        }
    }

    /// Set paused state for a specific monitor or all.
    pub fn set_paused(&mut self, monitor: Option<&str>, paused: bool) {
        match monitor {
            Some(name) => {
                if let Some(entry) = self.state.monitors.get_mut(name) {
                    entry.paused = paused;
                }
            }
            None => {
                for entry in self.state.monitors.values_mut() {
                    entry.paused = paused;
                }
                if let Some(fb) = &mut self.state.fallback {
                    fb.paused = paused;
                }
            }
        }
        self.dirty = true;
        if let Err(e) = self.flush() {
            warn!("failed to flush state after pause change: {e}");
        }
    }

    /// Toggle mute for a specific monitor or all.
    pub fn toggle_mute(&mut self, monitor: Option<&str>) {
        match monitor {
            Some(name) => {
                if let Some(entry) = self.state.monitors.get_mut(name) {
                    entry.muted = !entry.muted;
                }
            }
            None => {
                // Toggle: if any is unmuted, mute all; otherwise unmute all
                let any_unmuted = self
                    .state
                    .monitors
                    .values()
                    .any(|e| !e.muted);
                for entry in self.state.monitors.values_mut() {
                    entry.muted = any_unmuted;
                }
                if let Some(fb) = &mut self.state.fallback {
                    fb.muted = any_unmuted;
                }
            }
        }
        self.dirty = true;
        if let Err(e) = self.flush() {
            warn!("failed to flush state after mute toggle: {e}");
        }
    }

    /// Register a monitor that we learned about from Hyprland IPC.
    /// If it has no entry yet, apply the fallback (or default).
    pub fn ensure_monitor(&mut self, name: &str) {
        if self.state.monitors.contains_key(name) {
            return;
        }

        let entry = self
            .state
            .fallback
            .clone()
            .unwrap_or_default();

        info!("registering new monitor [{name}] with fallback wallpaper");
        self.state.monitors.insert(name.to_string(), entry);

        self.dirty = true;
        if let Err(e) = self.flush() {
            warn!("failed to flush state after monitor registration: {e}");
        }
    }

    /// Remove a monitor that was disconnected.
    pub fn remove_monitor(&mut self, name: &str) {
        if self.state.monitors.remove(name).is_some() {
            info!("removed monitor [{name}] from state");
            self.dirty = true;
            if let Err(e) = self.flush() {
                warn!("failed to flush state after monitor removal: {e}");
            }
        }
    }

    /// Update span offsets for bridging mode.
    /// Called after recalculating multi-monitor geometry.
    pub fn set_offsets(&mut self, monitor: &str, offset_x: f64, offset_y: f64) {
        if let Some(entry) = self.state.monitors.get_mut(monitor) {
            entry.offset_x = offset_x;
            entry.offset_y = offset_y;
            self.dirty = true;
        }
    }

    /// Get a reference to the raw persisted state (for profile saving, etc.)
    pub fn persisted(&self) -> &PersistedState {
        &self.state
    }

    /// Replace the entire state (for profile loading).
    pub fn replace(&mut self, new_state: PersistedState) -> Result<()> {
        self.state = new_state;
        self.dirty = true;
        self.flush()
    }

    /// Get the path to the state file (for QML file-watching).
    pub fn state_file() -> PathBuf {
        state_file_path()
    }

    /// Get the path to the scheme file.
    pub fn scheme_file() -> PathBuf {
        scheme_file_path()
    }

    /// Number of tracked monitors.
    pub fn monitor_count(&self) -> usize {
        self.state.monitors.len()
    }

    /// Update wallpaper path across all monitors and fallback after a rename
    /// (e.g. toggle-hidden). Flushes state to disk if any path was changed.
    pub fn rename_wallpaper_path(&mut self, old_path: &str, new_path: &str) {
        let mut changed = false;

        for entry in self.state.monitors.values_mut() {
            if entry.path.as_deref() == Some(old_path) {
                entry.path = Some(new_path.to_string());
                changed = true;
            }
        }

        if let Some(fb) = &mut self.state.fallback {
            if fb.path.as_deref() == Some(old_path) {
                fb.path = Some(new_path.to_string());
                changed = true;
            }
        }

        if changed {
            self.dirty = true;
            if let Err(e) = self.flush() {
                tracing::warn!("failed to flush state after path rename: {e}");
            }
        }
    }
}
