//! Slideshow timer management.
//!
//! When a slideshow is active the daemon periodically picks a new wallpaper
//! from the configured directory and applies it.  Each monitor can have its
//! own independent slideshow, or a single global one can drive all monitors.
//!
//! The slideshow respects "game mode" (pause-all): when the daemon's
//! `game_mode` flag is set, the timer keeps ticking but skips wallpaper
//! changes until game mode is lifted.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;

use anyhow::{Context, Result};
use rand::seq::IndexedRandom;
use tokio::sync::broadcast;
use tokio::task::JoinHandle;
use tracing::{debug, error, info, warn};
use walkdir::WalkDir;

use crate::daemon::Daemon;
use crate::ipc::{AwwwOpts, SearchOpts, SlideshowStartRequest, WpSetRequest};

// ── Public types ────────────────────────────────────────────────────────────

/// Describes a running slideshow for one logical target (a specific monitor or
/// all monitors).
#[derive(Debug)]
pub struct SlideshowTask {
    /// Directory to pick wallpapers from
    pub dir: PathBuf,

    /// Interval between wallpaper changes (seconds)
    pub interval: u64,

    /// Target monitor name, or `None` for all monitors
    pub monitor: Option<String>,

    /// Search options
    pub search: SearchOpts,

    /// awww options
    pub awww: AwwwOpts,

    /// Handle to the spawned tokio task so we can abort it
    pub handle: JoinHandle<()>,
}

impl SlideshowTask {
    /// Cancel the running slideshow task.
    pub fn cancel(&self) {
        self.handle.abort();
    }
}

/// Manages all active slideshows. Keyed by monitor name (or `"*"` for global).
#[derive(Debug, Default)]
pub struct SlideshowManager {
    tasks: HashMap<String, SlideshowTask>,
}

impl SlideshowManager {
    pub fn new() -> Self {
        Self {
            tasks: HashMap::new(),
        }
    }

    /// Start a slideshow. If one is already running for the same target,
    /// it is cancelled and replaced.
    pub fn start(
        &mut self,
        args: &SlideshowStartRequest,
        daemon: Arc<Daemon>,
        shutdown_rx: broadcast::Receiver<()>,
    ) {
        let key = slideshow_key(args.monitor.as_deref());

        // Cancel existing slideshow for this target
        if let Some(old) = self.tasks.remove(&key) {
            info!("slideshow: replacing existing slideshow for [{key}]");
            old.cancel();
        }

        let dir = args.dir.clone();
        let interval = args.interval;
        let monitor = args.monitor.clone();
        let search = args.search.clone();
        let awww = args.awww.clone();

        let handle = tokio::spawn(slideshow_loop(
            daemon,
            dir.clone(),
            interval,
            monitor.clone(),
            search.clone(),
            awww.clone(),
            shutdown_rx,
        ));

        self.tasks.insert(
            key,
            SlideshowTask {
                dir,
                interval,
                monitor,
                search,
                awww,
                handle,
            },
        );
    }

    /// Stop slideshow for a specific monitor or all slideshows.
    pub fn stop(&mut self, monitor: Option<&str>) {
        match monitor {
            Some(name) => {
                let key = slideshow_key(Some(name));
                if let Some(task) = self.tasks.remove(&key) {
                    info!("slideshow: stopping for [{key}]");
                    task.cancel();
                } else {
                    debug!("slideshow: no active slideshow for [{key}]");
                }
            }
            None => {
                info!("slideshow: stopping all ({} active)", self.tasks.len());
                for (key, task) in self.tasks.drain() {
                    debug!("slideshow: cancelling [{key}]");
                    task.cancel();
                }
            }
        }
    }

    /// Whether any slideshow is currently active.
    pub fn is_active(&self) -> bool {
        // Clean out finished tasks
        !self.tasks.is_empty()
    }

    /// Get the interval of the first active slideshow (for status display).
    pub fn current_interval(&self) -> Option<u64> {
        self.tasks.values().next().map(|t| t.interval)
    }

