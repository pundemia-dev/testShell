mod cli;
mod daemon;
mod db;
mod ipc;

use anyhow::{bail, Context, Result};
use clap::Parser;
use tokio::sync::broadcast;
use tracing::{info, warn};
use tracing_subscriber::EnvFilter;

use std::sync::Arc;

use cli::*;
use ipc::client::send_and_print;
use ipc::{
    DisplayOpts, MediaOpts, Request, SlideshowStartRequest, WpIndexRequest, WpRandomRequest,
    WpSearchRequest, WpSetRequest,
};

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // ── Logging ─────────────────────────────────────────────────────────
    let filter = if cli.verbose {
        "walltool=debug,info"
    } else {
        "walltool=info,warn"
    };
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new(filter)),
        )
        .with_target(false)
        .init();

    // ── Special case: `daemon start` runs the server in-process ─────────
    if let Commands::Daemon {
        action: DaemonAction::Start,
    } = &cli.command
    {
        return run_daemon().await;
    }

    // ── Everything else: build a Request and send it to the daemon ──────
    let request = build_request(&cli.command)?;
    send_and_print(&request, cli.json).await
}

// ── Daemon entry point ──────────────────────────────────────────────────────

async fn run_daemon() -> Result<()> {
    info!("walltool daemon starting");

    let (shutdown_tx, shutdown_rx) = broadcast::channel::<()>(1);

    let daemon = Arc::new(
        daemon::Daemon::new(shutdown_tx.clone())
            .context("failed to initialize daemon")?,
    );

    // ── Initial monitor sync (populate state from Hyprland) ─────────
    daemon::hyprland::sync_monitors_initial(&daemon).await;

    // ── Spawn IPC server ────────────────────────────────────────────
    let server_daemon = Arc::clone(&daemon);
    let server_handle = tokio::spawn(async move {
        if let Err(e) = ipc::server::run_server(server_daemon, shutdown_rx).await {
            tracing::error!("IPC server error: {e:#}");
        }
    });

    // ── Spawn Hyprland event listener for monitor hotplug ───────────
    let hypr_handle = daemon::hyprland::spawn_hyprland_listener(
        Arc::clone(&daemon),
        shutdown_tx.clone(),
    );

    // ── Handle SIGTERM / SIGINT for graceful shutdown ────────────────
    let sig_shutdown_tx = shutdown_tx.clone();
    tokio::spawn(async move {
        match tokio::signal::ctrl_c().await {
            Ok(()) => {
                info!("received SIGINT, initiating graceful shutdown");
                let _ = sig_shutdown_tx.send(());
            }
            Err(e) => {
                warn!("failed to listen for ctrl-c: {e}");
            }
        }
    });

    // ── Wait for the IPC server to finish (blocks until shutdown) ────
    server_handle
        .await
        .context("IPC server task panicked")?;

    // The Hyprland listener is a blocking task — abort it on shutdown
    hypr_handle.abort();
    let _ = hypr_handle.await;

    info!("walltool daemon stopped");
    Ok(())
}

// ── CLI → IPC Request mapping ───────────────────────────────────────────────

