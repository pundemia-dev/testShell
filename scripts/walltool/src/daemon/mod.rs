//! walltool daemon — awww + matugen orchestrator
//!
//! Key responsibilities:
//! - Orchestrate awww for wallpaper rendering
//! - Orchestrate matugen for theme generation
//! - Manage preview mode with RAM backup
//! - Handle history, favorites, profiles
//! - Run slideshow timers
//! - Index wallpapers in SQLite

pub mod awww;
pub mod indexer;
pub mod matugen;
pub mod slideshow;

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Instant;

use anyhow::{Context, Result};
use tokio::sync::{broadcast, RwLock};
use tracing::{debug, info, warn};
use walkdir::WalkDir;

use crate::config::Config;
use crate::db::Db;
use crate::ipc::{
    AwwwOpts, FavoriteEntry, HistoryEntry, MatugenParams, Response, ResponsePayload,
    SearchResultEntry, SlideshowOpts, SlideshowStartRequest, WpClearRequest, WpIndexRequest,
    WpOptionsSetRequest, WpPreviewStartRequest, WpRandomRequest, WpRestoreRequest,
    WpSearchRequest, WpSetRequest,
};

use self::indexer::IndexerState;
use self::matugen::{MatugenRunner, PALETTE_VARIANTS};
use self::slideshow::SlideshowManager;
use crate::ipc::{IndexerOptsInfo, MonitorAwwwOpts, MonitorConfigEntry, ThemeAutoOptsInfo};

// ══════════════════════════════════════════════════════════════════════════════
//  Preview backup state (RAM only)
// ══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone)]
pub struct PreviewBackup {
    /// Path to wallpaper before preview started
    pub path: String,
    /// awww options that were used
    pub awww_opts: AwwwOpts,
}

// ══════════════════════════════════════════════════════════════════════════════
//  Daemon state
// ══════════════════════════════════════════════════════════════════════════════

pub struct Daemon {
    /// When the daemon was started
    pub started_at: Instant,

    /// Loaded configuration
    pub config: Config,

    /// SQLite database
    pub db: Arc<Db>,

    /// Slideshow manager
    pub slideshow: RwLock<SlideshowManager>,

    /// Current matugen parameters (mode, scheme-type, contrast, etc.)
    pub matugen_params: RwLock<MatugenParams>,

    /// Matugen runner (handles abort of previous task)
    pub matugen_runner: MatugenRunner,

    /// Current wallpaper path (for theme regeneration)
    pub current_path: RwLock<Option<String>>,

    /// Current awww options (for saving per-wallpaper)
    pub current_awww_opts: RwLock<AwwwOpts>,

    /// Preview backup (None if not in preview mode)
    pub preview_backup: RwLock<Option<PreviewBackup>>,

    /// History navigation cursor (offset into history table)
    pub history_cursor: RwLock<usize>,

    /// Shutdown signal broadcaster
    pub shutdown_tx: broadcast::Sender<()>,

    /// Game mode flag (pauses everything)
    pub game_mode: RwLock<bool>,

    /// Background indexer state
    pub indexer_state: Arc<IndexerState>,

    /// Handles to running indexer tasks
    pub indexer_handles: RwLock<Vec<tokio::task::JoinHandle<()>>>,
}

impl Daemon {
    pub fn new(shutdown_tx: broadcast::Sender<()>) -> Result<Self> {
        // Load configuration
        let config = Config::load().unwrap_or_else(|e| {
            warn!("failed to load config: {e:#}, using defaults");
            Config::default()
        });

        let db_path = Db::default_path();
        let db = Db::open(&db_path)
            .with_context(|| format!("open database at {}", db_path.display()))?;

        // Initialize matugen params from config
        let matugen_params = config.default_matugen_params();

        // Initialize default awww opts from config
        let default_awww_opts = config.default_awww_opts();

        Ok(Self {
            started_at: Instant::now(),
            config,
            db: Arc::new(db),
            slideshow: RwLock::new(SlideshowManager::new()),
            matugen_params: RwLock::new(matugen_params),
            matugen_runner: MatugenRunner::new(),
            current_path: RwLock::new(None),
            current_awww_opts: RwLock::new(default_awww_opts),
            preview_backup: RwLock::new(None),
            history_cursor: RwLock::new(0),
            shutdown_tx,
            game_mode: RwLock::new(false),
            indexer_state: Arc::new(IndexerState::new()),
            indexer_handles: RwLock::new(Vec::new()),
        })
    }

    /// Merge awww options: config defaults → monitor override → per-wallpaper → CLI
        /// Resolve final awww options by merging layers:
    /// config defaults → monitor overrides → per-wallpaper → CLI
    ///
    /// NOTE: This reads config from disk to ensure we get the latest values
    /// after any `config set-awww-default` calls.
    pub async fn resolve_awww_opts(&self, path: &str, cli_opts: &AwwwOpts) -> AwwwOpts {
        use crate::config::merge_awww_opts;

        // Read fresh config from disk to get latest settings
        let fresh_config = Config::load().unwrap_or_else(|e| {
            warn!("failed to reload config, using cached: {e}");
            self.config.clone()
        });

        // Start with fresh config defaults
        let mut opts = fresh_config.default_awww_opts();

        // Apply monitor override if specified
        if let Some(output) = &cli_opts.outputs {
            let mon_opts = fresh_config.awww_opts_for_monitor(output);
            opts = merge_awww_opts(&opts, &mon_opts);
        }

        // Apply per-wallpaper overrides from DB
        if let Ok(Some(json)) = self.db.get_wallpaper_options(path) {
            if let Ok(wp_opts) = serde_json::from_str::<AwwwOpts>(&json) {
                opts = merge_awww_opts(&opts, &wp_opts);
            }
        }

        // Apply CLI overrides (highest priority)
        opts = merge_awww_opts(&opts, cli_opts);

        opts
    }

    // ════════════════════════════════════════════════════════════════════
    //  Wallpaper handlers
    // ════════════════════════════════════════════════════════════════════

    pub async fn handle_wp_set(&self, args: WpSetRequest) -> Response {
        let path = canonicalize_path(&args.path);
        info!("wp set: {}", path);

        // Resolve final awww options (config → monitor → per-wallpaper → CLI)
        let resolved_opts = self.resolve_awww_opts(&path, &args.awww).await;

        // 1. Call awww img
        if let Err(e) = awww::run_awww_img(&path, &resolved_opts).await {
            return Response::Err {
                message: format!("awww img failed: {e:#}"),
            };
        }

        // 2. Store current path and opts
        *self.current_path.write().await = Some(path.clone());
        *self.current_awww_opts.write().await = resolved_opts.clone();

        // 3. Record in history
        {
            let db = Arc::clone(&self.db);
            let p = path.clone();
            let monitor = resolved_opts.outputs.clone();
            if let Err(e) = tokio::task::spawn_blocking(move || {
                db.history_push(&p, monitor.as_deref(), "fill")
            })
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")))
            {
                warn!("failed to record history: {e:#}");
            }
        }

        // Reset history cursor
        *self.history_cursor.write().await = 0;

        // 4. Generate theme (fire-and-forget)
        if !args.no_theme {
            let params = self.matugen_params.read().await.clone();
            self.matugen_runner.run(Path::new(&path), &params).await;
        }

        Response::Ok(ResponsePayload::Empty)
    }

