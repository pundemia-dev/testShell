//! Hyprland IPC event listener for monitor hotplug detection.
//!
//! Spawns a blocking task that listens to Hyprland's event socket.
//! When a monitor is added or removed, updates the daemon's wallpaper
//! state accordingly (applies fallback wallpaper to new monitors,
//! recalculates span offsets if in bridging mode, removes stale entries).

use std::sync::Arc;

use tokio::sync::broadcast;
use tracing::{debug, error, info, warn};

use crate::daemon::monitor::{compute_span_offsets, fetch_monitors};
use crate::daemon::Daemon;

/// Spawn the Hyprland event listener as a background task.
///
/// This runs in a `spawn_blocking` context because `hyprland-rs`'s
/// `EventListener` is synchronous and blocks the calling thread.
///
/// The listener reacts to:
///   - `monitoradded`   → register new monitor, apply fallback wallpaper
///   - `monitorremoved` → remove monitor from state
///
/// The task will exit when:
///   - The shutdown signal is received
///   - The Hyprland event socket disconnects (compositor exit)
///   - An unrecoverable error occurs
pub fn spawn_hyprland_listener(
    daemon: Arc<Daemon>,
    shutdown_tx: broadcast::Sender<()>,
) -> tokio::task::JoinHandle<()> {
    // We need a runtime handle to spawn async work from within the
    // blocking listener callbacks.
    let rt_handle = tokio::runtime::Handle::current();

    tokio::task::spawn_blocking(move || {
        use hyprland::event_listener::EventListener;

        let mut listener = EventListener::new();
        let mut shutdown_rx = shutdown_tx.subscribe();

        // ── Monitor Added ───────────────────────────────────────────
        let d_added = Arc::clone(&daemon);
        let h_added = rt_handle.clone();

        listener.add_monitor_added_handler(move |data| {
            let monitor_name = data.name.clone();
            info!("hyprland: monitor added → {monitor_name}");

            let d = Arc::clone(&d_added);
            h_added.spawn(async move {
                // Register the monitor with fallback wallpaper
                {
                    let mut state = d.state.write().await;
                    state.ensure_monitor(&monitor_name);
                }

                // Recalculate span offsets if any monitor uses span mode
                if let Err(e) = recalculate_span_offsets(&d).await {
                    warn!("failed to recalculate span offsets after hotplug: {e:#}");
                }
            });
        });

        // ── Monitor Removed ─────────────────────────────────────────
        let d_removed = Arc::clone(&daemon);
        let h_removed = rt_handle.clone();

        listener.add_monitor_removed_handler(move |data| {
            // MonitorRemovedEventData is a String (the monitor name)
            let monitor_name = data.clone();
            info!("hyprland: monitor removed → {monitor_name}");

            let d = Arc::clone(&d_removed);
            h_removed.spawn(async move {
                {
                    let mut state = d.state.write().await;
                    state.remove_monitor(&monitor_name);
                }

                // Recalculate span offsets for remaining monitors
                if let Err(e) = recalculate_span_offsets(&d).await {
                    warn!("failed to recalculate span offsets after unplug: {e:#}");
                }
            });
        });

        // ── Workspace Changed (useful for future per-workspace wallpapers) ──
        listener.add_workspace_changed_handler(move |data| {
            debug!("hyprland: workspace changed → {:?}", data);
        });

        // ── Start the blocking listener ─────────────────────────────
        // We run the listener in a separate thread and use the shutdown
        // signal to know when to stop caring about events.
        //
        // Unfortunately hyprland-rs EventListener::start_listener() is
        // fully blocking with no built-in cancellation. We run it and
        // accept that the thread will live until Hyprland disconnects
        // the socket (which happens on compositor exit).
        info!("hyprland event listener started");

        // Check if we should even start
        if shutdown_rx.try_recv().is_ok() {
            info!("hyprland event listener: shutdown before start");
            return;
        }

        if let Err(e) = listener.start_listener() {
            // Don't log as error if it's a normal disconnection
            let msg = format!("{e}");
            if msg.contains("broken pipe")
                || msg.contains("connection reset")
                || msg.contains("EOF")
            {
                info!("hyprland event listener disconnected (compositor exit)");
            } else {
                error!("hyprland event listener error: {e}");
            }
        }

        info!("hyprland event listener stopped");
    })
}

/// Fetch the current monitor layout from Hyprland and synchronize
/// the daemon's wallpaper state with reality.
///
/// Call this once at daemon startup to populate the initial monitor list.
pub async fn sync_monitors_initial(daemon: &Daemon) {
    match fetch_monitors().await {
        Ok(monitors) => {
            info!(
                "initial monitor sync: {} monitor(s) detected",
                monitors.len()
            );

            let mut state = daemon.state.write().await;
            for m in &monitors {
                state.ensure_monitor(&m.name);
                debug!(
                    "  → {} ({}x{} @ {},{} scale={:.1})",
                    m.name, m.width, m.height, m.x, m.y, m.scale
                );
            }

            // Calculate span offsets for monitors using span mode
            let offsets = compute_span_offsets(&monitors);
            for (name, ox, oy) in &offsets {
                state.set_offsets(name, *ox, *oy);
            }

            if let Err(e) = state.flush() {
                warn!("failed to flush state after initial monitor sync: {e}");
            }
        }
        Err(e) => {
            warn!(
                "could not query Hyprland monitors at startup: {e:#}. \
                 Monitors will be discovered via hotplug events."
            );
        }
    }
}

/// Recalculate span offsets for all tracked monitors.
///
/// Called after a monitor is added or removed to update the bridging
/// geometry in `wallpaper_state.json`.
async fn recalculate_span_offsets(daemon: &Daemon) -> anyhow::Result<()> {
    let monitors = fetch_monitors().await?;
    let offsets = compute_span_offsets(&monitors);

    let mut state = daemon.state.write().await;
    for (name, ox, oy) in &offsets {
        state.set_offsets(name, *ox, *oy);
    }

    state.flush()?;
    debug!("span offsets recalculated for {} monitor(s)", monitors.len());

    Ok(())
}
