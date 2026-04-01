//! Background wallpaper indexer: watches directories for new/changed files,
//! scans them, extracts dominant colors via Matugen, and upserts records
//! into SQLite.
//!
//! Architecture:
//!   - A `notify` filesystem watcher detects Create/Modify events and
//!     feeds file paths into an async mpsc channel (the "queue").
//!   - On startup (or `--force`), an initial `walkdir` scan pushes every
//!     supported file into the same channel.
//!   - A consumer task pulls paths from the channel, runs the processing
//!     pipeline (media detection → optional ffmpeg frame extraction →
//!     matugen dominant color → DB upsert), and respects pause/shutdown.
//!
//! The indexer is designed to run as a long-lived background task inside
//! the daemon process.

#[cfg(unix)] // added by me
use libc; // added by me
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::Duration;

use anyhow::{Context, Result};
use tokio::sync::{broadcast, mpsc, Notify};
use tracing::{debug, error, info, warn};
use walkdir::WalkDir;

use crate::daemon::matugen;
use crate::db::Db;

// ── Constants ───────────────────────────────────────────────────────────────

/// Max number of paths that can be buffered in the processing queue.
const QUEUE_CAPACITY: usize = 4096;

/// Delay between processing items to avoid hammering CPU/disk.
const THROTTLE_MS: u64 = 100;

/// How long to wait after a notify event before processing, to let
/// writes settle (debounce).
const DEBOUNCE_MS: u64 = 500;

// ── Public types ────────────────────────────────────────────────────────────

/// Shared indexer state, accessible from the daemon for status queries
/// and pause/resume control.
pub struct IndexerState {
    /// Number of files waiting to be processed.
    pub queue_size: AtomicUsize,

    /// Whether the indexer consumer is actively processing files.
    pub active: AtomicBool,

    /// Whether the indexer has been frozen (game mode / pause-all).
    pub paused: AtomicBool,

    /// Notify token to wake the consumer when unpaused.
    resume_notify: Notify,
}

impl IndexerState {
    pub fn new() -> Self {
        Self {
            queue_size: AtomicUsize::new(0),
            active: AtomicBool::new(false),
            paused: AtomicBool::new(false),
            resume_notify: Notify::new(),
        }
    }

    /// Pause the indexer (game mode). The consumer will finish its current
    /// item then sleep until resumed.
    pub fn pause(&self) {
        if !self.paused.swap(true, Ordering::SeqCst) {
            info!("indexer: paused");
        }
    }

    /// Resume the indexer after a pause.
    pub fn resume(&self) {
        if self.paused.swap(false, Ordering::SeqCst) {
            info!("indexer: resumed");
            self.resume_notify.notify_waiters();
        }
    }

    /// Whether the indexer is paused.
    pub fn is_paused(&self) -> bool {
        self.paused.load(Ordering::Relaxed)
    }

    /// Whether the consumer is actively processing.
    pub fn is_active(&self) -> bool {
        self.active.load(Ordering::Relaxed)
    }

    /// Current queue depth.
    pub fn pending(&self) -> usize {
        self.queue_size.load(Ordering::Relaxed)
    }

    /// Wait until the indexer is unpaused.
    async fn wait_if_paused(&self) {
        while self.paused.load(Ordering::SeqCst) {
            debug!("indexer: consumer sleeping (paused)");
            self.resume_notify.notified().await;
        }
    }
}

// ── Watcher + Scanner ───────────────────────────────────────────────────────

