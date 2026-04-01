pub mod hyprland;
pub mod indexer;
pub mod matugen;
pub mod monitor;
pub mod slideshow;
pub mod state;

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Instant;
use std::process::Command;

use anyhow::{Context, Result};
use tokio::sync::{broadcast, RwLock};
use tracing::{debug, info, warn};
use walkdir::WalkDir;

use crate::db::Db;
use crate::ipc::{
    DisplayOpts, FavoriteEntry, HistoryEntry, MediaOpts, Response, ResponsePayload,
    SearchResultEntry, SlideshowStartRequest, WpIndexRequest, WpRandomRequest, WpSearchRequest,
    WpSetRequest,
};

use self::indexer::IndexerState;
use self::matugen::{MatugenOptions, SchemeMode, PALETTE_VARIANTS};
use self::slideshow::SlideshowManager;
use self::state::WallpaperStateManager;

// ── Theme runtime state ─────────────────────────────────────────────────────

/// Tracks current theme mode, palette variant, and auto-mode flag.
#[derive(Debug)]
pub struct ThemeState {
    pub mode: SchemeMode,
    pub variant: String,
    pub auto_mode: bool,
}

impl Default for ThemeState {
    fn default() -> Self {
        Self {
            mode: SchemeMode::Dark,
            variant: "tonal-spot".into(),
            auto_mode: false,
        }
    }
}

/// History navigation cursor — offset into the history table.
/// 0 means "current", 1 means "one back", etc.
#[derive(Debug, Default)]
pub struct HistoryCursor {
    pub offset: usize,
}

// ── Daemon ──────────────────────────────────────────────────────────────────

/// Central daemon state.  Shared via `Arc<Daemon>` across all IPC handler
/// tasks, the slideshow loop, the Hyprland event listener, etc.
pub struct Daemon {
    /// When the daemon was started
    pub started_at: Instant,

    /// Wallpaper + theme state manager (reads/writes JSON files)
    pub state: RwLock<WallpaperStateManager>,

    /// SQLite database (thread-safe via internal Mutex)
    pub db: Arc<Db>,

    /// Slideshow manager — owns running timer tasks
    pub slideshow: RwLock<SlideshowManager>,

    /// Current theme configuration
    pub theme: RwLock<ThemeState>,

    /// History navigation cursor
    pub history_cursor: RwLock<HistoryCursor>,

    /// Shutdown signal broadcaster
    pub shutdown_tx: broadcast::Sender<()>,

    /// Whether "game mode" (pause-all) is active
    pub game_mode: RwLock<bool>,

    /// Background indexer shared state (pause/resume, queue depth)
    pub indexer_state: Arc<IndexerState>,

    /// Handles to running indexer tasks (so we can abort on shutdown)
    pub indexer_handles: RwLock<Vec<tokio::task::JoinHandle<()>>>,
}

impl Daemon {
    /// Create a new daemon instance.
    ///
    /// Opens (or creates) the SQLite database at the default path.
    /// Does NOT start the IPC server — that's done separately so the
    /// caller can hold onto the `Arc<Daemon>`.
    pub fn new(shutdown_tx: broadcast::Sender<()>) -> Result<Self> {
        let db_path = Db::default_path();
        let db = Db::open(&db_path)
            .with_context(|| format!("open database at {}", db_path.display()))?;

        Ok(Self {
            started_at: Instant::now(),
            state: RwLock::new(WallpaperStateManager::new()),
            db: Arc::new(db),
            slideshow: RwLock::new(SlideshowManager::new()),
            theme: RwLock::new(ThemeState::default()),
            history_cursor: RwLock::new(HistoryCursor::default()),
            shutdown_tx,
            game_mode: RwLock::new(false),
            indexer_state: Arc::new(IndexerState::new()),
            indexer_handles: RwLock::new(Vec::new()),
        })
    }

    // ════════════════════════════════════════════════════════════════════
    //  Wallpaper handlers
    // ════════════════════════════════════════════════════════════════════