    pub async fn handle_wp_preview_start(&self, args: WpPreviewStartRequest) -> Response {
        let path = canonicalize_path(&args.path);
        info!("wp preview start: {}", path);

        // Save backup if not already in preview
        {
            let mut backup = self.preview_backup.write().await;
            if backup.is_none() {
                let current = self.current_path.read().await.clone();
                let current_opts = self.current_awww_opts.read().await.clone();
                if let Some(current_path) = current {
                    *backup = Some(PreviewBackup {
                        path: current_path,
                        awww_opts: current_opts,
                    });
                    debug!("preview backup saved");
                }
            }
        }

        // Resolve awww options same as normal set (config → monitor → per-wallpaper → CLI)
        let resolved_opts = self.resolve_awww_opts(&path, &args.awww).await;

        // Call awww img with full transition settings
        if let Err(e) = awww::run_awww_img(&path, &resolved_opts).await {
            return Response::Err {
                message: format!("awww img failed: {e:#}"),
            };
        }

        // Update current path and opts (but don't write to history!)
        *self.current_path.write().await = Some(path.clone());
        *self.current_awww_opts.write().await = resolved_opts;

        // Generate theme
        let params = self.matugen_params.read().await.clone();
        self.matugen_runner.run(Path::new(&path), &params).await;

        Response::Ok(ResponsePayload::Empty)
    }

    pub async fn handle_wp_preview_stop(&self) -> Response {
        info!("wp preview stop");

        let backup = self.preview_backup.write().await.take();
        let Some(backup) = backup else {
            return Response::Err {
                message: "not in preview mode".into(),
            };
        };

        // Restore with instant transition
        let restore_opts = awww::instant_transition_opts();
        if let Err(e) = awww::run_awww_img(&backup.path, &restore_opts).await {
            return Response::Err {
                message: format!("failed to restore: {e:#}"),
            };
        }

        // Restore current path
        *self.current_path.write().await = Some(backup.path.clone());

        // Regenerate theme from backup
        let params = self.matugen_params.read().await.clone();
        self.matugen_runner.run(Path::new(&backup.path), &params).await;

        Response::Ok(ResponsePayload::Text("preview stopped, wallpaper restored".into()))
    }

    pub async fn handle_wp_preview_commit(&self) -> Response {
        info!("wp preview commit");

        let backup = self.preview_backup.write().await.take();
        if backup.is_none() {
            return Response::Err {
                message: "not in preview mode".into(),
            };
        }

        // Get current (preview) path
        let current = self.current_path.read().await.clone();
        let Some(path) = current else {
            return Response::Err {
                message: "no current wallpaper".into(),
            };
        };

        // Write to history
        let db = Arc::clone(&self.db);
        let p = path.clone();
        if let Err(e) = tokio::task::spawn_blocking(move || {
            db.history_push(&p, None, "fill")
        })
        .await
        .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")))
        {
            warn!("failed to record history: {e:#}");
        }

        *self.history_cursor.write().await = 0;

        Response::Ok(ResponsePayload::Text(format!("preview committed: {path}")))
    }

    pub async fn handle_wp_random(&self, args: WpRandomRequest) -> Response {
        info!("wp random: dir={}", args.dir.display());

        let dir = args.dir.clone();
        let search = args.search.clone();

        let picked = match pick_random_file(&dir, &search).await {
            Ok(Some(p)) => p,
            Ok(None) => {
                return Response::Err {
                    message: format!("no matching files in {}", dir.display()),
                };
            }
            Err(e) => {
                return Response::Err {
                    message: format!("error: {e:#}"),
                };
            }
        };

        info!("wp random picked: {}", picked.display());

        let set_args = WpSetRequest {
            path: picked.to_string_lossy().to_string(),
            awww: args.awww,
            no_theme: args.no_theme,
        };

        self.handle_wp_set(set_args).await
    }