/// Start watching `dir` for filesystem changes and process files.
///
/// This spawns two tasks:
///  1. A **scanner** that does an initial `walkdir` sweep and pushes
///     all supported files into the queue.
///  2. A **watcher** (`notify` crate) that monitors `dir` recursively
///     and pushes new/modified files into the same queue.
///
/// Plus one **consumer** task that pulls from the queue and runs the
/// processing pipeline.
///
/// All tasks exit when `shutdown_rx` fires.
pub fn start_indexer(
    db: Arc<Db>,
    dir: PathBuf,
    force: bool,
    state: Arc<IndexerState>,
    shutdown_tx: broadcast::Sender<()>,
) -> tokio::task::JoinHandle<()> {
    let (tx, rx) = mpsc::channel::<PathBuf>(QUEUE_CAPACITY);

    state.active.store(true, Ordering::SeqCst);

    // ── Consumer task ───────────────────────────────────────────────
    let consumer_state = Arc::clone(&state);
    let consumer_db = Arc::clone(&db);
    let consumer_shutdown = shutdown_tx.subscribe();
    let consumer_handle = tokio::spawn(consumer_loop(
        consumer_db,
        rx,
        consumer_state,
        consumer_shutdown,
    ));

    // ── Scanner + Watcher combined task ─────────────────────────────
    let combined_state = Arc::clone(&state);
    let combined_shutdown = shutdown_tx.subscribe();

    tokio::spawn(async move {
        // 1. Initial scan
        info!(
            "indexer: starting initial scan of {} (force={})",
            dir.display(),
            force
        );
        if let Err(e) = initial_scan(
            &dir,
            force,
            &db,
            &tx,
            Arc::clone(&combined_state),
        )
        .await
        {
            error!("indexer: initial scan failed: {e:#}");
        }

        // 2. Start filesystem watcher
        info!("indexer: starting filesystem watcher on {}", dir.display());
        if let Err(e) = run_watcher(
            &dir,
            tx,
            combined_state.clone(),
            combined_shutdown,
        )
        .await
        {
            // Don't log as error if it's a shutdown
            let msg = format!("{e}");
            if msg.contains("shutdown") {
                info!("indexer: watcher stopped (shutdown)");
            } else {
                error!("indexer: watcher error: {e:#}");
            }
        }

        // Wait for consumer to finish
        combined_state.active.store(false, Ordering::SeqCst);
        let _ = consumer_handle.await;
        info!("indexer: all tasks stopped for {}", dir.display());
    })
}

/// Walk the directory tree and push every supported file into the queue.
/// Skips files already in the DB unless `force` is true.
async fn initial_scan(
    dir: &Path,
    force: bool,
    db: &Arc<Db>,
    tx: &mpsc::Sender<PathBuf>,
    state: Arc<IndexerState>,
) -> Result<()> {
    let dir = dir.to_path_buf();
    let db = Arc::clone(db);
    let tx = tx.clone();

    let count = tokio::task::spawn_blocking(move || -> Result<u64> {
        let mut count = 0u64;
        let mut skipped = 0u64;

        for entry in WalkDir::new(&dir)
            .follow_links(true)
            .into_iter()
            .filter_entry(|e| {
                // Skip hidden directories (but not hidden files — those
                // are handled per-file below)
                if e.file_type().is_dir() {
                    let name = e.file_name().to_string_lossy();
                    // Always enter the root dir even if it starts with '.'
                    if e.depth() == 0 {
                        return true;
                    }
                    return !name.starts_with('.');
                }
                true
            })
        {
            let entry = match entry {
                Ok(e) => e,
                Err(e) => {
                    debug!("indexer: walkdir error: {e}");
                    continue;
                }
            };

            if !entry.file_type().is_file() {
                continue;
            }

            let path = entry.path();

            if !is_supported_file(path) {
                continue;
            }

            // Skip if already indexed (unless force)
            if !force {
                let path_str = path.to_string_lossy().to_string();
                if let Ok(true) = db.wallpaper_exists(&path_str) {
                    skipped += 1;
                    continue;
                }
            }

            if tx.blocking_send(path.to_path_buf()).is_err() {
                // Channel closed — consumer shut down
                debug!("indexer: scan aborted (channel closed)");
                break;
            }

            state.queue_size.fetch_add(1, Ordering::Relaxed);
            count += 1;
        }

        info!(
            "indexer: initial scan complete — {count} queued, {skipped} skipped (already indexed)"
        );
        Ok(count)
    })
    .await
    .context("initial scan task panicked")??;

    debug!("indexer: initial scan pushed {count} files into queue");
    Ok(())
}