    pub async fn handle_wp_set(&self, args: WpSetRequest) -> Response {
        // Canonicalize the path so DB, history, favorites and state all
        // reference the same absolute path.  URLs and missing files fall
        // back to the original string.
        let canonical_path = if args.path.starts_with("http://") || args.path.starts_with("https://") {
            args.path.clone()
        } else {
            std::fs::canonicalize(&args.path)
                .map(|p| p.to_string_lossy().to_string())
                .unwrap_or_else(|_| args.path.clone())
        };

        info!(
            "wp set: path={} monitor={:?} mode={}",
            canonical_path, args.display.monitor, args.display.mode
        );
        let _ = Command::new("awww")
            .arg("img")
            .arg(&canonical_path)
            .arg("-t=any")
            .arg("--transition-step=30")
            .spawn();



        // 1. Update wallpaper state JSON
        {
            let mut state = self.state.write().await;
            if let Err(e) = state
                .set_wallpaper(&canonical_path, &args.display, &args.media)
                .await
            {
                return Response::Err {
                    message: format!("failed to set wallpaper: {e:#}"),
                };
            }
        }

        // 2. Record in history (spawn_blocking because DB is sync)
        {
            let db = Arc::clone(&self.db);
            let path = canonical_path.clone();
            let monitor = args.display.monitor.clone();
            let mode = args.display.mode.clone();
            if let Err(e) = tokio::task::spawn_blocking(move || {
                db.history_push(&path, monitor.as_deref(), &mode)
            })
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")))
            {
                warn!("failed to record wallpaper in history: {e:#}");
            }
        }

        // Reset history cursor (we just set something new)
        {
            let mut cursor = self.history_cursor.write().await;
            cursor.offset = 0;
        }

        // 3. If span mode, recalculate offsets
        if args.display.mode == "span" {
            if let Err(e) = self.recalculate_span().await {
                warn!("failed to recalculate span offsets: {e:#}");
            }
        }

        // 4. Generate theme unless --no-theme
        // if !args.media.no_theme {
        //             let path = args.path.clone();
        //             let theme = self.theme.read().await;
        //             let opts = MatugenOptions {
        //                 mode: theme.mode,
        //                 variant: theme.variant.clone(),
        //             };
        //             drop(theme);

        //             let db = Arc::clone(&self.db);

        //             // Fire-and-forget
        //             tokio::spawn(async move {
        //                 // Пытаемся достать закэшированный цвет из БД
        //                 let path_clone = path.clone();
        //                 let cached_color = tokio::task::spawn_blocking(move || {
        //                     db.get_wallpaper_by_path(&path_clone)
        //                       .ok()
        //                       .flatten()
        //                       .and_then(|row| row.dominant_color)
        //                 })
        //                 .await
        //                 .unwrap_or(None);

        //                 let source = Path::new(&path);

        //                 // Передаем кэшированный цвет. Если он есть, картинка даже не откроется с диска!
        //                 match matugen::generate_scheme(source, &opts, cached_color.as_deref()).await {
        //                     Ok(scheme) => {
        //                         info!(
        //                             "theme generated: source_color={} mode={} variant={}",
        //                             scheme.source_color, scheme.mode, scheme.variant,
        //                         );
        //                     }
        //                     Err(e) => warn!("theme generation failed: {e:#}"),
        //                 }
        //             });
        //         }
        if !args.media.no_theme {
            let path = canonical_path.clone();
            let theme = self.theme.read().await;
            let opts = MatugenOptions {
                mode: theme.mode,
                variant: theme.variant.clone(),
            };
            drop(theme);

            // Fire-and-forget: theme generation can be slow, don't block IPC
            tokio::spawn(async move {
                let source = Path::new(&path);
                match matugen::generate_scheme(source, &opts).await {
                    Ok(scheme) => {
                        info!(
                            "theme generated: source_color={} mode={} variant={}",
                            scheme.source_color, scheme.mode, scheme.variant,
                        );
                    }
                    Err(e) => {
                        warn!("theme generation failed: {e:#}");
                    }
                }
            });
        }

        Response::Ok(ResponsePayload::Empty)
    }

    pub async fn handle_wp_random(&self, args: WpRandomRequest) -> Response {
        info!(
            "wp random: dir={} type={:?} recursive={} query={:?}",
            args.dir.display(),
            args.media_type,
            args.recursive,
            args.query,
        );

        // Pick a random file using the slideshow file picker
        let dir = args.dir.clone();
        let media_type = args.media_type.clone();
        let include_dot = args.include_dot;
        let only_dot = args.only_dot;
        let query = args.query.clone();

        let picked = match pick_random_file(&dir, media_type.as_deref(), include_dot, only_dot, query.as_deref()).await {
            Ok(Some(p)) => p,
            Ok(None) => {
                return Response::Err {
                    message: format!(
                        "no matching files found in {}",
                        args.dir.display()
                    ),
                };
            }
            Err(e) => {
                return Response::Err {
                    message: format!("error scanning directory: {e:#}"),
                };
            }
        };

        info!("wp random: picked {}", picked.display());

        // Delegate to wp set
        let set_args = WpSetRequest {
            path: picked.to_string_lossy().to_string(),
            display: args.display,
            media: args.media,
        };

        self.handle_wp_set(set_args).await
    }

    pub async fn handle_wp_search(&self, args: WpSearchRequest) -> Response {
        info!(
            "wp search: query={} limit={} history={} favorites={} include_dot={} only_dot={}",
            args.query, args.limit, args.history, args.favorites, args.include_dot, args.only_dot,
        );

        let db = Arc::clone(&self.db);
        let query = args.query.clone();
        let limit = args.limit;
        let history = args.history;
        let favorites = args.favorites;
        let include_dot = args.include_dot;
        let only_dot = args.only_dot;

        let result = tokio::task::spawn_blocking(move || {
            match (history, favorites) {
                (true, true) => db.search_history_favorites(&query, limit, include_dot, only_dot),
                (true, false) => db.search_history(&query, limit, include_dot, only_dot),
                (false, true) => db.search_favorites(&query, limit, include_dot, only_dot),
                (false, false) => db.search(&query, limit, include_dot, only_dot),
            }
        })
        .await
        .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")));

        match result {
            Ok(results) => {
                let entries: Vec<SearchResultEntry> = results
                    .into_iter()
                    .map(|r| {
                        let name = Path::new(&r.path)
                            .file_stem()
                            .map(|s| s.to_string_lossy().to_string())
                            .unwrap_or_default();
                        SearchResultEntry {
                            id: r.id,
                            path: r.path,
                            name,
                            media_type: r.media_type,
                            tags: r.tags,
                            dominant_color: r.dominant_color,
                            is_fav: r.is_fav,
                            score: r.score,
                        }
                    })
                    .collect();
                Response::Ok(ResponsePayload::SearchResults(entries))
            }
            Err(e) => Response::Err {
                message: format!("search failed: {e:#}"),
            },
        }
    }