    pub async fn handle_wp_search(&self, args: WpSearchRequest) -> Response {
        info!("wp search: {}", args.query);

        let db = Arc::clone(&self.db);
        let query = args.query.clone();
        let search = args.search.clone();

        let result = tokio::task::spawn_blocking(move || {
            db.search(
                &query,
                search.limit,
                search.include_dot,
                search.only_dot,
            )
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

    pub async fn handle_wp_toggle_hidden(&self, path: String) -> Response {
        info!("wp toggle-hidden: {path}");

        let src = PathBuf::from(&path);
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

        if dst.exists() {
            return Response::Err {
                message: format!("destination exists: {}", dst.display()),
            };
        }

        if let Err(e) = tokio::fs::rename(&src, &dst).await {
            return Response::Err {
                message: format!("rename failed: {e}"),
            };
        }

        let new_path = dst.to_string_lossy().to_string();

        // Update DB
        let db = Arc::clone(&self.db);
        let old = path.clone();
        let new = new_path.clone();
        let _ = tokio::task::spawn_blocking(move || db.rename_path(&old, &new)).await;

        Response::Ok(ResponsePayload::Text(format!("{path} → {new_path}")))
    }

    pub async fn handle_wp_index(&self, args: WpIndexRequest) -> Response {
        info!("wp index: dir={}", args.dir.display());

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

    pub async fn handle_wp_clear(&self, args: WpClearRequest) -> Response {
        info!("wp clear");

        if let Err(e) = awww::run_awww_clear(
            args.color.as_deref(),
            args.outputs.as_deref(),
            args.namespace.as_deref(),
        ).await {
            return Response::Err {
                message: format!("awww clear failed: {e:#}"),
            };
        }

        Response::Ok(ResponsePayload::Empty)
    }

    pub async fn handle_wp_clear_cache(&self) -> Response {
        info!("wp clear-cache");

        if let Err(e) = awww::run_awww_clear_cache().await {
            return Response::Err {
                message: format!("awww clear-cache failed: {e:#}"),
            };
        }

        Response::Ok(ResponsePayload::Empty)
    }

    pub async fn handle_wp_restore(&self, args: WpRestoreRequest) -> Response {
        info!("wp restore");

        if let Err(e) = awww::run_awww_restore(
            args.outputs.as_deref(),
            args.namespace.as_deref(),
        ).await {
            return Response::Err {
                message: format!("awww restore failed: {e:#}"),
            };
        }

        Response::Ok(ResponsePayload::Empty)
    }

    // ════════════════════════════════════════════════════════════════════
    //  Per-wallpaper options handlers (awww opts stored in DB)
    // ════════════════════════════════════════════════════════════════════

    pub async fn handle_wp_options_set(&self, args: WpOptionsSetRequest) -> Response {
        // If path is None, use current wallpaper
        let path = match args.path {
            Some(p) => p,
            None => {
                let guard = self.current_path.read().await;
                match guard.as_ref() {
                    Some(p) => p.clone(),
                    None => {
                        return Response::Err {
                            message: "no current wallpaper and no path specified".into(),
                        };
                    }
                }
            }
        };

        info!("wp options set: {path}");

        let db = Arc::clone(&self.db);
        let opts_json = match serde_json::to_string(&args.awww) {
            Ok(j) => j,
            Err(e) => {
                return Response::Err {
                    message: format!("failed to serialize options: {e}"),
                };
            }
        };

        let result = tokio::task::spawn_blocking(move || {
            db.set_wallpaper_options(&path, &opts_json)
        })
        .await;

        match result {
            Ok(Ok(_)) => Response::Ok(ResponsePayload::Text("options saved".into())),
            Ok(Err(e)) => Response::Err {
                message: format!("database error: {e}"),
            },
            Err(e) => Response::Err {
                message: format!("task panicked: {e}"),
            },
        }
    }

    pub async fn handle_wp_options_get(&self, path: Option<String>) -> Response {
        // If path is None, use current wallpaper
        let path = match path {
            Some(p) => p,
            None => {
                let guard = self.current_path.read().await;
                match guard.as_ref() {
                    Some(p) => p.clone(),
                    None => {
                        return Response::Err {
                            message: "no current wallpaper and no path specified".into(),
                        };
                    }
                }
            }
        };

        info!("wp options get: {path}");

        let db = Arc::clone(&self.db);
        let result = tokio::task::spawn_blocking(move || {
            db.get_wallpaper_options(&path)
        })
        .await;

        match result {
            Ok(Ok(Some(json))) => {
                match serde_json::from_str::<AwwwOpts>(&json) {
                    Ok(opts) => Response::Ok(ResponsePayload::AwwwOpts(opts)),
                    Err(e) => Response::Err {
                        message: format!("failed to parse stored options: {e}"),
                    },
                }
            }
            Ok(Ok(None)) => {
                Response::Ok(ResponsePayload::AwwwOpts(AwwwOpts::default()))
            }
            Ok(Err(e)) => Response::Err {
                message: format!("database error: {e}"),
            },
            Err(e) => Response::Err {
                message: format!("task panicked: {e}"),
            },
        }
    }

    pub async fn handle_wp_options_clear(&self, path: Option<String>) -> Response {
        // If path is None, use current wallpaper
        let path = match path {
            Some(p) => p,
            None => {
                let guard = self.current_path.read().await;
                match guard.as_ref() {
                    Some(p) => p.clone(),
                    None => {
                        return Response::Err {
                            message: "no current wallpaper and no path specified".into(),
                        };
                    }
                }
            }
        };

        info!("wp options clear: {path}");

        let db = Arc::clone(&self.db);
        let result = tokio::task::spawn_blocking(move || {
            db.clear_wallpaper_options(&path)
        })
        .await;

        match result {
            Ok(Ok(_)) => Response::Ok(ResponsePayload::Text("options cleared".into())),
            Ok(Err(e)) => Response::Err {
                message: format!("database error: {e}"),
            },
            Err(e) => Response::Err {
                message: format!("task panicked: {e}"),
            },
        }
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
            *cursor += 1;
            *cursor
        };

        let db = Arc::clone(&self.db);
        let result = tokio::task::spawn_blocking(move || db.history_nth(new_offset))
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")));

        match result {
            Ok(Some(row)) => {
                info!("history prev: applying {} (offset={new_offset})", row.path);

                // Use instant transition for history navigation
                let opts = awww::instant_transition_opts();
                if let Err(e) = awww::run_awww_img(&row.path, &opts).await {
                    return Response::Err {
                        message: format!("failed to apply: {e:#}"),
                    };
                }

                *self.current_path.write().await = Some(row.path.clone());

                // Regenerate theme
                let params = self.matugen_params.read().await.clone();
                self.matugen_runner.run(Path::new(&row.path), &params).await;

                Response::Ok(ResponsePayload::Text(format!(
                    "restored from history (offset {new_offset})"
                )))
            }
            Ok(None) => {
                let mut cursor = self.history_cursor.write().await;
                *cursor = cursor.saturating_sub(1);
                Response::Err {
                    message: "no more history".into(),
                }
            }
            Err(e) => Response::Err {
                message: format!("history prev failed: {e:#}"),
            },
        }
    }

    pub async fn handle_history_next(&self) -> Response {
        info!("history next");

        let current_offset = *self.history_cursor.read().await;

        if current_offset == 0 {
            return Response::Err {
                message: "already at most recent".into(),
            };
        }

        let new_offset = current_offset - 1;

        let db = Arc::clone(&self.db);
        let result = tokio::task::spawn_blocking(move || db.history_nth(new_offset))
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")));

        match result {
            Ok(Some(row)) => {
                *self.history_cursor.write().await = new_offset;

                let opts = awww::instant_transition_opts();
                if let Err(e) = awww::run_awww_img(&row.path, &opts).await {
                    return Response::Err {
                        message: format!("failed to apply: {e:#}"),
                    };
                }

                *self.current_path.write().await = Some(row.path.clone());

                let params = self.matugen_params.read().await.clone();
                self.matugen_runner.run(Path::new(&row.path), &params).await;

                Response::Ok(ResponsePayload::Text(format!(
                    "restored from history (offset {new_offset})"
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
                *self.history_cursor.write().await = 0;
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
        let resolved = match path {
            Some(p) => canonicalize_path(&p.to_string_lossy()),
            None => match self.current_path.read().await.clone() {
                Some(p) => p,
                None => {
                    return Response::Err {
                        message: "no current wallpaper".into(),
                    };
                }
            },
        };

        info!("fav add: {resolved}");

        let db = Arc::clone(&self.db);
        let p = resolved.clone();
        let result = tokio::task::spawn_blocking(move || db.fav_add(&p))
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")));

        match result {
            Ok(()) => Response::Ok(ResponsePayload::Text(format!("added: {resolved}"))),
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
            Ok(true) => Response::Ok(ResponsePayload::Text(format!("removed: {target}"))),
            Ok(false) => Response::Err {
                message: format!("'{target}' not in favorites"),
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

    pub async fn handle_fav_set_random(&self, awww: AwwwOpts) -> Response {
        info!("fav set-random");

        let db = Arc::clone(&self.db);
        let result = tokio::task::spawn_blocking(move || db.fav_all_paths())
            .await
            .unwrap_or_else(|e| Err(anyhow::anyhow!("spawn_blocking panicked: {e}")));

        match result {
            Ok(paths) if paths.is_empty() => Response::Err {
                message: "favorites empty".into(),
            },
            Ok(paths) => {
                // Pick a random entry (use thread_rng in a non-Send context)
                let picked = {
                    use rand::seq::IndexedRandom;
                    let mut rng = rand::rng();
                    paths.choose(&mut rng).cloned()
                };

                let Some(picked) = picked else {
                    return Response::Err {
                        message: "failed to pick".into(),
                    };
                };

                let set_args = WpSetRequest {
                    path: picked,
                    awww,
                    no_theme: false,
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
        info!("theme generate: {}", path.display());

        let params = self.matugen_params.read().await.clone();

        match matugen::generate_scheme(&path, &params).await {
            Ok(scheme) => {
                let json = serde_json::to_value(&scheme).unwrap_or_default();
                Response::Ok(ResponsePayload::Json(json))
            }
            Err(e) => Response::Err {
                message: format!("theme generation failed: {e:#}"),
            },
        }
    }

    pub async fn handle_theme_set(&self, param: String, value: String) -> Response {
        info!("theme set: {param} = {value}");

        {
            let mut params = self.matugen_params.write().await;
            if let Err(e) = params.set_param(&param, &value) {
                return Response::Err {
                    message: format!("{e}"),
                };
            }
        }

        // Regenerate theme from current wallpaper
        if let Some(path) = self.current_path.read().await.clone() {
            let params = self.matugen_params.read().await.clone();
            self.matugen_runner.run(Path::new(&path), &params).await;
        }

        Response::Ok(ResponsePayload::Empty)
    }

    pub async fn handle_theme_get(&self) -> Response {
        let params = self.matugen_params.read().await.clone();
        Response::Ok(ResponsePayload::ThemeParams(params))
    }

    pub async fn handle_theme_mode_set(&self, mode: String) -> Response {
        info!("theme mode set: {mode}");

        if mode != "dark" && mode != "light" {
            return Response::Err {
                message: format!("mode must be 'dark' or 'light', got '{mode}'"),
            };
        }

        {
            let mut params = self.matugen_params.write().await;
            params.mode = mode;
        }

        // Regenerate
        if let Some(path) = self.current_path.read().await.clone() {
            let params = self.matugen_params.read().await.clone();
            self.matugen_runner.run(Path::new(&path), &params).await;
        }

        Response::Ok(ResponsePayload::Empty)
    }

    pub async fn handle_theme_mode_toggle(&self) -> Response {
        info!("theme mode toggle");

        let new_mode = {
            let mut params = self.matugen_params.write().await;
            params.mode = if params.mode == "dark" {
                "light".to_string()
            } else {
                "dark".to_string()
            };
            params.mode.clone()
        };

        // Regenerate
        if let Some(path) = self.current_path.read().await.clone() {
            let params = self.matugen_params.read().await.clone();
            self.matugen_runner.run(Path::new(&path), &params).await;
        }

        Response::Ok(ResponsePayload::Text(new_mode))
    }

    pub async fn handle_theme_mode_auto(&self) -> Response {
        info!("theme mode auto");
        // TODO: implement time-based auto switching
        Response::Ok(ResponsePayload::Text("auto mode enabled".into()))
    }

    pub async fn handle_theme_mode_current(&self) -> Response {
        let params = self.matugen_params.read().await;
        Response::Ok(ResponsePayload::Text(params.mode.clone()))
    }

    pub async fn handle_theme_palette_set(&self, variant: String) -> Response {
        info!("theme palette set: {variant}");

        let normalized = if variant.starts_with("scheme-") {
            variant.clone()
        } else {
            format!("scheme-{variant}")
        };

        if !PALETTE_VARIANTS.contains(&normalized.as_str()) {
            return Response::Err {
                message: format!(
                    "unknown variant '{variant}'. Available: {}",
                    PALETTE_VARIANTS.join(", ")
                ),
            };
        }

        {
            let mut params = self.matugen_params.write().await;
            params.scheme_type = normalized;
        }

        // Regenerate
        if let Some(path) = self.current_path.read().await.clone() {
            let params = self.matugen_params.read().await.clone();
            self.matugen_runner.run(Path::new(&path), &params).await;
        }

        Response::Ok(ResponsePayload::Empty)
    }

    pub async fn handle_theme_palette_list(&self) -> Response {
        let variants = PALETTE_VARIANTS.iter().map(|s| s.to_string()).collect();
        Response::Ok(ResponsePayload::PaletteVariants(variants))
    }

    pub async fn handle_theme_palette_current(&self) -> Response {
        let params = self.matugen_params.read().await;
        Response::Ok(ResponsePayload::Text(params.scheme_type.clone()))
    }

    // ════════════════════════════════════════════════════════════════════
    //  Config / Profile handlers
    // ════════════════════════════════════════════════════════════════════

    pub async fn handle_profile_save(&self, name: String) -> Response {
        info!("profile save: {name}");

        let current_path = self.current_path.read().await.clone();
        let params = self.matugen_params.read().await.clone();

        let profile = serde_json::json!({
            "current_path": current_path,
            "matugen_params": params,
        });

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
                "profile '{name}' saved"
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

        // Restore matugen params
        if let Some(mp) = profile.get("matugen_params") {
            if let Ok(params) = serde_json::from_value::<MatugenParams>(mp.clone()) {
                *self.matugen_params.write().await = params;
            }
        }

        // Restore wallpaper
        if let Some(cp) = profile.get("current_path").and_then(|v| v.as_str()) {
            let set_args = WpSetRequest {
                path: cp.to_string(),
                awww: AwwwOpts::default(),
                no_theme: false,
            };
            return self.handle_wp_set(set_args).await;
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
            Ok(()) => Response::Ok(ResponsePayload::Text(format!("profile '{name}' deleted"))),
            Err(e) => Response::Err {
                message: format!("failed to delete: {e}"),
            },
        }
    }

    pub async fn handle_config_edit(&self) -> Response {
        let config_path = config_dir().join("config.toml");

        if !config_path.exists() {
            if let Some(parent) = config_path.parent() {
                std::fs::create_dir_all(parent).ok();
            }
            std::fs::write(
                &config_path,
                "# walltool configuration\n\n[awww.defaults]\n# resize = \"crop\"\n# fill_color = \"000000ff\"\n# transition_type = \"grow\"\n",
            ).ok();
        }

        Response::Ok(ResponsePayload::Text(config_path.to_string_lossy().to_string()))
    }

    pub async fn handle_config_set_awww_default(&self, key: String, value: String) -> Response {
        info!("config set awww default: {key} = {value}");

        let config_path = config_dir().join("config.toml");

        // Ensure config exists
        if !config_path.exists() {
            if let Some(parent) = config_path.parent() {
                if let Err(e) = std::fs::create_dir_all(parent) {
                    return Response::Err {
                        message: format!("failed to create config dir: {e}"),
                    };
                }
            }
            std::fs::write(
                &config_path,
                "# walltool configuration\n\n[awww.defaults]\n",
            ).ok();
        }

        // Read current config
        let content = match std::fs::read_to_string(&config_path) {
            Ok(c) => c,
            Err(e) => {
                return Response::Err {
                    message: format!("failed to read config: {e}"),
                };
            }
        };

        // Parse as TOML
        let mut doc: toml_edit::DocumentMut = match content.parse() {
            Ok(d) => d,
            Err(e) => {
                return Response::Err {
                    message: format!("failed to parse config: {e}"),
                };
            }
        };

        // Ensure [awww.defaults] exists
        if !doc.contains_key("awww") {
            doc["awww"] = toml_edit::table();
        }
        if !doc["awww"].is_table() {
            doc["awww"] = toml_edit::table();
        }
        let awww = doc["awww"].as_table_mut().unwrap();
        if !awww.contains_key("defaults") {
            awww["defaults"] = toml_edit::table();
        }

        // Set the value
        let defaults = awww["defaults"].as_table_mut().unwrap();

        // Store value for error message before consuming
        let value_display = value.clone();

        // Parse value based on key
        match key.as_str() {
            "resize" | "fill_color" | "filter" | "transition_type" | "transition_pos"
            | "transition_bezier" | "transition_wave" => {
                defaults[&key] = toml_edit::value(value);
            }
            "transition_step" => {
                match value.parse::<u8>() {
                    Ok(v) => defaults[&key] = toml_edit::value(v as i64),
                    Err(_) => return Response::Err {
                        message: format!("invalid u8 value: {value}"),
                    },
                }
            }
            "transition_duration" | "transition_angle" => {
                match value.parse::<f64>() {
                    Ok(v) => defaults[&key] = toml_edit::value(v),
                    Err(_) => return Response::Err {
                        message: format!("invalid f64 value: {value}"),
                    },
                }
            }
            "transition_fps" => {
                match value.parse::<u32>() {
                    Ok(v) => defaults[&key] = toml_edit::value(v as i64),
                    Err(_) => return Response::Err {
                        message: format!("invalid u32 value: {value}"),
                    },
                }
            }
            "invert_y" => {
                match value.parse::<bool>() {
                    Ok(v) => defaults[&key] = toml_edit::value(v),
                    Err(_) => return Response::Err {
                        message: format!("invalid bool value: {value}"),
                    },
                }
            }
            _ => {
                return Response::Err {
                    message: format!("unknown config key: {key}"),
                };
            }
        }

        // Write back
        match std::fs::write(&config_path, doc.to_string()) {
            Ok(()) => Response::Ok(ResponsePayload::Text(format!("set {key} = {value_display}"))),
            Err(e) => Response::Err {
                message: format!("failed to write config: {e}"),
            },
        }
    }

    pub async fn handle_config_get_awww_defaults(&self) -> Response {
        // Read fresh config from file to ensure we get latest values
        // (especially after set-awww-default was called)
        let fresh_config = match Config::load() {
            Ok(c) => c,
            Err(e) => {
                // Fall back to cached config on error
                warn!("failed to reload config, using cached: {e}");
                self.config.clone()
            }
        };

        let opts = AwwwOpts {
            outputs: None,
            namespace: fresh_config.awww.global.namespace.clone(),
            resize: fresh_config.awww.defaults.resize.clone(),
            fill_color: fresh_config.awww.defaults.fill_color.clone(),
            filter: fresh_config.awww.defaults.filter.clone(),
            transition_type: fresh_config.awww.defaults.transition_type.clone(),
            transition_step: fresh_config.awww.defaults.transition_step,
            transition_duration: fresh_config.awww.defaults.transition_duration,
            transition_fps: fresh_config.awww.defaults.transition_fps,
            transition_angle: fresh_config.awww.defaults.transition_angle,
            transition_pos: fresh_config.awww.defaults.transition_pos.clone(),
            transition_bezier: fresh_config.awww.defaults.transition_bezier.clone(),
            transition_wave: fresh_config.awww.defaults.transition_wave.clone(),
            invert_y: fresh_config.awww.defaults.invert_y.unwrap_or(false),
        };
        Response::Ok(ResponsePayload::AwwwOpts(opts))
    }

    pub async fn handle_config_set_slideshow_option(&self, key: String, value: String) -> Response {
        info!("config set slideshow option: {key} = {value}");

        let config_path = config_dir().join("config.toml");

        // Ensure config exists
        if !config_path.exists() {
            if let Some(parent) = config_path.parent() {
                if let Err(e) = std::fs::create_dir_all(parent) {
                    return Response::Err {
                        message: format!("failed to create config dir: {e}"),
                    };
                }
            }
            std::fs::write(
                &config_path,
                "# walltool configuration\n\n[slideshow]\n",
            ).ok();
        }

        // Read current config
        let content = match std::fs::read_to_string(&config_path) {
            Ok(c) => c,
            Err(e) => {
                return Response::Err {
                    message: format!("failed to read config: {e}"),
                };
            }
        };

        // Parse as TOML
        let mut doc: toml_edit::DocumentMut = match content.parse() {
            Ok(d) => d,
            Err(e) => {
                return Response::Err {
                    message: format!("failed to parse config: {e}"),
                };
            }
        };

        // Ensure [slideshow] exists
        if !doc.contains_key("slideshow") {
            doc["slideshow"] = toml_edit::table();
        }

        let slideshow = doc["slideshow"].as_table_mut().unwrap();
        let value_display = value.clone();

        // Parse value based on key
        match key.as_str() {
            "dir" | "text_filter" => {
                if value.is_empty() || value == "null" {
                    slideshow.remove(&key);
                } else {
                    slideshow[&key] = toml_edit::value(value);
                }
            }
            "interval" => {
                match value.parse::<u64>() {
                    Ok(v) => slideshow[&key] = toml_edit::value(v as i64),
                    Err(_) => return Response::Err {
                        message: format!("invalid u64 value: {value}"),
                    },
                }
            }
            "include_hidden" | "only_hidden" | "only_favorites" => {
                match value.parse::<bool>() {
                    Ok(v) => slideshow[&key] = toml_edit::value(v),
                    Err(_) => return Response::Err {
                        message: format!("invalid bool value: {value}"),
                    },
                }
            }
            _ => {
                return Response::Err {
                    message: format!("unknown slideshow config key: {key}"),
                };
            }
        }

        // Write back
        match std::fs::write(&config_path, doc.to_string()) {
            Ok(()) => Response::Ok(ResponsePayload::Text(format!("set slideshow.{key} = {value_display}"))),
            Err(e) => Response::Err {
                message: format!("failed to write config: {e}"),
            },
        }
    }

    pub async fn handle_config_get_slideshow_options(&self) -> Response {
        // Read fresh config from file
        let fresh_config = match Config::load() {
            Ok(c) => c,
            Err(e) => {
                warn!("failed to reload config: {e}");
                self.config.clone()
            }
        };

        let opts = SlideshowOpts {
            dir: fresh_config.slideshow.dir.map(|p| p.to_string_lossy().to_string()),
            interval: fresh_config.slideshow.interval,
            include_hidden: fresh_config.slideshow.include_hidden,
            only_hidden: fresh_config.slideshow.only_hidden,
            only_favorites: fresh_config.slideshow.only_favorites,
            text_filter: fresh_config.slideshow.text_filter,
        };
        Response::Ok(ResponsePayload::SlideshowOpts(opts))
    }


    // ════════════════════════════════════════════════════════════════════
        //  Config: show full config
        // ════════════════════════════════════════════════════════════════════

        pub async fn handle_config_show(&self) -> Response {
            let config_path = config_dir().join("config.toml");

            // If file doesn't exist, return stringified default config
            if !config_path.exists() {
                let default_cfg = Config::default();
                return match toml::to_string_pretty(&default_cfg) {
                    Ok(s) => Response::Ok(ResponsePayload::ConfigFull(s)),
                    Err(e) => Response::Err { message: format!("serialize default config: {e}") },
                };
            }

            match std::fs::read_to_string(&config_path) {
                Ok(content) => Response::Ok(ResponsePayload::ConfigFull(content)),
                Err(e) => Response::Err {
                    message: format!("failed to read config: {e}"),
                },
            }
        }

        // ════════════════════════════════════════════════════════════════════
        //  Config: awww.global.namespace
        // ════════════════════════════════════════════════════════════════════

        pub async fn handle_config_get_namespace(&self) -> Response {
            let cfg = Config::load().unwrap_or_else(|_| self.config.clone());
            let ns = cfg.awww.global.namespace
                .unwrap_or_else(|| "(not set)".into());
            Response::Ok(ResponsePayload::Text(ns))
        }

        pub async fn handle_config_set_namespace(&self, value: String) -> Response {
            info!("config set namespace: {:?}", value);

            let ns_opt: Option<String> = if value.is_empty() || value == "null" {
                None
            } else {
                Some(value.clone())
            };

            match self.update_toml(|doc| {
                ensure_table(doc, &["awww", "global"]);
                let global = doc["awww"]["global"].as_table_mut().unwrap();
                match &ns_opt {
                    Some(v) => { global["namespace"] = toml_edit::value(v.clone()); }
                    None    => { global.remove("namespace"); }
                }
            }) {
                Ok(()) => Response::Ok(ResponsePayload::Text(
                    format!("namespace = {:?}", ns_opt.as_deref().unwrap_or("(cleared)"))
                )),
                Err(e) => Response::Err { message: e },
            }
        }

        // ════════════════════════════════════════════════════════════════════
        //  Config: awww.monitor.<name>
        // ════════════════════════════════════════════════════════════════════

        pub async fn handle_config_list_monitor_configs(&self) -> Response {
            let cfg = Config::load().unwrap_or_else(|_| self.config.clone());

            let entries: Vec<MonitorConfigEntry> = cfg.awww.monitor
                .into_iter()
                .map(|(monitor, d)| MonitorConfigEntry {
                    monitor,
                    options: MonitorAwwwOpts {
                        resize: d.resize,
                        fill_color: d.fill_color,
                        filter: d.filter,
                        transition_type: d.transition_type,
                        transition_step: d.transition_step,
                        transition_duration: d.transition_duration,
                        transition_fps: d.transition_fps,
                        transition_angle: d.transition_angle,
                        transition_pos: d.transition_pos,
                        transition_bezier: d.transition_bezier,
                        transition_wave: d.transition_wave,
                        invert_y: d.invert_y,
                    },
                })
                .collect();

            Response::Ok(ResponsePayload::MonitorConfigs(entries))
        }

        pub async fn handle_config_get_monitor_options(&self, monitor: String) -> Response {
            let cfg = Config::load().unwrap_or_else(|_| self.config.clone());

            let opts = cfg.awww.monitor.get(&monitor)
                .map(|d| MonitorAwwwOpts {
                    resize: d.resize.clone(),
                    fill_color: d.fill_color.clone(),
                    filter: d.filter.clone(),
                    transition_type: d.transition_type.clone(),
                    transition_step: d.transition_step,
                    transition_duration: d.transition_duration,
                    transition_fps: d.transition_fps,
                    transition_angle: d.transition_angle,
                    transition_pos: d.transition_pos.clone(),
                    transition_bezier: d.transition_bezier.clone(),
                    transition_wave: d.transition_wave.clone(),
                    invert_y: d.invert_y,
                })
                .unwrap_or_default();

            Response::Ok(ResponsePayload::MonitorOpts(opts))
        }

        pub async fn handle_config_set_monitor_option(
            &self,
            monitor: String,
            key: String,
            value: String,
        ) -> Response {
            info!("config set monitor {monitor} {key} = {value}");

            let value_display = value.clone();
            let monitor_key = monitor.clone();

            let result = self.update_toml(|doc| {
                // [awww.monitor."DP-1"]
                ensure_table(doc, &["awww", "monitor"]);
                let mon_table = doc["awww"]["monitor"].as_table_mut().unwrap();
                if !mon_table.contains_key(&monitor_key) {
                    mon_table[&monitor_key] = toml_edit::table();
                }
                let entry = mon_table[&monitor_key].as_table_mut().unwrap();

                match key.as_str() {
                    "resize" | "fill_color" | "filter" | "transition_type"
                    | "transition_pos" | "transition_bezier" | "transition_wave" => {
                        entry[&key] = toml_edit::value(value.clone());
                    }
                    "transition_step" => {
                        entry[&key] = toml_edit::value(
                            value.parse::<u8>().map_err(|_| ())
                                .map(|v| v as i64)
                                .unwrap_or(90i64)
                        );
                    }
                    "transition_duration" | "transition_angle" => {
                        if let Ok(v) = value.parse::<f64>() {
                            entry[&key] = toml_edit::value(v);
                        }
                    }
                    "transition_fps" => {
                        if let Ok(v) = value.parse::<u32>() {
                            entry[&key] = toml_edit::value(v as i64);
                        }
                    }
                    "invert_y" => {
                        if let Ok(v) = value.parse::<bool>() {
                            entry[&key] = toml_edit::value(v);
                        }
                    }
                    _ => {}
                }
            });

            match result {
                Ok(()) => Response::Ok(ResponsePayload::Text(
                    format!("[awww.monitor.{monitor}] {key} = {value_display}")
                )),
                Err(e) => Response::Err { message: e },
            }
        }

        pub async fn handle_config_rm_monitor_options(&self, monitor: String) -> Response {
            info!("config rm monitor: {monitor}");

            let mon = monitor.clone();
            let result = self.update_toml(|doc| {
                if let Some(awww) = doc.get_mut("awww") {
                    if let Some(mon_table) = awww.get_mut("monitor") {
                        if let Some(t) = mon_table.as_table_mut() {
                            t.remove(&mon);
                        }
                    }
                }
            });

            match result {
                Ok(()) => Response::Ok(ResponsePayload::Text(
                    format!("removed monitor config for {monitor}")
                )),
                Err(e) => Response::Err { message: e },
            }
        }

        // ════════════════════════════════════════════════════════════════════
        //  Config: matugen.defaults
        // ════════════════════════════════════════════════════════════════════

        pub async fn handle_config_get_matugen_defaults(&self) -> Response {
            let cfg = Config::load().unwrap_or_else(|_| self.config.clone());
            // Reuse MatugenParams / ThemeParams payload
            let params = cfg.default_matugen_params();
            Response::Ok(ResponsePayload::ThemeParams(params))
        }

        pub async fn handle_config_set_matugen_default(&self, key: String, value: String) -> Response {
            info!("config set matugen default: {key} = {value}");

            let value_display = value.clone();

            let result = self.update_toml(|doc| {
                ensure_table(doc, &["matugen", "defaults"]);
                let defaults = doc["matugen"]["defaults"].as_table_mut().unwrap();
                let is_null = value == "null" || value.is_empty();

                match key.as_str() {
                    "mode" | "scheme_type" | "prefer" | "fallback_color" => {
                        if is_null {
                            defaults.remove(&key);
                        } else {
                            defaults[&key] = toml_edit::value(value.clone());
                        }
                    }
                    "contrast" | "opacity" | "lightness_dark" | "lightness_light" => {
                        if is_null {
                            defaults.remove(&key);
                        } else if let Ok(v) = value.parse::<f64>() {
                            defaults[&key] = toml_edit::value(v);
                        }
                    }
                    "source_color_index" => {
                        if is_null {
                            defaults.remove(&key);
                        } else if let Ok(v) = value.parse::<u8>() {
                            defaults[&key] = toml_edit::value(v as i64);
                        }
                    }
                    _ => {}
                }
            });

            match result {
                Ok(()) => Response::Ok(ResponsePayload::Text(
                    format!("[matugen.defaults] {key} = {value_display}")
                )),
                Err(e) => Response::Err { message: e },
            }
        }

        // ════════════════════════════════════════════════════════════════════
        //  Config: theme.auto
        // ════════════════════════════════════════════════════════════════════

        pub async fn handle_config_get_theme_auto(&self) -> Response {
            let cfg = Config::load().unwrap_or_else(|_| self.config.clone());
            Response::Ok(ResponsePayload::ThemeAutoOpts(ThemeAutoOptsInfo {
                sunrise: cfg.theme.auto.sunrise,
                sunset: cfg.theme.auto.sunset,
            }))
        }

        pub async fn handle_config_set_theme_auto(&self, key: String, value: String) -> Response {
            info!("config set theme auto: {key} = {value}");

            if key != "sunrise" && key != "sunset" {
                return Response::Err {
                    message: format!("unknown key '{key}'. Valid: sunrise | sunset"),
                };
            }

            // Validate HH:MM format
            if crate::config::parse_time(&value).is_none() {
                return Response::Err {
                    message: format!("invalid time format '{value}'. Use HH:MM (e.g. 07:00)"),
                };
            }

            let value_display = value.clone();
            let result = self.update_toml(|doc| {
                ensure_table(doc, &["theme", "auto"]);
                doc["theme"]["auto"][&key] = toml_edit::value(value.clone());
            });

            match result {
                Ok(()) => Response::Ok(ResponsePayload::Text(
                    format!("[theme.auto] {key} = {value_display}")
                )),
                Err(e) => Response::Err { message: e },
            }
        }

        // ════════════════════════════════════════════════════════════════════
        //  Config: indexer
        // ════════════════════════════════════════════════════════════════════

        pub async fn handle_config_get_indexer(&self) -> Response {
            let cfg = Config::load().unwrap_or_else(|_| self.config.clone());
            Response::Ok(ResponsePayload::IndexerOpts(IndexerOptsInfo {
                watch_dirs: cfg.indexer.watch_dirs
                    .iter()
                    .map(|p| p.to_string_lossy().to_string())
                    .collect(),
                ai_tagging: cfg.indexer.ai_tagging,
            }))
        }

        pub async fn handle_config_set_indexer(&self, key: String, value: String) -> Response {
            info!("config set indexer: {key} = {value}");

            let value_display = value.clone();
            let result = self.update_toml(|doc| {
                ensure_table(doc, &["indexer"]);
                let indexer = doc["indexer"].as_table_mut().unwrap();

                match key.as_str() {
                    "ai_tagging" => {
                        if let Ok(v) = value.parse::<bool>() {
                            indexer["ai_tagging"] = toml_edit::value(v);
                        }
                    }
                    "add_watch_dir" => {
                        // Append to watch_dirs array
                        let arr = indexer
                            .entry("watch_dirs")
                            .or_insert(toml_edit::Item::Value(
                                toml_edit::Value::Array(toml_edit::Array::new())
                            ));
                        if let Some(a) = arr.as_array_mut() {
                            // Avoid duplicates
                            let already: Vec<String> = a
                                .iter()
                                .filter_map(|v| v.as_str().map(str::to_string))
                                .collect();
                            if !already.contains(&value) {
                                a.push(value.clone());
                            }
                        }
                    }
                    "rm_watch_dir" => {
                        if let Some(arr) = indexer.get_mut("watch_dirs")
                            .and_then(|i| i.as_array_mut())
                        {
                            let to_remove = value.clone();
                            // Rebuild without the entry
                            let kept: Vec<String> = arr
                                .iter()
                                .filter_map(|v| v.as_str().map(str::to_string))
                                .filter(|s| s != &to_remove)
                                .collect();
                            *arr = toml_edit::Array::new();
                            for s in kept { arr.push(s); }
                        }
                    }
                    _ => {}
                }
            });

            match result {
                Ok(()) => Response::Ok(ResponsePayload::Text(
                    format!("[indexer] {key} = {value_display}")
                )),
                Err(e) => Response::Err { message: e },
            }
        }

        // ════════════════════════════════════════════════════════════════════
        //  Shared TOML editing helper
        // ════════════════════════════════════════════════════════════════════

        /// Load config.toml as a toml_edit Document, apply `mutator`, then write back.
        /// Returns Err(String) on any I/O or parse failure.
        fn update_toml<F>(&self, mutator: F) -> Result<(), String>
        where
            F: FnOnce(&mut toml_edit::DocumentMut),
        {
            let config_path = config_dir().join("config.toml");

            // Ensure file exists
            if !config_path.exists() {
                if let Some(parent) = config_path.parent() {
                    std::fs::create_dir_all(parent)
                        .map_err(|e| format!("create config dir: {e}"))?;
                }
                std::fs::write(&config_path, "# walltool configuration\n")
                    .map_err(|e| format!("create config file: {e}"))?;
            }

            let content = std::fs::read_to_string(&config_path)
                .map_err(|e| format!("read config: {e}"))?;

            let mut doc: toml_edit::DocumentMut = content
                .parse()
                .map_err(|e| format!("parse config: {e}"))?;

            mutator(&mut doc);

            std::fs::write(&config_path, doc.to_string())
                .map_err(|e| format!("write config: {e}"))?;

            Ok(())
        }
    // ════════════════════════════════════════════════════════════════════
    //  Monitor handlers
    // ════════════════════════════════════════════════════════════════════

    pub async fn handle_monitor_list(&self) -> Response {
        info!("monitor list");

        match awww::run_awww_query().await {
            Ok(json) => {
                // Parse awww query output into MonitorInfo
                let monitors = parse_awww_monitors(&json);
                Response::Ok(ResponsePayload::Monitors(monitors))
            }
            Err(e) => Response::Err {
                message: format!("awww query failed: {e:#}"),
            },
        }
    }

    pub async fn handle_monitor_identify(&self) -> Response {
        info!("monitor identify");
        // Write signal file for QML
        let signal_path = cache_dir().join("identify_signal");
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis();
        std::fs::write(&signal_path, ts.to_string()).ok();
        Response::Ok(ResponsePayload::Text("identify signal written".into()))
    }

    // ════════════════════════════════════════════════════════════════════
    //  Daemon control handlers
    // ════════════════════════════════════════════════════════════════════

    pub async fn handle_status(&self) -> Response {
        let uptime = self.started_at.elapsed().as_secs();
        let game_mode = *self.game_mode.read().await;
        let memory_mb = get_rss_mb().unwrap_or(0.0);
        let preview_active = self.preview_backup.read().await.is_some();

        let slideshow = self.slideshow.read().await;
        let slideshow_active = slideshow.is_active();
        let slideshow_interval = slideshow.current_interval();
        drop(slideshow);

        let indexing = self.indexer_state.is_active();
        let index_queue_size = self.indexer_state.pending();

        let info = crate::ipc::DaemonStatusInfo {
            uptime_secs: uptime,
            memory_mb,
            slideshow_active,
            slideshow_interval,
            indexing,
            index_queue_size,
            game_mode,
            preview_active,
        };

        Response::Ok(ResponsePayload::DaemonStatus(info))
    }

    pub async fn handle_stop(&self) -> Response {
        info!("daemon stop requested");

        {
            let mut slideshow = self.slideshow.write().await;
            slideshow.cancel_all();
        }

        {
            let mut handles = self.indexer_handles.write().await;
            for h in handles.drain(..) {
                h.abort();
            }
        }

        let _ = self.shutdown_tx.send(());
        Response::Ok(ResponsePayload::Text("daemon shutting down".into()))
    }

    pub async fn handle_pause_all(&self) -> Response {
        info!("pause-all (game mode ON)");
        *self.game_mode.write().await = true;

        // Pause awww daemon
        if let Err(e) = awww::run_awww_pause(None).await {
            warn!("awww pause failed: {e:#}");
        }

        self.indexer_state.pause();

        Response::Ok(ResponsePayload::Text("game mode: ON".into()))
    }

    pub async fn handle_resume_all(&self) -> Response {
        info!("resume-all (game mode OFF)");
        *self.game_mode.write().await = false;

        // Restore with instant transition
        if let Some(path) = self.current_path.read().await.clone() {
            let opts = awww::instant_transition_opts();
            let _ = awww::run_awww_img(&path, &opts).await;
        }

        self.indexer_state.resume();

        Response::Ok(ResponsePayload::Text("game mode: OFF".into()))
    }

    pub async fn handle_slideshow_start(self: &Arc<Self>, args: SlideshowStartRequest) -> Response {
        info!(
            "slideshow start: dir={} interval={}s",
            args.dir.display(),
            args.interval,
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

        Response::Ok(ResponsePayload::Text(format!(
            "slideshow started — {}s interval",
            args.interval
        )))
    }

    pub async fn handle_slideshow_stop(&self, monitor: Option<String>) -> Response {
        info!("slideshow stop: monitor={monitor:?}");
        let mut slideshow = self.slideshow.write().await;
        slideshow.stop(monitor.as_deref());
        Response::Ok(ResponsePayload::Empty)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Helpers
// ══════════════════════════════════════════════════════════════════════════════

fn canonicalize_path(path: &str) -> String {
    if path.starts_with("http://") || path.starts_with("https://") {
        return path.to_string();
    }
    std::fs::canonicalize(path)
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|_| path.to_string())
}

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

fn get_rss_mb() -> Option<f64> {
    let statm = std::fs::read_to_string("/proc/self/statm").ok()?;
    let rss_pages: u64 = statm.split_whitespace().nth(1)?.parse().ok()?;
    let page_size = 4096u64;
    Some((rss_pages * page_size) as f64 / (1024.0 * 1024.0))
}

fn parse_awww_monitors(json: &serde_json::Value) -> Vec<crate::ipc::MonitorInfo> {
    // awww query returns array of outputs
    let Some(arr) = json.as_array() else {
        return Vec::new();
    };

    arr.iter()
        .filter_map(|v| {
            let name = v.get("name")?.as_str()?.to_string();
            let width = v.get("width")?.as_u64()? as u32;
            let height = v.get("height")?.as_u64()? as u32;
            let x = v.get("x").and_then(|v| v.as_i64()).unwrap_or(0) as i32;
            let y = v.get("y").and_then(|v| v.as_i64()).unwrap_or(0) as i32;
            let scale = v.get("scale").and_then(|v| v.as_f64()).unwrap_or(1.0);

            Some(crate::ipc::MonitorInfo {
                name,
                width,
                height,
                x,
                y,
                scale,
            })
        })
        .collect()
}

/// Pick a random file from a directory
async fn pick_random_file(dir: &Path, search: &crate::ipc::SearchOpts) -> Result<Option<PathBuf>> {
    let dir = dir.to_path_buf();
    let include_dot = search.include_dot;
    let only_dot = search.only_dot;
    let query = search.query.clone();

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

            if !is_supported_media(path) {
                continue;
            }

            // Query filter
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
    .context("file picker panicked")?
}

fn is_supported_media(path: &Path) -> bool {
    let Some(ext) = path.extension().and_then(|e| e.to_str()) else {
        return false;
    };

    matches!(
        ext.to_ascii_lowercase().as_str(),
        "jpg" | "jpeg" | "png" | "gif" | "webp" | "bmp" | "tiff" | "tif" | "avif"
            | "heic" | "mp4" | "mkv" | "webm" | "avi" | "mov"
    )
}

fn ensure_table(doc: &mut toml_edit::DocumentMut, path: &[&str]) {
    let mut cur = doc.as_item_mut();
    for &key in path {
        if cur.get(key).is_none() {
            cur[key] = toml_edit::table();
        }
        cur = cur.get_mut(key).unwrap();
    }
}