/// Run the `notify` filesystem watcher. Blocks until shutdown.
async fn run_watcher(
    dir: &Path,
    tx: mpsc::Sender<PathBuf>,
    state: Arc<IndexerState>,
    mut shutdown_rx: broadcast::Receiver<()>,
) -> Result<()> {
    use notify::{Config, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};

    let (notify_tx, mut notify_rx) = mpsc::channel::<Event>(256);

    let mut watcher = RecommendedWatcher::new(
        move |res: Result<Event, notify::Error>| {
            match res {
                Ok(event) => {
                    let _ = notify_tx.blocking_send(event);
                }
                Err(e) => {
                    warn!("indexer: notify error: {e}");
                }
            }
        },
        Config::default()
            .with_poll_interval(Duration::from_secs(2)),
    )
    .context("create filesystem watcher")?;

    watcher
        .watch(dir, RecursiveMode::Recursive)
        .with_context(|| format!("watch directory: {}", dir.display()))?;

    info!("indexer: filesystem watcher active on {}", dir.display());

    // Debounce: collect events, then process unique paths
    let mut pending_paths: std::collections::HashSet<PathBuf> = std::collections::HashSet::new();
    let debounce = tokio::time::sleep(Duration::from_millis(DEBOUNCE_MS));
    tokio::pin!(debounce);

    loop {
        tokio::select! {
            // Filesystem event
            Some(event) = notify_rx.recv() => {
                match event.kind {
                    EventKind::Create(_) | EventKind::Modify(_) => {
                        for path in event.paths {
                            if path.is_file() && is_supported_file(&path) {
                                pending_paths.insert(path);
                            }
                        }
                        // Reset debounce timer
                        debounce.as_mut().reset(tokio::time::Instant::now() + Duration::from_millis(DEBOUNCE_MS));
                    }
                    _ => {}
                }
            }

            // Debounce timer fired — flush pending paths to queue
            () = &mut debounce => {
                if !pending_paths.is_empty() {
                    let batch_size = pending_paths.len();
                    debug!("indexer: debounce fired, flushing {batch_size} paths to queue");

                    for path in pending_paths.drain() {
                        if tx.send(path).await.is_err() {
                            debug!("indexer: watcher channel closed");
                            return Ok(());
                        }
                        state.queue_size.fetch_add(1, Ordering::Relaxed);
                    }
                }
                // Reset to far future (will be re-armed on next event)
                debounce.as_mut().reset(tokio::time::Instant::now() + Duration::from_secs(86400));
            }

            // Shutdown
            _ = shutdown_rx.recv() => {
                info!("indexer: watcher received shutdown signal");
                return Ok(());
            }
        }
    }
}

// ── Consumer ────────────────────────────────────────────────────────────────

/// Consumer loop: pulls file paths from the queue and processes each one
/// through the indexing pipeline.
// async fn consumer_loop(
//     db: Arc<Db>,
//     mut rx: mpsc::Receiver<PathBuf>,
//     state: Arc<IndexerState>,
//     mut shutdown_rx: broadcast::Receiver<()>,
// ) {
//     info!("indexer: consumer started");

//     // УСКОРЕНИЕ 3: Переводим поток в режим Background Priority (nice 19)
//     // Это гарантирует, что индексация НИКОГДА не вызовет лагов в системе
//     tokio::task::spawn_blocking(|| {
//         #[cfg(unix)]
//         unsafe {
//             libc::setpriority(libc::PRIO_PROCESS, 0, 19);
//         }
//     }).await.ok();

//     loop {
//         state.wait_if_paused().await;

//         tokio::select! {
//             Some(path) = rx.recv() => {
//                 state.queue_size.fetch_sub(1, Ordering::Relaxed);
//                 state.wait_if_paused().await;

//                 if let Err(e) = process_file(&db, &path).await {
//                     debug!("indexer: failed to process {}: {e:#}", path.display());
//                 }

//                 // Throttle to avoid hammering disk IO
//                 tokio::time::sleep(Duration::from_millis(THROTTLE_MS)).await;
//             }

//             _ = shutdown_rx.recv() => {
//                 info!("indexer: consumer received shutdown signal");
//                 break;
//             }

