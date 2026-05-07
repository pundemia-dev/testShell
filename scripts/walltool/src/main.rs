mod cli;
mod config;
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
    AwwwOpts, Request, SearchOpts, SlideshowStartRequest, WpClearRequest, WpIndexRequest,
    WpOptionsSetRequest, WpPreviewStartRequest, WpRandomRequest, WpRestoreRequest,
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

    // Ensure awww-daemon is running
    if let Err(e) = daemon::awww::ensure_daemon_running().await {
        warn!("failed to start awww-daemon: {e:#}");
    }

    let (shutdown_tx, shutdown_rx) = broadcast::channel::<()>(1);

    let daemon = Arc::new(
        daemon::Daemon::new(shutdown_tx.clone()).context("failed to initialize daemon")?,
    );

    // ── Spawn IPC server ────────────────────────────────────────────
    let server_daemon = Arc::clone(&daemon);
    let server_handle = tokio::spawn(async move {
        if let Err(e) = ipc::server::run_server(server_daemon, shutdown_rx).await {
            tracing::error!("IPC server error: {e:#}");
        }
    });

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
    server_handle.await.context("IPC server task panicked")?;

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
                awww: awww_opts_from(&args.awww),
                no_theme: args.matugen.no_theme,
            }),

            WallpaperAction::Preview { action } => match action {
                PreviewAction::Start(args) => Request::WpPreviewStart(WpPreviewStartRequest {
                    path: args.path.clone(),
                    awww: awww_opts_from(&args.awww),
                }),
                PreviewAction::Stop => Request::WpPreviewStop,
                PreviewAction::Commit => Request::WpPreviewCommit,
            },

            WallpaperAction::Random(args) => Request::WpRandom(WpRandomRequest {
                dir: args.dir.clone(),
                recursive: args.recursive,
                search: search_opts_from(&args.search),
                awww: awww_opts_from(&args.awww),
                no_theme: args.matugen.no_theme,
            }),

            WallpaperAction::Search(args) => Request::WpSearch(WpSearchRequest {
                query: args.query.clone(),
                search: search_opts_from(&args.search),
            }),

            WallpaperAction::ToggleHidden { path } => Request::WpToggleHidden { path: path.clone() },

            WallpaperAction::Options { action } => match action {
                WpOptionsAction::Set(args) => Request::WpOptionsSet(WpOptionsSetRequest {
                    path: args.path.clone(),
                    awww: awww_opts_from(&args.awww),
                }),
                WpOptionsAction::Get { path } => Request::WpOptionsGet { path: path.clone() },
                WpOptionsAction::Clear { path } => Request::WpOptionsClear { path: path.clone() },
            },

            WallpaperAction::Index(args) => Request::WpIndex(WpIndexRequest {
                dir: args.dir.clone(),
                force: args.force,
            }),

            WallpaperAction::Clear(args) => Request::WpClear(WpClearRequest {
                color: args.color.clone(),
                outputs: args.outputs.clone(),
                namespace: args.namespace.clone(),
            }),

            WallpaperAction::ClearCache => Request::WpClearCache,

            WallpaperAction::Restore(args) => Request::WpRestore(WpRestoreRequest {
                outputs: args.outputs.clone(),
                namespace: args.namespace.clone(),
            }),

            // ── History ──────────────────────────────────────────────
            WallpaperAction::History { action } => match action {
                HistoryAction::List { limit } => Request::HistoryList { limit: *limit },
                HistoryAction::Prev => Request::HistoryPrev,
                HistoryAction::Next => Request::HistoryNext,
                HistoryAction::Clear => Request::HistoryClear,
            },

            // ── Favorites ────────────────────────────────────────────
            WallpaperAction::Fav { action } => match action {
                FavAction::Add { path } => Request::FavAdd { path: path.clone() },
                FavAction::Rm { target } => Request::FavRm { target: target.clone() },
                FavAction::List { limit } => Request::FavList { limit: *limit },
                FavAction::SetRandom { awww } => Request::FavSetRandom(awww_opts_from(awww)),
            },
        },

        // ── Theme ────────────────────────────────────────────────────
        Commands::Theme { action } => match action {
            ThemeAction::Generate { path } => Request::ThemeGenerate { path: path.clone() },
            ThemeAction::Set { param, value } => Request::ThemeSet {
                param: param.clone(),
                value: value.clone(),
            },
            ThemeAction::Get => Request::ThemeGet,

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
            ConfigAction::SetAwwwDefault { key, value } => Request::ConfigSetAwwwDefault {
                key: key.clone(), value: value.clone(),
            },
            ConfigAction::GetAwwwDefaults => Request::ConfigGetAwwwDefaults,
            ConfigAction::SetNamespace { value } => Request::ConfigSetNamespace { value: value.clone() },
            ConfigAction::GetNamespace => Request::ConfigGetNamespace,
            ConfigAction::ListMonitorConfigs => Request::ConfigListMonitorConfigs,
            ConfigAction::GetMonitorOptions { monitor } => Request::ConfigGetMonitorOptions {
                monitor: monitor.clone(),
            },
            ConfigAction::SetMonitorOption { monitor, key, value } => Request::ConfigSetMonitorOption {
                monitor: monitor.clone(), key: key.clone(), value: value.clone(),
            },
            ConfigAction::RmMonitorOptions { monitor } => Request::ConfigRmMonitorOptions {
                monitor: monitor.clone(),
            },
            ConfigAction::GetMatugenDefaults => Request::ConfigGetMatugenDefaults,
            ConfigAction::SetMatugenDefault { key, value } => Request::ConfigSetMatugenDefault {
                key: key.clone(), value: value.clone(),
            },
            ConfigAction::GetThemeAuto => Request::ConfigGetThemeAuto,
            ConfigAction::SetThemeAuto { key, value } => Request::ConfigSetThemeAuto {
                key: key.clone(), value: value.clone(),
            },
            ConfigAction::SetSlideshowOption { key, value } => Request::ConfigSetSlideshowOption {
                key: key.clone(), value: value.clone(),
            },
            ConfigAction::GetSlideshowOptions => Request::ConfigGetSlideshowOptions,
            ConfigAction::GetIndexer => Request::ConfigGetIndexer,
            ConfigAction::SetIndexer { key, value } => Request::ConfigSetIndexer {
                key: key.clone(), value: value.clone(),
            },
            ConfigAction::Show => Request::ConfigShow,
            ConfigAction::Edit => Request::ConfigEdit,
        },
        // Commands::Config { action } => match action {
        //     ConfigAction::Profile { action } => match action {
        //         ProfileAction::Save { name } => Request::ProfileSave { name: name.clone() },
        //         ProfileAction::Load { name } => Request::ProfileLoad { name: name.clone() },
        //         ProfileAction::List => Request::ProfileList,
        //         ProfileAction::Rm { name } => Request::ProfileRm { name: name.clone() },
        //     },
        //     ConfigAction::SetAwwwDefault { key, value } => Request::ConfigSetAwwwDefault {
        //         key: key.clone(),
        //         value: value.clone(),
        //     },
        //     ConfigAction::GetAwwwDefaults => Request::ConfigGetAwwwDefaults,
        //     ConfigAction::SetSlideshowOption { key, value } => Request::ConfigSetSlideshowOption {
        //         key: key.clone(),
        //         value: value.clone(),
        //     },
        //     ConfigAction::GetSlideshowOptions => Request::ConfigGetSlideshowOptions,
        //     ConfigAction::Edit => Request::ConfigEdit,
        // },

        // ── Monitor ──────────────────────────────────────────────────
        Commands::Monitor { action } => match action {
            MonitorAction::List => Request::MonitorList,
            MonitorAction::Identify => Request::MonitorIdentify,
        },

        // ── Daemon ───────────────────────────────────────────────────
        Commands::Daemon { action } => match action {
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
                    search: search_opts_from(&args.search),
                    awww: awww_opts_from(&args.awww),
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

fn awww_opts_from(a: &AwwwOptions) -> AwwwOpts {
    AwwwOpts {
        outputs: a.outputs.clone(),
        namespace: a.namespace.clone(),
        resize: a.resize.map(|r| match r {
            ResizeMode::No => "no",
            ResizeMode::Crop => "crop",
            ResizeMode::Fit => "fit",
            ResizeMode::Stretch => "stretch",
        }.to_string()),
        fill_color: a.fill_color.clone(),
        filter: a.filter.map(|f| match f {
            ImageFilter::Nearest => "Nearest",
            ImageFilter::Bilinear => "Bilinear",
            ImageFilter::CatmullRom => "CatmullRom",
            ImageFilter::Mitchell => "Mitchell",
            ImageFilter::Lanczos3 => "Lanczos3",
        }.to_string()),
        transition_type: a.transition_type.map(|t| match t {
            TransitionType::None => "none",
            TransitionType::Simple => "simple",
            TransitionType::Fade => "fade",
            TransitionType::Left => "left",
            TransitionType::Right => "right",
            TransitionType::Top => "top",
            TransitionType::Bottom => "bottom",
            TransitionType::Wipe => "wipe",
            TransitionType::Wave => "wave",
            TransitionType::Grow => "grow",
            TransitionType::Center => "center",
            TransitionType::Any => "any",
            TransitionType::Outer => "outer",
            TransitionType::Random => "random",
        }.to_string()),
        transition_step: a.transition_step,
        transition_duration: a.transition_duration,
        transition_fps: a.transition_fps,
        transition_angle: a.transition_angle,
        transition_pos: a.transition_pos.clone(),
        transition_bezier: a.transition_bezier.clone(),
        transition_wave: a.transition_wave.clone(),
        invert_y: a.invert_y,
    }
}

fn search_opts_from(s: &SearchOptions) -> SearchOpts {
    SearchOpts {
        query: s.query.clone(),
        history: s.history,
        favorites: s.favorites,
        include_dot: s.include_dot,
        only_dot: s.only_dot,
        sort_by: match s.sort_by {
            SortField::Score => "score",
            SortField::Time => "time",
            SortField::Name => "name",
            SortField::Color => "color",
        }.to_string(),
        reverse: s.reverse,
        limit: s.limit,
    }
}