    pub async fn handle_wp_index(&self, args: WpIndexRequest) -> Response {
        info!(
            "wp index: dir={} force={}",
            args.dir.display(),
            args.force
        );

        if !args.dir.is_dir() {
            return Response::Err {
                message: format!("{} is not a directory", args.dir.display()),
            };
        }

        let handle = indexer::start_indexer(
            Arc::clone(&self.db),
            args.dir.clone(),
            args.force,
            Arc::clone(&self.indexer_state),
            self.shutdown_tx.clone(),
        );

        self.indexer_handles.write().await.push(handle);

        Response::Ok(ResponsePayload::Text(format!(
            "indexing started for {}",
            args.dir.display()
        )))
    }

    pub async fn handle_wp_clear(&self, monitor: Option<String>) -> Response {
        info!("wp clear: monitor={monitor:?}");
        let mut state = self.state.write().await;
        state.clear_wallpaper(monitor.as_deref());
        Response::Ok(ResponsePayload::Empty)
    }

    pub async fn handle_wp_current(&self, monitor: Option<String>) -> Response {
        let state = self.state.read().await;
        let states = state.get_current(monitor.as_deref());
        Response::Ok(ResponsePayload::WallpaperState(states))
    }

    pub async fn handle_wp_toggle_hidden(&self, path: String) -> Response {
        info!("wp toggle-hidden: {path}");

        let src = PathBuf::from(&path);

        // Verify source exists before attempting rename
        if !src.exists() {
            return Response::Err {
                message: format!("file not found: {path}"),
            };
        }

        let fname = match src.file_name().and_then(|n| n.to_str()) {
            Some(n) => n.to_string(),
            None => {
                return Response::Err {
                    message: format!("invalid path: {path}"),
                };
            }
        };

        let new_fname = if fname.starts_with('.') {
            fname[1..].to_string()
        } else {
            format!(".{fname}")
        };

        let dst = src.with_file_name(&new_fname);

        // Check destination doesn't already exist
        if dst.exists() {
            return Response::Err {
                message: format!(
                    "destination already exists: {}",
                    dst.display()
                ),
            };
        }

        // Rename on disk
        if let Err(e) = tokio::fs::rename(&src, &dst).await {
            return Response::Err {
                message: format!("failed to rename {} → {}: {e}", src.display(), dst.display()),
            };
        }

        let new_path = dst.to_string_lossy().to_string();
        info!("renamed {} → {}", path, new_path);

        // Update all DB references
        let db = Arc::clone(&self.db);
        let old = path.clone();
        let new = new_path.clone();
        if let Err(e) = tokio::task::spawn_blocking(move || db.rename_path(&old, &new))
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")))
        {
            warn!("failed to update DB paths after rename: {e:#}");
        }

        // Update wallpaper state if the renamed file is the current wallpaper
        {
            let mut state = self.state.write().await;
            state.rename_wallpaper_path(&path, &new_path);
        }

        Response::Ok(ResponsePayload::Text(format!(
            "toggled: {path} → {new_path}"
        )))
    }

    pub async fn handle_wp_play(&self, monitor: Option<String>) -> Response {
        info!("wp play: monitor={monitor:?}");
        let mut state = self.state.write().await;
        state.set_paused(monitor.as_deref(), false);
        Response::Ok(ResponsePayload::Empty)
    }

    pub async fn handle_wp_pause(&self, monitor: Option<String>) -> Response {
        info!("wp pause: monitor={monitor:?}");
        let mut state = self.state.write().await;
        state.set_paused(monitor.as_deref(), true);
        Response::Ok(ResponsePayload::Empty)
    }

    pub async fn handle_wp_toggle_mute(&self, monitor: Option<String>) -> Response {
        info!("wp toggle-mute: monitor={monitor:?}");
        let mut state = self.state.write().await;
        state.toggle_mute(monitor.as_deref());
        Response::Ok(ResponsePayload::Empty)
    }

    // ════════════════════════════════════════════════════════════════════
    //  History handlers
    // ════════════════════════════════════════════════════════════════════

    pub async fn handle_history_list(&self, limit: usize) -> Response {
        info!("history list: limit={limit}");

        let db = Arc::clone(&self.db);
        let result = tokio::task::spawn_blocking(move || db.history_list(limit))
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")));

        match result {
            Ok(rows) => {
                let entries: Vec<HistoryEntry> = rows
                    .into_iter()
                    .map(|r| HistoryEntry {
                        id: r.id,
                        path: r.path,
                        timestamp: r.timestamp,
                        monitor: r.monitor,
                    })
                    .collect();
                Response::Ok(ResponsePayload::History(entries))
            }
            Err(e) => Response::Err {
                message: format!("history list failed: {e:#}"),
            },
        }
    }

