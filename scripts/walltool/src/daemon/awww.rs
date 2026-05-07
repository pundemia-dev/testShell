//! awww daemon orchestration module
//!
//! This module handles all communication with the `awww` wallpaper daemon.
//! awww is responsible for the actual rendering — walltool just orchestrates.

use anyhow::{bail, Context, Result};
use std::process::Stdio;
use tokio::process::Command;
use tracing::{debug, info, warn};

use crate::ipc::AwwwOpts;

// ══════════════════════════════════════════════════════════════════════════════
//  awww command builders
// ══════════════════════════════════════════════════════════════════════════════

/// Build CLI arguments from AwwwOpts (excluding the image path)
pub fn build_awww_args(opts: &AwwwOpts) -> Vec<String> {
    let mut args = Vec::new();

    if let Some(ref outputs) = opts.outputs {
        args.push("-o".to_string());
        args.push(outputs.clone());
    }

    if let Some(ref ns) = opts.namespace {
        args.push("-n".to_string());
        args.push(ns.clone());
    }

    if let Some(ref resize) = opts.resize {
        args.push("--resize".to_string());
        args.push(resize.clone());
    }

    if let Some(ref color) = opts.fill_color {
        args.push("--fill-color".to_string());
        args.push(color.clone());
    }

    if let Some(ref filter) = opts.filter {
        args.push("-f".to_string());
        args.push(filter.clone());
    }

    if let Some(ref tt) = opts.transition_type {
        args.push("-t".to_string());
        args.push(tt.clone());
    }

    if let Some(step) = opts.transition_step {
        args.push("--transition-step".to_string());
        args.push(step.to_string());
    }

    if let Some(dur) = opts.transition_duration {
        args.push("--transition-duration".to_string());
        args.push(dur.to_string());
    }

    if let Some(fps) = opts.transition_fps {
        args.push("--transition-fps".to_string());
        args.push(fps.to_string());
    }

    if let Some(angle) = opts.transition_angle {
        args.push("--transition-angle".to_string());
        args.push(angle.to_string());
    }

    if let Some(ref pos) = opts.transition_pos {
        args.push("--transition-pos".to_string());
        args.push(pos.clone());
    }

    if let Some(ref bezier) = opts.transition_bezier {
        args.push("--transition-bezier".to_string());
        args.push(bezier.clone());
    }

    if let Some(ref wave) = opts.transition_wave {
        args.push("--transition-wave".to_string());
        args.push(wave.clone());
    }

    if opts.invert_y {
        args.push("--invert-y".to_string());
    }

    args
}

