pub mod client;
pub mod server;

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Socket path: $XDG_RUNTIME_DIR/walltool.sock
pub fn socket_path() -> PathBuf {
    let runtime_dir = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| {
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

pub const MAX_MESSAGE_SIZE: usize = 16 * 1024 * 1024; // 16 MiB

// ══════════════════════════════════════════════════════════════════════════════
//  awww options (mirrored from CLI for IPC transport)
// ══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AwwwOpts {
    pub outputs: Option<String>,
    pub namespace: Option<String>,
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
    pub invert_y: bool,
}

// ══════════════════════════════════════════════════════════════════════════════
//  Search options
// ══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SearchOpts {
    pub query: Option<String>,
    pub history: bool,
    pub favorites: bool,
    pub include_dot: bool,
    pub only_dot: bool,
    pub sort_by: String, // "score", "time", "name", "color"
    pub reverse: bool,
    pub limit: usize,
}

// ══════════════════════════════════════════════════════════════════════════════
//  Matugen parameters (full state for th set/get)
// ══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MatugenParams {
    pub mode: String, // "dark" | "light"
    pub scheme_type: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub contrast: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub source_color_index: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub prefer: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fallback_color: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub opacity: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub lightness_dark: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub lightness_light: Option<f64>,
}

// ══════════════════════════════════════════════════════════════════════════════
//  Request (CLI → Daemon)
// ══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "cmd", content = "args")]
pub enum Request {
    // ── Wallpaper ────────────────────────────────────────────────────────
    WpSet(WpSetRequest),
    WpPreviewStart(WpPreviewStartRequest),
    WpPreviewStop,
    WpPreviewCommit,
    WpRandom(WpRandomRequest),
    WpSearch(WpSearchRequest),
    WpToggleHidden { path: String },
    WpOptionsSet(WpOptionsSetRequest),
    WpOptionsGet { path: Option<String> },
    WpOptionsClear { path: Option<String> },
    WpIndex(WpIndexRequest),
    WpClear(WpClearRequest),
    WpClearCache,
    WpRestore(WpRestoreRequest),

    // ── History ──────────────────────────────────────────────────────────
    HistoryList { limit: usize },
    HistoryPrev,
    HistoryNext,
    HistoryClear,

    // ── Favorites ────────────────────────────────────────────────────────
    FavAdd { path: Option<PathBuf> },
    FavRm { target: String },
    FavList { limit: usize },
    FavSetRandom(AwwwOpts),

    // ── Theme (matugen) ──────────────────────────────────────────────────
    ThemeGenerate { path: PathBuf },
    ThemeSet { param: String, value: String },
    ThemeGet,
    ThemeModeSet { mode: String },
    ThemeModeToggle,
    ThemeModeAuto,
    ThemeModeCurrent,
    ThemePaletteSet { variant: String },
    ThemePaletteList,
    ThemePaletteCurrent,

    // ── Config / Profiles ────────────────────────────────────────────────
    ConfigShow,
    ConfigSetAwwwDefault { key: String, value: String },
    ConfigGetAwwwDefaults,
    ConfigSetNamespace { value: String },
    ConfigGetNamespace,
    ConfigListMonitorConfigs,
    ConfigGetMonitorOptions { monitor: String },
    ConfigSetMonitorOption { monitor: String, key: String, value: String },
    ConfigRmMonitorOptions { monitor: String },
    ConfigGetMatugenDefaults,
    ConfigSetMatugenDefault { key: String, value: String },
    ConfigGetThemeAuto,
    ConfigSetThemeAuto { key: String, value: String },
    ConfigSetSlideshowOption { key: String, value: String },
    ConfigGetSlideshowOptions,
    ConfigGetIndexer,
    ConfigSetIndexer { key: String, value: String },
    ProfileSave { name: String },
    ProfileLoad { name: String },
    ProfileList,
    ProfileRm { name: String },
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
    SlideshowStop { monitor: Option<String> },

    Ping,
}

