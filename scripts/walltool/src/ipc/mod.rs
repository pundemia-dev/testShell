pub mod client;
pub mod server;

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Socket path: $XDG_RUNTIME_DIR/walltool.sock
pub fn socket_path() -> PathBuf {
    let runtime_dir = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| {
        // Fallback: read uid from /proc/self/status to avoid libc dependency
        let uid = std::fs::read_to_string("/proc/self/status")
            .ok()
            .and_then(|s| {
                s.lines()
                    .find(|l| l.starts_with("Uid:"))
                    .and_then(|l| l.split_whitespace().nth(1))
                    .and_then(|v| v.parse::<u32>().ok())
            })
            .unwrap_or(1000);
        format!("/run/user/{uid}")
    });
    PathBuf::from(runtime_dir).join("walltool.sock")
}

/// Wire format: 4-byte little-endian length prefix + JSON payload.
pub const MAX_MESSAGE_SIZE: usize = 16 * 1024 * 1024; // 16 MiB

// ── Request (CLI → Daemon) ──────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "cmd", content = "args")]
pub enum Request {
    // ── Wallpaper ────────────────────────────────────────────────────────
    WpSet(WpSetRequest),
    WpRandom(WpRandomRequest),
    WpSearch(WpSearchRequest),
    WpIndex(WpIndexRequest),
    WpClear {
        monitor: Option<String>,
    },
    WpCurrent {
        monitor: Option<String>,
    },
    WpPlay {
        monitor: Option<String>,
    },
    WpPause {
        monitor: Option<String>,
    },
    WpToggleMute {
        monitor: Option<String>,
    },
    WpToggleHidden {
        path: String,
    },

    // ── History ──────────────────────────────────────────────────────────
    HistoryList {
        limit: usize,
    },
    HistoryPrev,
    HistoryNext,
    HistoryClear,

    // ── Favorites ────────────────────────────────────────────────────────
    FavAdd {
        path: Option<PathBuf>,
    },
    FavRm {
        target: String,
    },
    FavList {
        limit: usize,
    },
    FavSetRandom(DisplayOpts),

    // ── Theme ────────────────────────────────────────────────────────────
    ThemeGenerate {
        path: PathBuf,
    },
    ThemeModeSet {
        mode: String,
    },
    ThemeModeToggle,
    ThemeModeAuto,
    ThemeModeCurrent,
    ThemePaletteSet {
        variant: String,
    },
    ThemePaletteList,
    ThemePaletteCurrent,

    // ── Config / Profiles ────────────────────────────────────────────────
    ProfileSave {
        name: String,
    },
    ProfileLoad {
        name: String,
    },
    ProfileList,
    ProfileRm {
        name: String,
    },
    ConfigEdit,

    // ── Monitor ──────────────────────────────────────────────────────────
    MonitorList,
    MonitorIdentify,

    // ── Daemon ───────────────────────────────────────────────────────────
    DaemonStatus,
    DaemonStop,
    DaemonPauseAll,
    DaemonResumeAll,
    SlideshowStart(SlideshowStartRequest),
    SlideshowStop {
        monitor: Option<String>,
    },

    /// Heartbeat / liveness check
    Ping,
}