/// Build instant transition args (for history prev/next, preview stop, resume-all)
pub fn instant_transition_opts() -> AwwwOpts {
    AwwwOpts {
        transition_type: Some("none".to_string()),
        ..Default::default()
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  awww commands
// ══════════════════════════════════════════════════════════════════════════════

/// Set wallpaper via `awww img <path> [options]`
pub async fn run_awww_img(path: &str, opts: &AwwwOpts) -> Result<()> {
    let _ = ensure_daemon_running().await;

    let mut args = vec!["img".to_string(), path.to_string()];
    args.extend(build_awww_args(opts));

    info!("awww img {}", args[1..].join(" "));

    let status = Command::new("awww")
        .args(&args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .status()
        .await
        .context("failed to spawn awww")?;

    if !status.success() {
        bail!("awww img failed with status {status}");
    }

    Ok(())
}

/// Clear screen via `awww clear [color] [options]`
pub async fn run_awww_clear(
    color: Option<&str>,
    outputs: Option<&str>,
    namespace: Option<&str>,
) -> Result<()> {
    let mut args = vec!["clear".to_string()];

    if let Some(c) = color {
        args.push(c.to_string());
    }

    if let Some(o) = outputs {
        args.push("-o".to_string());
        args.push(o.to_string());
    }

    if let Some(ns) = namespace {
        args.push("-n".to_string());
        args.push(ns.to_string());
    }

    info!("awww {}", args.join(" "));

    let status = Command::new("awww")
        .args(&args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .status()
        .await
        .context("failed to spawn awww clear")?;

    if !status.success() {
        bail!("awww clear failed with status {status}");
    }

    Ok(())
}

/// Restore wallpaper via `awww restore [options]`
pub async fn run_awww_restore(outputs: Option<&str>, namespace: Option<&str>) -> Result<()> {
    let mut args = vec!["restore".to_string()];

    if let Some(o) = outputs {
        args.push("-o".to_string());
        args.push(o.to_string());
    }

    if let Some(ns) = namespace {
        args.push("-n".to_string());
        args.push(ns.to_string());
    }

    info!("awww {}", args.join(" "));

    let status = Command::new("awww")
        .args(&args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .status()
        .await
        .context("failed to spawn awww restore")?;

    if !status.success() {
        bail!("awww restore failed with status {status}");
    }

    Ok(())
}

/// Pause awww daemon (game mode)
pub async fn run_awww_pause(namespace: Option<&str>) -> Result<()> {
    let mut args = vec!["pause".to_string()];

    if let Some(ns) = namespace {
        args.push("-n".to_string());
        args.push(ns.to_string());
    }

    info!("awww {}", args.join(" "));

    let status = Command::new("awww")
        .args(&args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .status()
        .await
        .context("failed to spawn awww pause")?;

    if !status.success() {
        bail!("awww pause failed with status {status}");
    }

    Ok(())
}

/// Clear awww cache
pub async fn run_awww_clear_cache() -> Result<()> {
    info!("awww clear-cache");

    let status = Command::new("awww")
        .arg("clear-cache")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .status()
        .await
        .context("failed to spawn awww clear-cache")?;

    if !status.success() {
        bail!("awww clear-cache failed with status {status}");
    }

    Ok(())
}

/// Query awww for monitors
/// Returns JSON output from `awww query --json`
pub async fn run_awww_query() -> Result<serde_json::Value> {
    debug!("awww query --json");

    let output = Command::new("awww")
        .args(["query", "--json"])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await
        .context("failed to spawn awww query")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!("awww query failed: {stderr}");
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    serde_json::from_str(&stdout).context("parse awww query JSON")
}

/// Check if awww-daemon is running by trying `awww query`
pub async fn healthcheck() -> bool {
    match run_awww_query().await {
        Ok(_) => true,
        Err(e) => {
            debug!("awww healthcheck failed: {e}");
            false
        }
    }
}

/// Start awww-daemon if not running
pub async fn ensure_daemon_running() -> Result<()> {
    if healthcheck().await {
        debug!("awww-daemon already running");
        return Ok(());
    }

    info!("starting awww-daemon");

    // awww-daemon forks itself, so we just need to run it
    let status = Command::new("awww-daemon")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .await
        .context("failed to start awww-daemon")?;

    if !status.success() {
        warn!("awww-daemon exited with status {status}");
    }

    // Give it a moment to start
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

    if !healthcheck().await {
        bail!("awww-daemon failed to start");
    }

    Ok(())
}

// ══════════════════════════════════════════════════════════════════════════════
//  Option merging
// ══════════════════════════════════════════════════════════════════════════════

/// Merge options with priority: cli > per_wallpaper > monitor > defaults
///
/// Each Option field is merged independently — if cli has it, use cli,
/// otherwise try per_wallpaper, then monitor-specific, then defaults.
pub fn merge_opts(
    cli: &AwwwOpts,
    per_wallpaper: Option<&AwwwOpts>,
    monitor: Option<&AwwwOpts>,
    defaults: Option<&AwwwOpts>,
) -> AwwwOpts {
    let pw = per_wallpaper.cloned().unwrap_or_default();
    let mon = monitor.cloned().unwrap_or_default();
    let def = defaults.cloned().unwrap_or_default();

    AwwwOpts {
        outputs: cli.outputs.clone().or(pw.outputs).or(mon.outputs).or(def.outputs),
        namespace: cli.namespace.clone().or(pw.namespace).or(mon.namespace).or(def.namespace),
        resize: cli.resize.clone().or(pw.resize).or(mon.resize).or(def.resize),
        fill_color: cli.fill_color.clone().or(pw.fill_color).or(mon.fill_color).or(def.fill_color),
        filter: cli.filter.clone().or(pw.filter).or(mon.filter).or(def.filter),
        transition_type: cli.transition_type.clone().or(pw.transition_type).or(mon.transition_type).or(def.transition_type),
        transition_step: cli.transition_step.or(pw.transition_step).or(mon.transition_step).or(def.transition_step),
        transition_duration: cli.transition_duration.or(pw.transition_duration).or(mon.transition_duration).or(def.transition_duration),
        transition_fps: cli.transition_fps.or(pw.transition_fps).or(mon.transition_fps).or(def.transition_fps),
        transition_angle: cli.transition_angle.or(pw.transition_angle).or(mon.transition_angle).or(def.transition_angle),
        transition_pos: cli.transition_pos.clone().or(pw.transition_pos).or(mon.transition_pos).or(def.transition_pos),
        transition_bezier: cli.transition_bezier.clone().or(pw.transition_bezier).or(mon.transition_bezier).or(def.transition_bezier),
        transition_wave: cli.transition_wave.clone().or(pw.transition_wave).or(mon.transition_wave).or(def.transition_wave),
        invert_y: cli.invert_y || pw.invert_y || mon.invert_y || def.invert_y,
    }
}