//             else => {
//                 debug!("indexer: queue exhausted, consumer exiting");
//                 break;
//             }
//         }
//     }
//     info!("indexer: consumer stopped");
// }
async fn consumer_loop(
    db: Arc<Db>,
    mut rx: mpsc::Receiver<PathBuf>,
    state: Arc<IndexerState>,
    mut shutdown_rx: broadcast::Receiver<()>,
) {
    info!("indexer: consumer started");

    loop {
        // Wait if paused
        state.wait_if_paused().await;

        tokio::select! {
            Some(path) = rx.recv() => {
                state.queue_size.fetch_sub(1, Ordering::Relaxed);

                // Check pause again before processing
                state.wait_if_paused().await;

                if let Err(e) = process_file(&db, &path).await {
                    debug!("indexer: failed to process {}: {e:#}", path.display());
                }

                // Throttle to avoid hammering
                tokio::time::sleep(Duration::from_millis(THROTTLE_MS)).await;
            }

            _ = shutdown_rx.recv() => {
                info!("indexer: consumer received shutdown signal");
                break;
            }

            else => {
                // Channel closed and empty
                debug!("indexer: queue exhausted, consumer exiting");
                break;
            }
        }
    }

    info!("indexer: consumer stopped");
}

/// Process a single file through the indexing pipeline:
///   1. Determine media type
///   2. Get file metadata (size)
///   3. If video/gif → extract first frame via ffmpeg
///   4. Extract dominant color via matugen
///   5. Upsert into SQLite
async fn process_file(db: &Arc<Db>, path: &Path) -> Result<()> {
    let media_type = media_type_for(path);
    let path_str = path.to_string_lossy().to_string();

    debug!("indexer: processing [{media_type}] {path_str}");

    // File metadata
    let metadata = tokio::fs::metadata(path).await.ok();
    let file_size = metadata.as_ref().map(|m| m.len());

    // Extract dominant color via matugen pipeline
    let dominant_color = extract_color(path, media_type).await;

    // Upsert into DB (sync operation → spawn_blocking)
    let db = Arc::clone(db);
    let dc = dominant_color.clone();

    tokio::task::spawn_blocking(move || {
        match db.upsert_wallpaper(
            &path_str,
            media_type,
            dc.as_deref(),
            None, // width — could use image crate
            None, // height
            file_size,
        ) {
            Ok(id) => {
                debug!(
                    "indexer: upserted [{id}] {path_str} color={:?}",
                    dc
                );
            }
            Err(e) => {
                warn!("indexer: DB upsert failed for {path_str}: {e}");
            }
        }
    })
    .await
    .context("DB upsert task panicked")?;

    Ok(())
}

/// Try to extract the dominant/source color from a file.
///
/// For images: run matugen directly.
/// For video/gif: extract first frame via ffmpeg, then run matugen on the frame.
///
/// Returns `None` on any error (non-fatal for indexing).
// async fn extract_color(path: &Path, media_type: &str) -> Option<String> {
//     // В фоне используем наши новые быстрые функции: thumbnail или ffmpeg 128x128
//     let image_path: PathBuf = match media_type {
//         "video" | "gif" => {
//             match matugen::extract_first_frame(path).await {
//                 Ok(frame) => frame,
//                 Err(_) => return None,
//             }
//         }
//         "image" => {
//             match matugen::create_thumbnail(path).await {
//                 Ok(thumb) => thumb,
//                 Err(_) => path.to_path_buf(),
//             }
//         }
//         _ => return None,
//     };

//     let opts = matugen::MatugenOptions::default();
//     let result = matugen::generate_scheme(&image_path, &opts, None).await;

//     // Удаляем миниатюру после того, как вытащили из нее цвет
//     if image_path != path {
//         tokio::fs::remove_file(&image_path).await.ok();
//     }

//     result.ok().map(|scheme| scheme.source_color)
// }

async fn extract_color(path: &Path, media_type: &str) -> Option<String> {
    let image_path: PathBuf = match media_type {
        "video" | "gif" => {
            match matugen::extract_first_frame(path).await {
                Ok(frame) => frame,
                Err(e) => {
                    debug!(
                        "indexer: ffmpeg frame extraction failed for {}: {e}",
                        path.display()
                    );
                    return None;
                }
            }
        }
        "image" => path.to_path_buf(),
        _ => return None,
    };

    // Run matugen to get source_color
    let opts = matugen::MatugenOptions::default();
    let result = matugen::generate_scheme(&image_path, &opts).await;

    // Clean up temp frame if we extracted one
    if media_type == "video" || media_type == "gif" {
        if let Err(e) = tokio::fs::remove_file(&image_path).await {
            debug!("indexer: failed to clean up temp frame: {e}");
        }
    }

    match result {
        Ok(scheme) => Some(scheme.source_color),
        Err(e) => {
            debug!(
                "indexer: matugen failed for {}: {e}",
                path.display()
            );
            None
        }
    }
}