    pub async fn handle_history_prev(&self) -> Response {
        info!("history prev");

        let new_offset = {
            let mut cursor = self.history_cursor.write().await;
            cursor.offset += 1;
            cursor.offset
        };

        let db = Arc::clone(&self.db);
        let result = tokio::task::spawn_blocking(move || db.history_nth(new_offset))
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")));

        match result {
            Ok(Some(row)) => {
                info!("history prev: applying {} (offset={new_offset})", row.path);
                let set_args = WpSetRequest {
                    path: row.path,
                    display: DisplayOpts {
                        monitor: row.monitor,
                        mode: row.mode,
                    },
                    media: MediaOpts {
                        mute: false,
                        volume: None,
                        no_theme: false,
                    },
                };
                // Apply without re-recording in history — set directly
                let mut state = self.state.write().await;
                if let Err(e) = state
                    .set_wallpaper(&set_args.path, &set_args.display, &set_args.media)
                    .await
                {
                    return Response::Err {
                        message: format!("failed to apply history entry: {e:#}"),
                    };
                }
                Response::Ok(ResponsePayload::Text(format!(
                    "restored wallpaper from history (offset {new_offset})"
                )))
            }
            Ok(None) => {
                // No more history — revert cursor
                let mut cursor = self.history_cursor.write().await;
                cursor.offset = cursor.offset.saturating_sub(1);
                Response::Err {
                    message: "no more history entries".into(),
                }
            }
            Err(e) => Response::Err {
                message: format!("history prev failed: {e:#}"),
            },
        }
    }

    pub async fn handle_history_next(&self) -> Response {
        info!("history next");

        let current_offset = {
            let cursor = self.history_cursor.read().await;
            cursor.offset
        };

        if current_offset == 0 {
            return Response::Err {
                message: "already at the most recent wallpaper".into(),
            };
        }

        let new_offset = current_offset - 1;

        let db = Arc::clone(&self.db);
        let result = tokio::task::spawn_blocking(move || db.history_nth(new_offset))
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")));

        match result {
            Ok(Some(row)) => {
                {
                    let mut cursor = self.history_cursor.write().await;
                    cursor.offset = new_offset;
                }
                info!("history next: applying {} (offset={new_offset})", row.path);
                let mut state = self.state.write().await;
                let display = DisplayOpts {
                    monitor: row.monitor,
                    mode: row.mode,
                };
                let media = MediaOpts {
                    mute: false,
                    volume: None,
                    no_theme: false,
                };
                if let Err(e) = state.set_wallpaper(&row.path, &display, &media).await {
                    return Response::Err {
                        message: format!("failed to apply history entry: {e:#}"),
                    };
                }
                Response::Ok(ResponsePayload::Text(format!(
                    "restored wallpaper from history (offset {new_offset})"
                )))
            }
            Ok(None) => Response::Err {
                message: "history entry not found".into(),
            },
            Err(e) => Response::Err {
                message: format!("history next failed: {e:#}"),
            },
        }
    }