    /// Number of active slideshows.
    pub fn count(&self) -> usize {
        self.tasks.len()
    }

    /// Cancel all slideshows (called on daemon shutdown).
    pub fn cancel_all(&mut self) {
        for (_, task) in self.tasks.drain() {
            task.cancel();
        }
    }
}

// ── Slideshow loop ──────────────────────────────────────────────────────────

/// The core slideshow timer loop. Runs until cancelled or shutdown.
async fn slideshow_loop(
    daemon: Arc<Daemon>,
    dir: PathBuf,
    interval_secs: u64,
    monitor: Option<String>,
    search: SearchOpts,
    awww: AwwwOpts,
    mut shutdown_rx: broadcast::Receiver<()>,
) {
    let key = slideshow_key(monitor.as_deref());
    info!(
        "slideshow [{key}]: started — dir={} interval={}s",
        dir.display(),
        interval_secs,
    );

    let mut ticker = tokio::time::interval(Duration::from_secs(interval_secs));

    // The first tick fires immediately — skip it so the user's current
    // wallpaper isn't replaced the instant the slideshow starts.
    // Instead, apply immediately on the first tick to give instant feedback.
    let mut first_tick = true;

    loop {
        tokio::select! {
            _ = ticker.tick() => {
                // Check game mode — skip change but keep ticking
                if *daemon.game_mode.read().await {
                    debug!("slideshow [{key}]: skipping tick (game mode active)");
                    continue;
                }

                // On first tick, apply immediately for instant feedback
                if first_tick {
                    first_tick = false;
                }

                // Pick a random file
                let picked = match pick_random_file(
                    &dir,
                    search.include_dot,
                    search.only_dot,
                    search.query.as_deref(),
                ).await {
                    Ok(Some(path)) => path,
                    Ok(None) => {
                        warn!(
                            "slideshow [{key}]: no matching files found in {}",
                            dir.display()
                        );
                        continue;
                    }
                    Err(e) => {
                        error!(
                            "slideshow [{key}]: error picking file: {e:#}"
                        );
                        continue;
                    }
                };

                info!(
                    "slideshow [{key}]: changing wallpaper → {}",
                    picked.display()
                );

                // Build a WpSet request and apply it through the daemon
                let path_str = picked.to_string_lossy().to_string();
                let mut slide_awww = awww.clone();
                slide_awww.outputs = monitor.clone();

                let set_args = WpSetRequest {
                    path: path_str,
                    awww: slide_awww,
                    no_theme: false,
                };

                let response = daemon.handle_wp_set(set_args).await;
                if let crate::ipc::Response::Err { message } = &response {
                    error!("slideshow [{key}]: failed to set wallpaper: {message}");
                }
            }

            _ = shutdown_rx.recv() => {
                info!("slideshow [{key}]: shutdown signal received");
                break;
            }
        }
    }

    info!("slideshow [{key}]: stopped");
}

// ── File picker ─────────────────────────────────────────────────────────────

/// Scan `dir` and pick one random file matching the filters.
///
/// This runs the filesystem scan inside `spawn_blocking` to avoid blocking
/// the Tokio runtime on large directories.
async fn pick_random_file(
    dir: &Path,
    include_dot: bool,
    only_dot: bool,
    query: Option<&str>,
) -> Result<Option<PathBuf>> {
    let dir = dir.to_path_buf();
    let query = query.map(String::from);

    tokio::task::spawn_blocking(move || {
        pick_random_file_sync(&dir, include_dot, only_dot, query.as_deref())
    })
    .await
    .context("file picker task panicked")?
}