// ── Media type / extension helpers ──────────────────────────────────────────

const IMAGE_EXTS: &[&str] = &[
    "png", "jpg", "jpeg", "webp", "bmp", "tiff", "tif", "avif", "heic", "heif",
];

const VIDEO_EXTS: &[&str] = &[
    "mp4", "mkv", "webm", "avi", "mov", "wmv", "flv", "m4v",
];

const GIF_EXTS: &[&str] = &["gif"];

/// Returns `true` if `path` looks like a supported wallpaper file
/// based on extension.
pub fn is_supported_file(path: &Path) -> bool {
    let Some(ext) = path.extension().and_then(|e| e.to_str()) else {
        return false;
    };
    let ext = ext.to_ascii_lowercase();
    let ext_str = ext.as_str();

    IMAGE_EXTS.contains(&ext_str)
        || VIDEO_EXTS.contains(&ext_str)
        || GIF_EXTS.contains(&ext_str)
}

/// Determine the broad media type string for a file path.
pub fn media_type_for(path: &Path) -> &'static str {
    let Some(ext) = path.extension().and_then(|e| e.to_str()) else {
        return "unknown";
    };

    match ext.to_ascii_lowercase().as_str() {
        "gif" => "gif",
        "mp4" | "mkv" | "webm" | "avi" | "mov" | "wmv" | "flv" | "m4v" => "video",
        "png" | "jpg" | "jpeg" | "webp" | "bmp" | "tiff" | "tif" | "avif" | "heic" | "heif" => {
            "image"
        }
        _ => "unknown",
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_supported_extensions() {
        assert!(is_supported_file(Path::new("photo.jpg")));
        assert!(is_supported_file(Path::new("photo.JPG")));
        assert!(is_supported_file(Path::new("clip.mp4")));
        assert!(is_supported_file(Path::new("anim.gif")));
        assert!(is_supported_file(Path::new("PHOTO.PNG")));
        assert!(is_supported_file(Path::new("art.avif")));
        assert!(is_supported_file(Path::new("pic.heic")));
        assert!(!is_supported_file(Path::new("readme.txt")));
        assert!(!is_supported_file(Path::new("script.sh")));
        assert!(!is_supported_file(Path::new("noext")));
        assert!(!is_supported_file(Path::new("page.html")));
        assert!(!is_supported_file(Path::new("shader.glsl")));
    }

    #[test]
    fn test_media_type_for() {
        assert_eq!(media_type_for(Path::new("a.png")), "image");
        assert_eq!(media_type_for(Path::new("a.PNG")), "image");
        assert_eq!(media_type_for(Path::new("b.mp4")), "video");
        assert_eq!(media_type_for(Path::new("c.gif")), "gif");
        assert_eq!(media_type_for(Path::new("d.txt")), "unknown");
        assert_eq!(media_type_for(Path::new("e.avif")), "image");
        assert_eq!(media_type_for(Path::new("f.mkv")), "video");
        assert_eq!(media_type_for(Path::new("noext")), "unknown");
    }

    #[test]
    fn test_indexer_state_pause_resume() {
        let state = IndexerState::new();

        assert!(!state.is_paused());
        assert!(!state.is_active());
        assert_eq!(state.pending(), 0);

        state.pause();
        assert!(state.is_paused());

        state.resume();
        assert!(!state.is_paused());

        // Double pause is idempotent
        state.pause();
        state.pause();
        assert!(state.is_paused());

        // Double resume is idempotent
        state.resume();
        state.resume();
        assert!(!state.is_paused());
    }

    #[test]
    fn test_queue_size_tracking() {
        let state = IndexerState::new();

        state.queue_size.fetch_add(5, Ordering::Relaxed);
        assert_eq!(state.pending(), 5);

        state.queue_size.fetch_sub(3, Ordering::Relaxed);
        assert_eq!(state.pending(), 2);
    }
}