// ── Request payloads ────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WpSetRequest {
    pub path: String,
    pub awww: AwwwOpts,
    pub no_theme: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WpPreviewStartRequest {
    pub path: String,
    pub awww: AwwwOpts,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WpRandomRequest {
    pub dir: PathBuf,
    pub recursive: bool,
    pub search: SearchOpts,
    pub awww: AwwwOpts,
    pub no_theme: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WpSearchRequest {
    pub query: String,
    pub search: SearchOpts,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WpOptionsSetRequest {
    pub path: Option<String>,
    pub awww: AwwwOpts,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WpIndexRequest {
    pub dir: PathBuf,
    pub force: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WpClearRequest {
    pub color: Option<String>,
    pub outputs: Option<String>,
    pub namespace: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WpRestoreRequest {
    pub outputs: Option<String>,
    pub namespace: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SlideshowStartRequest {
    pub dir: PathBuf,
    pub interval: u64,
    pub monitor: Option<String>,
    pub search: SearchOpts,
    pub awww: AwwwOpts,
}

// ══════════════════════════════════════════════════════════════════════════════
//  Response (Daemon → CLI)
// ══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "status", content = "data")]
pub enum Response {
    Ok(ResponsePayload),
    Err { message: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", content = "value")]
pub enum ResponsePayload {
    Empty,
    Text(String),
    Json(serde_json::Value),
    Monitors(Vec<MonitorInfo>),
    SearchResults(Vec<SearchResultEntry>),
    History(Vec<HistoryEntry>),
    Favorites(Vec<FavoriteEntry>),
    Profiles(Vec<String>),
    PaletteVariants(Vec<String>),
    DaemonStatus(DaemonStatusInfo),
    ThemeParams(MatugenParams),
    AwwwOpts(AwwwOpts),
    SlideshowOpts(SlideshowOpts),
    // ── new ──────────────────────────────────────────────────────────────
    ConfigFull(String),                         // raw TOML text of config.toml
    MonitorConfigs(Vec<MonitorConfigEntry>),    // list of per-monitor config sections
    MonitorOpts(MonitorAwwwOpts),               // single monitor's overrides
    IndexerOpts(IndexerOptsInfo),
    ThemeAutoOpts(ThemeAutoOptsInfo),
    // ─────────────────────────────────────────────────────────────────────
    Pong,
}

/// Slideshow options for IPC transport
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SlideshowOpts {
    pub dir: Option<String>,
    pub interval: u64,
    pub include_hidden: bool,
    pub only_hidden: bool,
    pub only_favorites: bool,
    pub text_filter: Option<String>,
}

// ── Config extended data types ───────────────────────────────────────────────

/// One row in the per-monitor config list
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MonitorConfigEntry {
    pub monitor: String,
    pub options: MonitorAwwwOpts,
}

/// Flat representation of per-monitor awww overrides (all optional)
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MonitorAwwwOpts {
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

/// Indexer configuration for IPC transport
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IndexerOptsInfo {
    pub watch_dirs: Vec<String>,
    pub ai_tagging: bool,
}

/// Theme auto-mode schedule
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThemeAutoOptsInfo {
    pub sunrise: String,
    pub sunset: String,
}

// ── Response data types ─────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MonitorInfo {
    pub name: String,
    pub width: u32,
    pub height: u32,
    pub x: i32,
    pub y: i32,
    pub scale: f64,
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
    pub indexing: bool,
    pub index_queue_size: usize,
    pub game_mode: bool,
    pub preview_active: bool,
}

// ══════════════════════════════════════════════════════════════════════════════
//  Framing helpers (length-prefixed JSON)
// ══════════════════════════════════════════════════════════════════════════════

pub mod framing {
    use super::MAX_MESSAGE_SIZE;
    use anyhow::{bail, Context, Result};
    use serde::{de::DeserializeOwned, Serialize};
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    pub async fn write_message<W, T>(writer: &mut W, msg: &T) -> Result<()>
    where
        W: AsyncWriteExt + Unpin,
        T: Serialize,
    {
        let payload = serde_json::to_vec(msg).context("serialize message")?;
        let len = payload.len() as u32;
        writer.write_all(&len.to_le_bytes()).await.context("write length")?;
        writer.write_all(&payload).await.context("write payload")?;
        writer.flush().await.context("flush")?;
        Ok(())
    }

    pub async fn read_message<R, T>(reader: &mut R) -> Result<T>
    where
        R: AsyncReadExt + Unpin,
        T: DeserializeOwned,
    {
        let mut len_buf = [0u8; 4];
        reader.read_exact(&mut len_buf).await.context("read length")?;
        let len = u32::from_le_bytes(len_buf) as usize;

        if len > MAX_MESSAGE_SIZE {
            bail!("message too large: {len} bytes (max {MAX_MESSAGE_SIZE})");
        }

        let mut buf = vec![0u8; len];
        reader.read_exact(&mut buf).await.context("read payload")?;
        serde_json::from_slice(&buf).context("deserialize message")
    }
}

// pub mod client;
// pub mod server;

// use serde::{Deserialize, Serialize};
// use std::path::PathBuf;

// /// Socket path: $XDG_RUNTIME_DIR/walltool.sock
// pub fn socket_path() -> PathBuf {
//     let runtime_dir = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| {
//         let uid = std::fs::read_to_string("/proc/self/status")
//             .ok()
//             .and_then(|s| {
//                 s.lines()
//                     .find(|l| l.starts_with("Uid:"))
//                     .and_then(|l| l.split_whitespace().nth(1))
//                     .and_then(|v| v.parse::<u32>().ok())
//             })
//             .unwrap_or(1000);
//         format!("/run/user/{uid}")
//     });
//     PathBuf::from(runtime_dir).join("walltool.sock")
// }

// pub const MAX_MESSAGE_SIZE: usize = 16 * 1024 * 1024; // 16 MiB

// // ══════════════════════════════════════════════════════════════════════════════
// //  awww options (mirrored from CLI for IPC transport)
// // ══════════════════════════════════════════════════════════════════════════════

// #[derive(Debug, Clone, Default, Serialize, Deserialize)]
// pub struct AwwwOpts {
//     pub outputs: Option<String>,
//     pub namespace: Option<String>,
//     pub resize: Option<String>,
//     pub fill_color: Option<String>,
//     pub filter: Option<String>,
//     pub transition_type: Option<String>,
//     pub transition_step: Option<u8>,
//     pub transition_duration: Option<f64>,
//     pub transition_fps: Option<u32>,
//     pub transition_angle: Option<f64>,
//     pub transition_pos: Option<String>,
//     pub transition_bezier: Option<String>,
//     pub transition_wave: Option<String>,
//     pub invert_y: bool,
// }

// // ══════════════════════════════════════════════════════════════════════════════
// //  Search options
// // ══════════════════════════════════════════════════════════════════════════════

// #[derive(Debug, Clone, Default, Serialize, Deserialize)]
// pub struct SearchOpts {
//     pub query: Option<String>,
//     pub history: bool,
//     pub favorites: bool,
//     pub include_dot: bool,
//     pub only_dot: bool,
//     pub sort_by: String, // "score", "time", "name", "color"
//     pub reverse: bool,
//     pub limit: usize,
// }

// // ══════════════════════════════════════════════════════════════════════════════
// //  Matugen parameters (full state for th set/get)
// // ══════════════════════════════════════════════════════════════════════════════

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct MatugenParams {
//     pub mode: String, // "dark" | "light"
//     pub scheme_type: String,
//     #[serde(skip_serializing_if = "Option::is_none")]
//     pub contrast: Option<f64>,
//     #[serde(skip_serializing_if = "Option::is_none")]
//     pub source_color_index: Option<u8>,
//     #[serde(skip_serializing_if = "Option::is_none")]
//     pub prefer: Option<String>,
//     #[serde(skip_serializing_if = "Option::is_none")]
//     pub fallback_color: Option<String>,
//     #[serde(skip_serializing_if = "Option::is_none")]
//     pub opacity: Option<f64>,
//     #[serde(skip_serializing_if = "Option::is_none")]
//     pub lightness_dark: Option<f64>,
//     #[serde(skip_serializing_if = "Option::is_none")]
//     pub lightness_light: Option<f64>,
// }

// // ══════════════════════════════════════════════════════════════════════════════
// //  Request (CLI → Daemon)
// // ══════════════════════════════════════════════════════════════════════════════

// #[derive(Debug, Clone, Serialize, Deserialize)]
// #[serde(tag = "cmd", content = "args")]
// pub enum Request {
//     // ── Wallpaper ────────────────────────────────────────────────────────
//     WpSet(WpSetRequest),
//     WpPreviewStart(WpPreviewStartRequest),
//     WpPreviewStop,
//     WpPreviewCommit,
//     WpRandom(WpRandomRequest),
//     WpSearch(WpSearchRequest),
//     WpToggleHidden { path: String },
//     WpOptionsSet(WpOptionsSetRequest),
//     WpOptionsGet { path: Option<String> },
//     WpOptionsClear { path: Option<String> },
//     WpIndex(WpIndexRequest),
//     WpClear(WpClearRequest),
//     WpClearCache,
//     WpRestore(WpRestoreRequest),

//     // ── History ──────────────────────────────────────────────────────────
//     HistoryList { limit: usize },
//     HistoryPrev,
//     HistoryNext,
//     HistoryClear,

//     // ── Favorites ────────────────────────────────────────────────────────
//     FavAdd { path: Option<PathBuf> },
//     FavRm { target: String },
//     FavList { limit: usize },
//     FavSetRandom(AwwwOpts),

//     // ── Theme (matugen) ──────────────────────────────────────────────────
//     ThemeGenerate { path: PathBuf },
//     ThemeSet { param: String, value: String },
//     ThemeGet,
//     ThemeModeSet { mode: String },
//     ThemeModeToggle,
//     ThemeModeAuto,
//     ThemeModeCurrent,
//     ThemePaletteSet { variant: String },
//     ThemePaletteList,
//     ThemePaletteCurrent,

//     // ── Config / Profiles ────────────────────────────────────────────────
//     ConfigSetAwwwDefault { key: String, value: String },
//     ConfigGetAwwwDefaults,
//     ConfigSetSlideshowOption { key: String, value: String },
//     ConfigGetSlideshowOptions,
//     ProfileSave { name: String },
//     ProfileLoad { name: String },
//     ProfileList,
//     ProfileRm { name: String },
//     ConfigEdit,

//     // ── Monitor ──────────────────────────────────────────────────────────
//     MonitorList,
//     MonitorIdentify,

//     // ── Daemon ───────────────────────────────────────────────────────────
//     DaemonStatus,
//     DaemonStop,
//     DaemonPauseAll,
//     DaemonResumeAll,
//     SlideshowStart(SlideshowStartRequest),
//     SlideshowStop { monitor: Option<String> },

//     Ping,
// }

// // ── Request payloads ────────────────────────────────────────────────────────

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct WpSetRequest {
//     pub path: String,
//     pub awww: AwwwOpts,
//     pub no_theme: bool,
// }

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct WpPreviewStartRequest {
//     pub path: String,
//     pub awww: AwwwOpts,
// }

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct WpRandomRequest {
//     pub dir: PathBuf,
//     pub recursive: bool,
//     pub search: SearchOpts,
//     pub awww: AwwwOpts,
//     pub no_theme: bool,
// }

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct WpSearchRequest {
//     pub query: String,
//     pub search: SearchOpts,
// }

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct WpOptionsSetRequest {
//     pub path: Option<String>,
//     pub awww: AwwwOpts,
// }

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct WpIndexRequest {
//     pub dir: PathBuf,
//     pub force: bool,
// }

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct WpClearRequest {
//     pub color: Option<String>,
//     pub outputs: Option<String>,
//     pub namespace: Option<String>,
// }

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct WpRestoreRequest {
//     pub outputs: Option<String>,
//     pub namespace: Option<String>,
// }

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct SlideshowStartRequest {
//     pub dir: PathBuf,
//     pub interval: u64,
//     pub monitor: Option<String>,
//     pub search: SearchOpts,
//     pub awww: AwwwOpts,
// }

// // ══════════════════════════════════════════════════════════════════════════════
// //  Response (Daemon → CLI)
// // ══════════════════════════════════════════════════════════════════════════════

// #[derive(Debug, Clone, Serialize, Deserialize)]
// #[serde(tag = "status", content = "data")]
// pub enum Response {
//     Ok(ResponsePayload),
//     Err { message: String },
// }

// #[derive(Debug, Clone, Serialize, Deserialize)]
// #[serde(tag = "kind", content = "value")]
// pub enum ResponsePayload {
//     Empty,
//     Text(String),
//     Json(serde_json::Value),
//     Monitors(Vec<MonitorInfo>),
//     SearchResults(Vec<SearchResultEntry>),
//     History(Vec<HistoryEntry>),
//     Favorites(Vec<FavoriteEntry>),
//     Profiles(Vec<String>),
//     PaletteVariants(Vec<String>),
//     DaemonStatus(DaemonStatusInfo),
//     ThemeParams(MatugenParams),
//     AwwwOpts(AwwwOpts),
//     SlideshowOpts(SlideshowOpts),
//     Pong,
// }

// /// Slideshow options for IPC transport
// #[derive(Debug, Clone, Default, Serialize, Deserialize)]
// pub struct SlideshowOpts {
//     pub dir: Option<String>,
//     pub interval: u64,
//     pub include_hidden: bool,
//     pub only_hidden: bool,
//     pub only_favorites: bool,
//     pub text_filter: Option<String>,
// }

// // ── Response data types ─────────────────────────────────────────────────────

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct MonitorInfo {
//     pub name: String,
//     pub width: u32,
//     pub height: u32,
//     pub x: i32,
//     pub y: i32,
//     pub scale: f64,
// }

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct SearchResultEntry {
//     pub id: i64,
//     pub path: String,
//     pub name: String,
//     pub media_type: String,
//     pub tags: Vec<String>,
//     pub dominant_color: Option<String>,
//     pub is_fav: bool,
//     pub score: f64,
// }

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct HistoryEntry {
//     pub id: i64,
//     pub path: String,
//     pub timestamp: String,
//     pub monitor: Option<String>,
// }

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct FavoriteEntry {
//     pub id: i64,
//     pub path: String,
//     pub added_at: String,
// }

// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct DaemonStatusInfo {
//     pub uptime_secs: u64,
//     pub memory_mb: f64,
//     pub slideshow_active: bool,
//     pub slideshow_interval: Option<u64>,
//     pub indexing: bool,
//     pub index_queue_size: usize,
//     pub game_mode: bool,
//     pub preview_active: bool,
// }

// // ══════════════════════════════════════════════════════════════════════════════
// //  Framing helpers (length-prefixed JSON)
// // ══════════════════════════════════════════════════════════════════════════════

// pub mod framing {
//     use super::MAX_MESSAGE_SIZE;
//     use anyhow::{bail, Context, Result};
//     use serde::{de::DeserializeOwned, Serialize};
//     use tokio::io::{AsyncReadExt, AsyncWriteExt};

//     pub async fn write_message<W, T>(writer: &mut W, msg: &T) -> Result<()>
//     where
//         W: AsyncWriteExt + Unpin,
//         T: Serialize,
//     {
//         let payload = serde_json::to_vec(msg).context("serialize message")?;
//         let len = payload.len() as u32;
//         writer.write_all(&len.to_le_bytes()).await.context("write length")?;
//         writer.write_all(&payload).await.context("write payload")?;
//         writer.flush().await.context("flush")?;
//         Ok(())
//     }

//     pub async fn read_message<R, T>(reader: &mut R) -> Result<T>
//     where
//         R: AsyncReadExt + Unpin,
//         T: DeserializeOwned,
//     {
//         let mut len_buf = [0u8; 4];
//         reader.read_exact(&mut len_buf).await.context("read length")?;
//         let len = u32::from_le_bytes(len_buf) as usize;

//         if len > MAX_MESSAGE_SIZE {
//             bail!("message too large: {len} bytes (max {MAX_MESSAGE_SIZE})");
//         }

//         let mut buf = vec![0u8; len];
//         reader.read_exact(&mut buf).await.context("read payload")?;
//         serde_json::from_slice(&buf).context("deserialize message")
//     }
// }