fn build_request(command: &Commands) -> Result<Request> {
    let request = match command {
        // ── Wallpaper ────────────────────────────────────────────────
        Commands::Wallpaper { action } => match action {
            WallpaperAction::Set(args) => Request::WpSet(WpSetRequest {
                path: args.path.clone(),
                display: display_opts_from(&args.display),
                media: media_opts_from(&args.media),
            }),

            WallpaperAction::Random(args) => Request::WpRandom(WpRandomRequest {
                dir: args.dir.clone(),
                media_type: args.media_type.as_ref().map(|t| media_type_str(t)),
                recursive: args.recursive,
                query: args.query.clone(),
                include_dot: args.dots.include_dot,
                only_dot: args.dots.only_dot,
                display: display_opts_from(&args.display),
                media: media_opts_from(&args.media),
            }),

            WallpaperAction::Search(args) => Request::WpSearch(WpSearchRequest {
                query: args.query.clone(),
                limit: args.limit,
                history: args.history,
                favorites: args.favorites,
                include_dot: args.dots.include_dot,
                only_dot: args.dots.only_dot,
            }),

            WallpaperAction::ToggleHidden { path } => Request::WpToggleHidden {
                path: path.clone(),
            },

            WallpaperAction::Index(args) => Request::WpIndex(WpIndexRequest {
                dir: args.dir.clone(),
                force: args.force,
            }),

            WallpaperAction::Clear { monitor } => Request::WpClear {
                monitor: monitor.clone(),
            },

            WallpaperAction::Current { monitor } => Request::WpCurrent {
                monitor: monitor.clone(),
            },

            WallpaperAction::Play { monitor } => Request::WpPlay {
                monitor: monitor.clone(),
            },

            WallpaperAction::Pause { monitor } => Request::WpPause {
                monitor: monitor.clone(),
            },

            WallpaperAction::ToggleMute { monitor } => Request::WpToggleMute {
                monitor: monitor.clone(),
            },

            // ── History ──────────────────────────────────────────────
            WallpaperAction::History { action } => match action {
                HistoryAction::List { limit } => Request::HistoryList { limit: *limit },
                HistoryAction::Prev => Request::HistoryPrev,
                HistoryAction::Next => Request::HistoryNext,
                HistoryAction::Clear => Request::HistoryClear,
            },

            // ── Favorites ────────────────────────────────────────────
            WallpaperAction::Fav { action } => match action {
                FavAction::Add { path } => Request::FavAdd {
                    path: path.clone(),
                },
                FavAction::Rm { target } => Request::FavRm {
                    target: target.clone(),
                },
                FavAction::List { limit } => Request::FavList { limit: *limit },
                FavAction::SetRandom { display, media } => {
                    let _ = media; // media opts used internally by daemon
                    Request::FavSetRandom(display_opts_from(display))
                }
            },
        },

        // ── Theme ────────────────────────────────────────────────────
        Commands::Theme { action } => match action {
            ThemeAction::Generate { path } => Request::ThemeGenerate { path: path.clone() },

            ThemeAction::Mode { action } => match action {
                ThemeModeAction::Set { mode } => Request::ThemeModeSet {
                    mode: match mode {
                        ThemeModeValue::Dark => "dark".into(),
                        ThemeModeValue::Light => "light".into(),
                    },
                },
                ThemeModeAction::Toggle => Request::ThemeModeToggle,
                ThemeModeAction::Auto => Request::ThemeModeAuto,
                ThemeModeAction::Current => Request::ThemeModeCurrent,
            },

            ThemeAction::Palette { action } => match action {
                ThemePaletteAction::Set { variant } => Request::ThemePaletteSet {
                    variant: variant.clone(),
                },
                ThemePaletteAction::List => Request::ThemePaletteList,
                ThemePaletteAction::Current => Request::ThemePaletteCurrent,
            },
        },

        // ── Config / Profiles ────────────────────────────────────────
        Commands::Config { action } => match action {
            ConfigAction::Profile { action } => match action {
                ProfileAction::Save { name } => Request::ProfileSave { name: name.clone() },
                ProfileAction::Load { name } => Request::ProfileLoad { name: name.clone() },
                ProfileAction::List => Request::ProfileList,
                ProfileAction::Rm { name } => Request::ProfileRm { name: name.clone() },
            },
            ConfigAction::Edit => Request::ConfigEdit,
        },

        // ── Monitor ──────────────────────────────────────────────────
        Commands::Monitor { action } => match action {
            MonitorAction::List => Request::MonitorList,
            MonitorAction::Identify => Request::MonitorIdentify,
        },

        // ── Daemon ───────────────────────────────────────────────────
        Commands::Daemon { action } => match action {
            // `Start` is handled before we get here — should be unreachable
            DaemonAction::Start => {
                bail!("daemon start should have been handled earlier");
            }
            DaemonAction::Stop => Request::DaemonStop,
            DaemonAction::Status => Request::DaemonStatus,
            DaemonAction::PauseAll => Request::DaemonPauseAll,
            DaemonAction::ResumeAll => Request::DaemonResumeAll,

            DaemonAction::Slideshow { action } => match action {
                SlideshowAction::Start(args) => Request::SlideshowStart(SlideshowStartRequest {
                    dir: args.dir.clone(),
                    interval: args.interval,
                    monitor: args.monitor.clone(),
                    media_type: args.media_type.as_ref().map(|t| media_type_str(t)),
                    include_dot: args.dots.include_dot,
                    only_dot: args.dots.only_dot,
                    query: args.query.clone(),
                }),
                SlideshowAction::Stop { monitor } => Request::SlideshowStop {
                    monitor: monitor.clone(),
                },
            },
        },
    };

    Ok(request)
}

// ── Conversion helpers ──────────────────────────────────────────────────────

fn display_opts_from(d: &DisplayOptions) -> DisplayOpts {
    DisplayOpts {
        monitor: d.monitor.clone(),
        mode: display_mode_str(&d.mode),
    }
}

fn media_opts_from(m: &MediaOptions) -> MediaOpts {
    MediaOpts {
        mute: m.mute,
        volume: m.volume,
        no_theme: m.no_theme,
    }
}

fn display_mode_str(mode: &DisplayMode) -> String {
    match mode {
        DisplayMode::Fill => "fill",
        DisplayMode::Fit => "fit",
        DisplayMode::Center => "center",
        DisplayMode::Stretch => "stretch",
        DisplayMode::Span => "span",
    }
    .into()
}

fn media_type_str(mt: &MediaType) -> String {
    match mt {
        MediaType::Image => "image",
        MediaType::Video => "video",
        MediaType::Web => "web",
        MediaType::All => "all",
    }
    .into()
}