// ── Request payloads ────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DisplayOpts {
    pub monitor: Option<String>,
    pub mode: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MediaOpts {
    pub mute: bool,
    pub volume: Option<u8>,
    pub no_theme: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WpSetRequest {
    pub path: String,
    pub display: DisplayOpts,
    pub media: MediaOpts,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WpRandomRequest {
    pub dir: PathBuf,
    pub media_type: Option<String>,
    pub recursive: bool,
    pub query: Option<String>,
    pub include_dot: bool,
    pub only_dot: bool,
    pub display: DisplayOpts,
    pub media: MediaOpts,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WpSearchRequest {
    pub query: String,
    pub limit: usize,
    #[serde(default)]
    pub history: bool,
    #[serde(default)]
    pub favorites: bool,
    #[serde(default)]
    pub include_dot: bool,
    #[serde(default)]
    pub only_dot: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WpIndexRequest {
    pub dir: PathBuf,
    pub force: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SlideshowStartRequest {
    pub dir: PathBuf,
    pub interval: u64,
    pub monitor: Option<String>,
    pub media_type: Option<String>,
    pub include_dot: bool,
    pub only_dot: bool,
    pub query: Option<String>,
}

// ── Response (Daemon → CLI) ─────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "status", content = "data")]
pub enum Response {
    /// Command executed successfully, optional payload
    Ok(ResponsePayload),

    /// Something went wrong
    Err { message: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", content = "value")]
pub enum ResponsePayload {
    /// No data to return (ack)
    Empty,

    /// Arbitrary text (human-readable)
    Text(String),

    /// Raw JSON value (for --json passthrough to QML)
    Json(serde_json::Value),

    /// Wallpaper state for `wp current`
    WallpaperState(Vec<MonitorWallpaperState>),

    /// Monitor listing
    Monitors(Vec<MonitorInfo>),

    /// Search results
    SearchResults(Vec<SearchResultEntry>),

    /// History listing
    History(Vec<HistoryEntry>),

    /// Favorites listing
    Favorites(Vec<FavoriteEntry>),

    /// Profile names
    Profiles(Vec<String>),

    /// Palette variant names
    PaletteVariants(Vec<String>),

    /// Daemon status blob
    DaemonStatus(DaemonStatusInfo),

    /// Pong
    Pong,
}

// ── Response data types ─────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MonitorWallpaperState {
    pub monitor: String,
    pub path: Option<String>,
    pub media_type: String, // "image" | "video" | "gif" | "web"
    pub mode: String,
    pub offset_x: f64,
    pub offset_y: f64,
    pub muted: bool,
    pub volume: u8,
    pub paused: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MonitorInfo {
    pub name: String,
    pub width: u32,
    pub height: u32,
    pub x: i32,
    pub y: i32,
    pub scale: f64,
    pub active_workspace: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResultEntry {
    pub id: i64,
    pub path: String,
    pub name: String,
    pub media_type: String,
    pub tags: Vec<String>,
    pub dominant_color: Option<String>,
    pub is_fav: bool,
    pub score: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HistoryEntry {
    pub id: i64,
    pub path: String,
    pub timestamp: String,
    pub monitor: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FavoriteEntry {
    pub id: i64,
    pub path: String,
    pub added_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DaemonStatusInfo {
    pub uptime_secs: u64,
    pub memory_mb: f64,
    pub slideshow_active: bool,
    pub slideshow_interval: Option<u64>,
    pub ai_indexing: bool,
    pub ai_queue_size: usize,
    pub game_mode: bool,
    pub monitors: usize,
}

// ── Framing helpers (length-prefixed JSON) ──────────────────────────────────

pub mod framing {
    use super::MAX_MESSAGE_SIZE;
    use anyhow::{bail, Context, Result};
    use serde::{de::DeserializeOwned, Serialize};
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    /// Write a length-prefixed JSON message to an async writer.
    pub async fn write_message<W, T>(writer: &mut W, msg: &T) -> Result<()>
    where
        W: AsyncWriteExt + Unpin,
        T: Serialize,
    {
        let payload = serde_json::to_vec(msg).context("serialize message")?;
        let len = payload.len() as u32;
        writer
            .write_all(&len.to_le_bytes())
            .await
            .context("write length")?;
        writer
            .write_all(&payload)
            .await
            .context("write payload")?;
        writer.flush().await.context("flush")?;
        Ok(())
    }

    /// Read a length-prefixed JSON message from an async reader.
    pub async fn read_message<R, T>(reader: &mut R) -> Result<T>
    where
        R: AsyncReadExt + Unpin,
        T: DeserializeOwned,
    {
        let mut len_buf = [0u8; 4];
        reader
            .read_exact(&mut len_buf)
            .await
            .context("read length")?;
        let len = u32::from_le_bytes(len_buf) as usize;

        if len > MAX_MESSAGE_SIZE {
            bail!(
                "message too large: {len} bytes (max {MAX_MESSAGE_SIZE})"
            );
        }

        let mut buf = vec![0u8; len];
        reader
            .read_exact(&mut buf)
            .await
            .context("read payload")?;

        serde_json::from_slice(&buf).context("deserialize message")
    }
}