    pub async fn handle_history_clear(&self) -> Response {
        info!("history clear");

        let db = Arc::clone(&self.db);
        let result = tokio::task::spawn_blocking(move || db.history_clear())
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")));

        match result {
            Ok(()) => {
                let mut cursor = self.history_cursor.write().await;
                cursor.offset = 0;
                Response::Ok(ResponsePayload::Empty)
            }
            Err(e) => Response::Err {
                message: format!("history clear failed: {e:#}"),
            },
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  Favorites handlers
    // ════════════════════════════════════════════════════════════════════

    pub async fn handle_fav_add(&self, path: Option<PathBuf>) -> Response {
        // If no path given, use the current wallpaper
        let resolved_path = match path {
            Some(p) => {
                // Canonicalize to avoid duplicates from relative vs absolute paths
                match p.canonicalize() {
                    Ok(abs) => abs.to_string_lossy().to_string(),
                    Err(_) => p.to_string_lossy().to_string(),
                }
            }
            None => {
                let state = self.state.read().await;
                let current = state.get_current(None);
                match current.first().and_then(|s| s.path.clone()) {
                    Some(p) => p,
                    None => {
                        return Response::Err {
                            message: "no current wallpaper to add to favorites".into(),
                        };
                    }
                }
            }
        };

        info!("fav add: {resolved_path}");

        let db = Arc::clone(&self.db);
        let p = resolved_path.clone();
        let result = tokio::task::spawn_blocking(move || db.fav_add(&p))
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")));

        match result {
            Ok(()) => Response::Ok(ResponsePayload::Text(format!(
                "added to favorites: {resolved_path}"
            ))),
            Err(e) => Response::Err {
                message: format!("fav add failed: {e:#}"),
            },
        }
    }

    pub async fn handle_fav_rm(&self, target: String) -> Response {
        info!("fav rm: {target}");

        let db = Arc::clone(&self.db);
        let t = target.clone();
        let result = tokio::task::spawn_blocking(move || db.fav_rm(&t))
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")));

        match result {
            Ok(true) => Response::Ok(ResponsePayload::Text(format!(
                "removed from favorites: {target}"
            ))),
            Ok(false) => Response::Err {
                message: format!("'{target}' not found in favorites"),
            },
            Err(e) => Response::Err {
                message: format!("fav rm failed: {e:#}"),
            },
        }
    }

    pub async fn handle_fav_list(&self, limit: usize) -> Response {
        info!("fav list: limit={limit}");

        let db = Arc::clone(&self.db);
        let result = tokio::task::spawn_blocking(move || db.fav_list(limit))
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")));

        match result {
            Ok(rows) => {
                let entries: Vec<FavoriteEntry> = rows
                    .into_iter()
                    .map(|r| FavoriteEntry {
                        id: r.id,
                        path: r.path,
                        added_at: r.added_at,
                    })
                    .collect();
                Response::Ok(ResponsePayload::Favorites(entries))
            }
            Err(e) => Response::Err {
                message: format!("fav list failed: {e:#}"),
            },
        }
    }

    pub async fn handle_fav_set_random(&self, opts: DisplayOpts) -> Response {
        info!(
            "fav set-random: monitor={:?} mode={}",
            opts.monitor, opts.mode
        );

        let db = Arc::clone(&self.db);
        let result = tokio::task::spawn_blocking(move || db.fav_all_paths())
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")));

        match result {
            Ok(paths) if paths.is_empty() => Response::Err {
                message: "favorites list is empty".into(),
            },
            Ok(paths) => {
                let picked = {
                    use rand::seq::IndexedRandom;
                    let mut rng = rand::rng();
                    paths.choose(&mut rng).cloned()
                };

                let picked = match picked {
                    Some(p) => p,
                    None => {
                        return Response::Err {
                            message: "failed to pick random favorite".into(),
                        };
                    }
                };

                info!("fav set-random: picked {picked}");

                let set_args = WpSetRequest {
                    path: picked,
                    display: opts,
                    media: MediaOpts {
                        mute: false,
                        volume: None,
                        no_theme: false,
                    },
                };
                self.handle_wp_set(set_args).await
            }
            Err(e) => Response::Err {
                message: format!("fav set-random failed: {e:#}"),
            },
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  Theme handlers
    // ════════════════════════════════════════════════════════════════════

    pub async fn handle_theme_generate(&self, path: PathBuf) -> Response {
        info!("theme generate: path={}", path.display());

        let theme = self.theme.read().await;
        let opts = MatugenOptions {
            mode: theme.mode,
            variant: theme.variant.clone(),
        };
        drop(theme);

        match matugen::generate_scheme(&path, &opts).await {
            Ok(scheme) => {
                let json = serde_json::to_value(&scheme).unwrap_or_default();
                Response::Ok(ResponsePayload::Json(json))
            }
            Err(e) => Response::Err {
                message: format!("theme generation failed: {e:#}"),
            },
        }
    }

    pub async fn handle_theme_mode_set(&self, mode: String) -> Response {
        info!("theme mode set: {mode}");

        let new_mode = match mode.as_str() {
            "dark" => SchemeMode::Dark,
            "light" => SchemeMode::Light,
            other => {
                return Response::Err {
                    message: format!("unknown theme mode '{other}' (expected dark|light)"),
                };
            }
        };

        {
            let mut theme = self.theme.write().await;
            theme.mode = new_mode;
            theme.auto_mode = false;
        }

        // Regenerate the current scheme with the new mode
        self.regenerate_current_theme().await;

        Response::Ok(ResponsePayload::Empty)
    }

    pub async fn handle_theme_mode_toggle(&self) -> Response {
        info!("theme mode toggle");

        let new_mode = {
            let mut theme = self.theme.write().await;
            theme.mode = match theme.mode {
                SchemeMode::Dark => SchemeMode::Light,
                SchemeMode::Light => SchemeMode::Dark,
            };
            theme.auto_mode = false;
            theme.mode
        };

        info!("theme mode toggled to {new_mode}");
        self.regenerate_current_theme().await;

        Response::Ok(ResponsePayload::Text(format!("{new_mode}")))
    }

    pub async fn handle_theme_mode_auto(&self) -> Response {
        info!("theme mode auto");
        let mut theme = self.theme.write().await;
        theme.auto_mode = true;
        // TODO: spawn a background task that checks time-of-day / sunset
        // and toggles mode accordingly
        Response::Ok(ResponsePayload::Text("auto mode enabled".into()))
    }

    pub async fn handle_theme_mode_current(&self) -> Response {
        let theme = self.theme.read().await;
        let auto_str = if theme.auto_mode { " (auto)" } else { "" };
        Response::Ok(ResponsePayload::Text(format!(
            "{}{}",
            theme.mode, auto_str
        )))
    }

    pub async fn handle_theme_palette_set(&self, variant: String) -> Response {
        info!("theme palette set: {variant}");

        // Validate variant name
        if !PALETTE_VARIANTS.contains(&variant.as_str()) {
            return Response::Err {
                message: format!(
                    "unknown palette variant '{variant}'. Available: {}",
                    PALETTE_VARIANTS.join(", ")
                ),
            };
        }

        {
            let mut theme = self.theme.write().await;
            theme.variant = variant;
        }

        self.regenerate_current_theme().await;

        Response::Ok(ResponsePayload::Empty)
    }

    pub async fn handle_theme_palette_list(&self) -> Response {
        let variants = PALETTE_VARIANTS.iter().map(|s| s.to_string()).collect();
        Response::Ok(ResponsePayload::PaletteVariants(variants))
    }

    pub async fn handle_theme_palette_current(&self) -> Response {
        let theme = self.theme.read().await;
        Response::Ok(ResponsePayload::Text(theme.variant.clone()))
    }

    // ════════════════════════════════════════════════════════════════════
    //  Config / Profile handlers
    // ════════════════════════════════════════════════════════════════════

    pub async fn handle_profile_save(&self, name: String) -> Response {
        info!("profile save: {name}");

        let state = self.state.read().await;
        let persisted = state.persisted().clone();
        drop(state);

        let theme = self.theme.read().await;
        let profile = serde_json::json!({
            "wallpaper_state": persisted,
            "theme_mode": format!("{}", theme.mode),
            "theme_variant": &theme.variant,
        });
        drop(theme);

        let dir = profile_dir();
        if let Err(e) = std::fs::create_dir_all(&dir) {
            return Response::Err {
                message: format!("failed to create profile dir: {e}"),
            };
        }

        let path = dir.join(format!("{name}.json"));
        let json = serde_json::to_string_pretty(&profile).unwrap_or_default();
        match std::fs::write(&path, &json) {
            Ok(()) => Response::Ok(ResponsePayload::Text(format!(
                "profile '{name}' saved to {}",
                path.display()
            ))),
            Err(e) => Response::Err {
                message: format!("failed to write profile: {e}"),
            },
        }
    }

    pub async fn handle_profile_load(&self, name: String) -> Response {
        info!("profile load: {name}");

        let path = profile_dir().join(format!("{name}.json"));
        let data = match std::fs::read_to_string(&path) {
            Ok(d) => d,
            Err(e) => {
                return Response::Err {
                    message: format!("failed to read profile '{name}': {e}"),
                };
            }
        };

        let profile: serde_json::Value = match serde_json::from_str(&data) {
            Ok(v) => v,
            Err(e) => {
                return Response::Err {
                    message: format!("failed to parse profile '{name}': {e}"),
                };
            }
        };

        // Restore wallpaper state
        if let Some(ws) = profile.get("wallpaper_state") {
            match serde_json::from_value(ws.clone()) {
                Ok(new_state) => {
                    let mut state = self.state.write().await;
                    if let Err(e) = state.replace(new_state) {
                        warn!("failed to apply wallpaper state from profile: {e}");
                    }
                }
                Err(e) => {
                    warn!("failed to parse wallpaper_state in profile: {e}");
                }
            }
        }

        // Restore theme settings
        {
            let mut theme = self.theme.write().await;
            if let Some(mode_str) = profile.get("theme_mode").and_then(|v| v.as_str()) {
                theme.mode = match mode_str {
                    "light" => SchemeMode::Light,
                    _ => SchemeMode::Dark,
                };
            }
            if let Some(variant) = profile.get("theme_variant").and_then(|v| v.as_str()) {
                theme.variant = variant.to_string();
            }
        }

        Response::Ok(ResponsePayload::Text(format!("profile '{name}' loaded")))
    }

    pub async fn handle_profile_list(&self) -> Response {
        let dir = profile_dir();
        let mut names = Vec::new();

        if let Ok(entries) = std::fs::read_dir(&dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().is_some_and(|e| e == "json") {
                    if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                        names.push(stem.to_string());
                    }
                }
            }
        }

        names.sort();
        Response::Ok(ResponsePayload::Profiles(names))
    }

    pub async fn handle_profile_rm(&self, name: String) -> Response {
        info!("profile rm: {name}");

        let path = profile_dir().join(format!("{name}.json"));
        if !path.exists() {
            return Response::Err {
                message: format!("profile '{name}' not found"),
            };
        }

        match std::fs::remove_file(&path) {
            Ok(()) => Response::Ok(ResponsePayload::Text(format!(
                "profile '{name}' deleted"
            ))),
            Err(e) => Response::Err {
                message: format!("failed to delete profile '{name}': {e}"),
            },
        }
    }

    pub async fn handle_config_edit(&self) -> Response {
        let config_path = config_dir().join("config.toml");

        // Ensure the file exists
        if !config_path.exists() {
            if let Some(parent) = config_path.parent() {
                std::fs::create_dir_all(parent).ok();
            }
            std::fs::write(
                &config_path,
                "# walltool configuration\n\n[theme]\nmode = \"dark\"\nvariant = \"tonal-spot\"\n",
            )
            .ok();
        }

        Response::Ok(ResponsePayload::Text(format!(
            "{}",
            config_path.display()
        )))
    }

    // ════════════════════════════════════════════════════════════════════
    //  Monitor handlers
    // ════════════════════════════════════════════════════════════════════

    pub async fn handle_monitor_list(&self) -> Response {
        info!("monitor list");
        match monitor::fetch_monitors().await {
            Ok(monitors) => Response::Ok(ResponsePayload::Monitors(monitors)),
            Err(e) => Response::Err {
                message: format!("failed to query Hyprland monitors: {e:#}"),
            },
        }
    }

    pub async fn handle_monitor_identify(&self) -> Response {
        info!("monitor identify");
        // Write a signal file that QML can watch for
        let signal_path = cache_dir().join("identify_signal");
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis();
        std::fs::write(&signal_path, ts.to_string()).ok();
        Response::Ok(ResponsePayload::Text(
            "identify signal written (QML should watch for it)".into(),
        ))
    }

    // ════════════════════════════════════════════════════════════════════
    //  Daemon control handlers
    // ════════════════════════════════════════════════════════════════════

    pub async fn handle_status(&self) -> Response {
        let uptime = self.started_at.elapsed().as_secs();
        let game_mode = *self.game_mode.read().await;
        let memory_mb = get_rss_mb().unwrap_or(0.0);

        let slideshow = self.slideshow.read().await;
        let slideshow_active = slideshow.is_active();
        let slideshow_interval = slideshow.current_interval();
        drop(slideshow);

        let monitor_count = {
            let state = self.state.read().await;
            state.monitor_count()
        };

        let ai_indexing = self.indexer_state.is_active();
        let ai_queue_size = self.indexer_state.pending();

        let info = crate::ipc::DaemonStatusInfo {
            uptime_secs: uptime,
            memory_mb,
            slideshow_active,
            slideshow_interval,
            ai_indexing,
            ai_queue_size,
            game_mode,
            monitors: monitor_count,
        };

        Response::Ok(ResponsePayload::DaemonStatus(info))
    }

    pub async fn handle_stop(&self) -> Response {
        info!("daemon stop requested");

        // Cancel all slideshows
        {
            let mut slideshow = self.slideshow.write().await;
            slideshow.cancel_all();
        }

        // Abort indexer tasks
        {
            let mut handles = self.indexer_handles.write().await;
            for h in handles.drain(..) {
                h.abort();
            }
        }

        // Send shutdown signal
        let _ = self.shutdown_tx.send(());
        Response::Ok(ResponsePayload::Text("daemon shutting down".into()))
    }

    pub async fn handle_pause_all(&self) -> Response {
        info!("pause-all (game mode ON)");
        *self.game_mode.write().await = true;

        // Pause all video/gif playback
        let mut state = self.state.write().await;
        state.set_paused(None, true);

        // Pause background indexer
        self.indexer_state.pause();

        // Slideshows will check game_mode flag on each tick and skip

        Response::Ok(ResponsePayload::Text("game mode: ON".into()))
    }

    pub async fn handle_resume_all(&self) -> Response {
        info!("resume-all (game mode OFF)");
        *self.game_mode.write().await = false;

        // Resume all video/gif playback
        let mut state = self.state.write().await;
        state.set_paused(None, false);

        // Resume background indexer
        self.indexer_state.resume();

        Response::Ok(ResponsePayload::Text("game mode: OFF".into()))
    }

    pub async fn handle_slideshow_start(self: &Arc<Self>, args: SlideshowStartRequest) -> Response {
        info!(
            "slideshow start: dir={} interval={}s monitor={:?}",
            args.dir.display(),
            args.interval,
            args.monitor,
        );

        if !args.dir.is_dir() {
            return Response::Err {
                message: format!("{} is not a directory", args.dir.display()),
            };
        }

        let shutdown_rx = self.shutdown_tx.subscribe();

        {
            let mut slideshow = self.slideshow.write().await;
            slideshow.start(&args, Arc::clone(self), shutdown_rx);
        }

        let key = args
            .monitor
            .as_deref()
            .unwrap_or("all monitors");
        Response::Ok(ResponsePayload::Text(format!(
            "slideshow started for [{key}] — {}s interval",
            args.interval
        )))
    }

    pub async fn handle_slideshow_stop(&self, monitor: Option<String>) -> Response {
        info!("slideshow stop: monitor={monitor:?}");
        let mut slideshow = self.slideshow.write().await;
        slideshow.stop(monitor.as_deref());
        Response::Ok(ResponsePayload::Empty)
    }

    // ════════════════════════════════════════════════════════════════════
    //  Internal helpers
    // ════════════════════════════════════════════════════════════════════

    /// Regenerate theme from the current wallpaper using the current
    /// theme settings (mode + variant). Fire-and-forget.
    /// Regenerate theme from the current wallpaper using the current
        /// theme settings (mode + variant). Fire-and-forget.
        // async fn regenerate_current_theme(&self) {
        //     let current_path = {
        //         let state = self.state.read().await;
        //         let current = state.get_current(None);
        //         current
        //             .first()
        //             .and_then(|s| s.path.clone())
        //     };

        //     let Some(path_str) = current_path else {
        //         debug!("no current wallpaper — skipping theme regeneration");
        //         return;
        //     };

        //     let theme = self.theme.read().await;
        //     let opts = MatugenOptions {
        //         mode: theme.mode,
        //         variant: theme.variant.clone(),
        //     };
        //     drop(theme);

        //     // Получаем доступ к БД для кэша
        //     let db = Arc::clone(&self.db);
        //     let path_clone = path_str.clone();

        //     tokio::spawn(async move {
        //         // Пытаемся быстро вытащить цвет из БД
        //         let cached_color = tokio::task::spawn_blocking(move || {
        //             db.get_wallpaper_by_path(&path_clone)
        //               .ok()
        //               .flatten()
        //               .and_then(|row| row.dominant_color)
        //         })
        //         .await
        //         .unwrap_or(None);

        //         let source = Path::new(&path_str);

        //         // ИЗМЕНЕНИЕ ЗДЕСЬ: Передаем cached_color, чтобы смена Dark/Light режима
        //         // не вызывала повторную перегенерацию из картинки
        //         if let Err(e) = matugen::generate_scheme(source, &opts, cached_color.as_deref()).await {
        //             warn!("theme regeneration failed: {e:#}");
        //         }
        //     });
        // }
    async fn regenerate_current_theme(&self) {
        let current_path = {
            let state = self.state.read().await;
            let current = state.get_current(None);
            current
                .first()
                .and_then(|s| s.path.clone())
        };

        let Some(path_str) = current_path else {
            debug!("no current wallpaper — skipping theme regeneration");
            return;
        };

        let theme = self.theme.read().await;
        let opts = MatugenOptions {
            mode: theme.mode,
            variant: theme.variant.clone(),
        };
        drop(theme);

        tokio::spawn(async move {
            let source = Path::new(&path_str);
            if let Err(e) = matugen::generate_scheme(source, &opts).await {
                warn!("theme regeneration failed: {e:#}");
            }
        });
    }

    /// Recalculate span offsets after a monitor change.
    async fn recalculate_span(&self) -> Result<()> {
        let monitors = monitor::fetch_monitors().await?;
        let offsets = monitor::compute_span_offsets(&monitors);

        let mut state = self.state.write().await;
        for (name, ox, oy) in &offsets {
            state.set_offsets(name, *ox, *oy);
        }
        state.flush()?;
        Ok(())
    }
}

// ── Random file picker (reused by wp random) ────────────────────────────────

/// Pick a random file from a directory, respecting filters.
/// Runs filesystem scan in `spawn_blocking`.
async fn pick_random_file(
    dir: &Path,
    media_type: Option<&str>,
    include_dot: bool,
    only_dot: bool,
    query: Option<&str>,
) -> Result<Option<PathBuf>> {
    let dir = dir.to_path_buf();
    let media_type = media_type.map(String::from);
    let query = query.map(String::from);

    tokio::task::spawn_blocking(move || {
        use rand::seq::IndexedRandom;

        let mut candidates: Vec<PathBuf> = Vec::new();

        for entry in WalkDir::new(&dir).follow_links(true) {
            let entry = match entry {
                Ok(e) => e,
                Err(_) => continue,
            };

            let name = entry.file_name().to_string_lossy();
            let is_dot = name.starts_with('.');

            // Dot-file filtering
            if is_dot && !(include_dot || only_dot) {
                continue;
            }
            if !is_dot && only_dot {
                continue;
            }

            if !entry.file_type().is_file() {
                continue;
            }

            let path = entry.path();

            // Media type filter
            if let Some(ref mt) = media_type {
                if mt != "all" && !slideshow::matches_media_type_ext(path, mt) {
                    continue;
                }
            } else if !slideshow::is_supported_media_ext(path) {
                continue;
            }

            // Query filter (case-insensitive substring match on filename)
            if let Some(ref q) = query {
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

        let mut rng = rand::rng();
        Ok(candidates.choose(&mut rng).cloned())
    })
    .await
    .context("file picker task panicked")?
}

// ── Path helpers ────────────────────────────────────────────────────────────

fn cache_dir() -> PathBuf {
    directories::BaseDirs::new()
        .map(|d| d.cache_dir().join("walltool"))
        .unwrap_or_else(|| PathBuf::from("/tmp/walltool"))
}

fn config_dir() -> PathBuf {
    directories::ProjectDirs::from("", "", "walltool")
        .map(|d| d.config_dir().to_path_buf())
        .unwrap_or_else(|| {
            let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
            PathBuf::from(home).join(".config/walltool")
        })
}

fn profile_dir() -> PathBuf {
    config_dir().join("profiles")
}

/// Read RSS (Resident Set Size) from /proc/self/statm on Linux.
fn get_rss_mb() -> Option<f64> {
    let statm = std::fs::read_to_string("/proc/self/statm").ok()?;
    let rss_pages: u64 = statm.split_whitespace().nth(1)?.parse().ok()?;
    let page_size = 4096u64; // typical on x86_64
    Some((rss_pages * page_size) as f64 / (1024.0 * 1024.0))
}