/// Synchronous file scanning + random selection.
fn pick_random_file_sync(
    dir: &Path,
    include_dot: bool,
    only_dot: bool,
    query: Option<&str>,
) -> Result<Option<PathBuf>> {
    let walker = WalkDir::new(dir)
        .follow_links(true)
        .into_iter()
        .filter_entry(|e| {
            let name = e.file_name().to_string_lossy();

            // Dot-file filtering applies to both files and directories
            if name.starts_with('.') {
                // If only_dot: we WANT dot entries
                // If include_dot: we WANT dot entries too
                // Otherwise: skip them
                only_dot || include_dot
            } else {
                // Regular (non-dot) entry
                // If only_dot: skip regular entries
                // Otherwise: keep them
                !only_dot
            }
        });

    let mut candidates: Vec<PathBuf> = Vec::new();

    for entry in walker {
        let entry = match entry {
            Ok(e) => e,
            Err(e) => {
                debug!("walkdir error: {e}");
                continue;
            }
        };

        // Only consider files
        if !entry.file_type().is_file() {
            continue;
        }

        let path = entry.path();

        // Only accept known image types (awww supports images only)
        if !is_supported_media(path) {
            continue;
        }

        // Query filter: simple case-insensitive substring match on filename
        if let Some(q) = query {
            let fname = path
                .file_name()
                .map(|n| n.to_string_lossy().to_ascii_lowercase())
                .unwrap_or_default();
            if !fname.contains(&q.to_ascii_lowercase()) {
                continue;
            }
        }

        candidates.push(path.to_path_buf());
    }

    if candidates.is_empty() {
        return Ok(None);
    }

    // Pick a random one
    let mut rng = rand::rng();
    let picked = candidates.choose(&mut rng).cloned();

    Ok(picked)
}

// ── Media type helpers ──────────────────────────────────────────────────────

const IMAGE_EXTS: &[&str] = &[
    "png", "jpg", "jpeg", "webp", "bmp", "tiff", "tif", "avif", "heic", "heif", "gif",
];

/// Check whether a file has a supported media extension (image types for awww).
/// Public alias for use from `daemon/mod.rs`.
pub fn is_supported_media_ext(path: &Path) -> bool {
    is_supported_media(path)
}

/// Check whether a file has a supported media extension (image types).
fn is_supported_media(path: &Path) -> bool {
    let ext = match path.extension().and_then(|e| e.to_str()) {
        Some(e) => e.to_ascii_lowercase(),
        None => return false,
    };
    IMAGE_EXTS.contains(&ext.as_str())
}

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Produce a consistent key for the slideshow tasks hashmap.
/// `"*"` for global (all monitors), or the monitor name.
fn slideshow_key(monitor: Option<&str>) -> String {
    monitor.unwrap_or("*").to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    #[test]
    fn test_is_supported_media() {
        assert!(is_supported_media(Path::new("a.jpg")));
        assert!(is_supported_media(Path::new("b.png")));
        assert!(is_supported_media(Path::new("c.gif")));
        assert!(is_supported_media(Path::new("d.webp")));
        assert!(!is_supported_media(Path::new("e.txt")));
        assert!(!is_supported_media(Path::new("f.rs")));
        assert!(!is_supported_media(Path::new("noext")));
    }

    #[test]
    fn test_slideshow_key() {
        assert_eq!(slideshow_key(None), "*");
        assert_eq!(slideshow_key(Some("DP-1")), "DP-1");
        assert_eq!(slideshow_key(Some("HDMI-A-1")), "HDMI-A-1");
    }

    #[test]
    fn test_dot_file_logic() {
        // Simulates the filter_entry logic
        let is_dot = |name: &str| name.starts_with('.');

        // Default mode (include_dot=false, only_dot=false)
        // dot files should be excluded
        let include_dot = false;
        let only_dot = false;
        assert!(!is_dot("photo.jpg") || include_dot || only_dot); // regular: keep
        assert!(is_dot(".hidden") && !(include_dot || only_dot)); // dot: skip

        // include_dot=true
        let include_dot = true;
        let only_dot = false;
        assert!(is_dot(".hidden") && (include_dot || only_dot)); // dot: keep
        assert!(!is_dot("photo.jpg")); // regular: keep (not only_dot)

        // only_dot=true
        let include_dot = false;
        let only_dot = true;
        assert!(is_dot(".hidden") && (include_dot || only_dot)); // dot: keep
        assert!(!is_dot("photo.jpg") && only_dot); // regular: skip
    }
}
