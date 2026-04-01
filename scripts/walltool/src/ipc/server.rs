use std::sync::Arc;

use anyhow::{Context, Result};
use tokio::net::UnixListener;
use tokio::sync::broadcast;
use tracing::{debug, error, info, warn};

use super::framing::{read_message, write_message};
use super::{socket_path, Request, Response, ResponsePayload};
use crate::daemon::Daemon;

/// Start the IPC server loop. Listens on the Unix socket and dispatches
/// incoming requests to the daemon's handler.
///
/// `shutdown_rx` is used to signal a graceful stop from the outside
/// (e.g. when the daemon receives `DaemonStop`).
pub async fn run_server(
    daemon: Arc<Daemon>,
    mut shutdown_rx: broadcast::Receiver<()>,
) -> Result<()> {
    let path = socket_path();

    // Remove stale socket file if it exists from a previous crash.
    if path.exists() {
        std::fs::remove_file(&path)
            .with_context(|| format!("failed to remove stale socket at {}", path.display()))?;
    }

    // Ensure the parent directory exists.
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).ok();
    }

    let listener = UnixListener::bind(&path)
        .with_context(|| format!("failed to bind Unix socket at {}", path.display()))?;

    // Make socket world-accessible (user-level runtime dir is already private).
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o700)).ok();
    }

    info!("IPC server listening on {}", path.display());

    loop {
        tokio::select! {
            // Accept new connections
            accept_result = listener.accept() => {
                match accept_result {
                    Ok((stream, _addr)) => {
                        let daemon = Arc::clone(&daemon);
                        tokio::spawn(async move {
                            if let Err(e) = handle_connection(stream, &daemon).await {
                                warn!("client connection error: {e:#}");
                            }
                        });
                    }
                    Err(e) => {
                        error!("failed to accept connection: {e}");
                    }
                }
            }

            // Shutdown signal
            _ = shutdown_rx.recv() => {
                info!("IPC server shutting down");
                break;
            }
        }
    }

    // Cleanup socket file on graceful exit
    if path.exists() {
        std::fs::remove_file(&path).ok();
    }

    Ok(())
}

/// Handle a single client connection: read one request, dispatch it, send
/// back the response, then close the connection.
///
/// The protocol is strictly request-response (one message per connection).
/// This keeps the implementation simple and stateless per-connection.
async fn handle_connection(
    stream: tokio::net::UnixStream,
    daemon: &Arc<Daemon>,
) -> Result<()> {
    let (mut reader, mut writer) = stream.into_split();

    // Read the incoming request
    let request: Request = match read_message(&mut reader).await {
        Ok(req) => req,
        Err(e) => {
            debug!("failed to read request: {e:#}");
            // Try to send an error response even if we couldn't parse the request
            let err_resp = Response::Err {
                message: format!("malformed request: {e}"),
            };
            let _ = write_message(&mut writer, &err_resp).await;
            return Ok(());
        }
    };

    debug!("received request: {request:?}");

    // Dispatch to the daemon handler
    let response = dispatch(daemon, request).await;

    // Send response back
    write_message(&mut writer, &response)
        .await
        .context("failed to send response")?;

    Ok(())
}

/// Map a [`Request`] to the appropriate daemon method and return a [`Response`].
///
/// This is the central routing table. Each arm calls into `Daemon` methods
/// that contain the actual business logic (state management, Hyprland IPC,
/// Matugen pipeline, SQLite queries, etc.).
///
/// During early development, unimplemented commands return a descriptive
/// `Response::Err` so the CLI doesn't hang silently.
async fn dispatch(daemon: &Arc<Daemon>, request: Request) -> Response {
    match request {
        // ── Ping ─────────────────────────────────────────────────────
        Request::Ping => Response::Ok(ResponsePayload::Pong),

        // ── Wallpaper ────────────────────────────────────────────────
        Request::WpSet(args) => daemon.handle_wp_set(args).await,
        Request::WpRandom(args) => daemon.handle_wp_random(args).await,
        Request::WpSearch(args) => daemon.handle_wp_search(args).await,
        Request::WpIndex(args) => daemon.handle_wp_index(args).await,
        Request::WpClear { monitor } => daemon.handle_wp_clear(monitor).await,
        Request::WpCurrent { monitor } => daemon.handle_wp_current(monitor).await,
        Request::WpPlay { monitor } => daemon.handle_wp_play(monitor).await,
        Request::WpPause { monitor } => daemon.handle_wp_pause(monitor).await,
        Request::WpToggleMute { monitor } => daemon.handle_wp_toggle_mute(monitor).await,
        Request::WpToggleHidden { path } => daemon.handle_wp_toggle_hidden(path).await,

        // ── History ──────────────────────────────────────────────────
        Request::HistoryList { limit } => daemon.handle_history_list(limit).await,
        Request::HistoryPrev => daemon.handle_history_prev().await,
        Request::HistoryNext => daemon.handle_history_next().await,
        Request::HistoryClear => daemon.handle_history_clear().await,

        // ── Favorites ────────────────────────────────────────────────
        Request::FavAdd { path } => daemon.handle_fav_add(path).await,
        Request::FavRm { target } => daemon.handle_fav_rm(target).await,
        Request::FavList { limit } => daemon.handle_fav_list(limit).await,
        Request::FavSetRandom(opts) => daemon.handle_fav_set_random(opts).await,

        // ── Theme ────────────────────────────────────────────────────
        Request::ThemeGenerate { path } => daemon.handle_theme_generate(path).await,
        Request::ThemeModeSet { mode } => daemon.handle_theme_mode_set(mode).await,
        Request::ThemeModeToggle => daemon.handle_theme_mode_toggle().await,
        Request::ThemeModeAuto => daemon.handle_theme_mode_auto().await,
        Request::ThemeModeCurrent => daemon.handle_theme_mode_current().await,
        Request::ThemePaletteSet { variant } => daemon.handle_theme_palette_set(variant).await,
        Request::ThemePaletteList => daemon.handle_theme_palette_list().await,
        Request::ThemePaletteCurrent => daemon.handle_theme_palette_current().await,

        // ── Config / Profiles ────────────────────────────────────────
        Request::ProfileSave { name } => daemon.handle_profile_save(name).await,
        Request::ProfileLoad { name } => daemon.handle_profile_load(name).await,
        Request::ProfileList => daemon.handle_profile_list().await,
        Request::ProfileRm { name } => daemon.handle_profile_rm(name).await,
        Request::ConfigEdit => daemon.handle_config_edit().await,

        // ── Monitor ──────────────────────────────────────────────────
        Request::MonitorList => daemon.handle_monitor_list().await,
        Request::MonitorIdentify => daemon.handle_monitor_identify().await,

        // ── Daemon ───────────────────────────────────────────────────
        Request::DaemonStatus => daemon.handle_status().await,
        Request::DaemonStop => daemon.handle_stop().await,
        Request::DaemonPauseAll => daemon.handle_pause_all().await,
        Request::DaemonResumeAll => daemon.handle_resume_all().await,
        Request::SlideshowStart(args) => daemon.handle_slideshow_start(args).await,
        Request::SlideshowStop { monitor } => daemon.handle_slideshow_stop(monitor).await,
    }
}
