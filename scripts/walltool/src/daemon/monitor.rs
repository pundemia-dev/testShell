use anyhow::{Context, Result};
use hyprland::data::Monitors;
use hyprland::shared::HyprData;

use crate::ipc::MonitorInfo;

/// Fetch the current monitor layout from Hyprland via its IPC socket.
pub async fn fetch_monitors() -> Result<Vec<MonitorInfo>> {
    let monitors = Monitors::get_async()
        .await
        .context("failed to query Hyprland monitors")?;

    let result: Vec<MonitorInfo> = monitors
        .into_iter()
        .map(|m| MonitorInfo {
            name: m.name,
            width: m.width as u32,
            height: m.height as u32,
            x: m.x,
            y: m.y,
            scale: m.scale as f64,
            active_workspace: Some(m.active_workspace.name),
        })
        .collect();

    Ok(result)
}

/// Compute the bounding box that encompasses all monitors.
/// Returns (total_width, total_height, min_x, min_y).
pub fn bounding_box(monitors: &[MonitorInfo]) -> (u32, u32, i32, i32) {
    if monitors.is_empty() {
        return (0, 0, 0, 0);
    }

    let min_x = monitors.iter().map(|m| m.x).min().unwrap_or(0);
    let min_y = monitors.iter().map(|m| m.y).min().unwrap_or(0);
    let max_x = monitors
        .iter()
        .map(|m| m.x + m.width as i32)
        .max()
        .unwrap_or(0);
    let max_y = monitors
        .iter()
        .map(|m| m.y + m.height as i32)
        .max()
        .unwrap_or(0);

    let total_width = (max_x - min_x) as u32;
    let total_height = (max_y - min_y) as u32;

    (total_width, total_height, min_x, min_y)
}

/// Compute per-monitor offsets for "span" (bridging) mode.
///
/// In span mode a single wallpaper image covers the entire bounding box of all
/// monitors. Each monitor shows a sub-region of that image. The returned
/// `(offset_x, offset_y)` pairs tell QML where to position the image so the
/// correct region lands on each screen.
///
/// The offsets are normalised to the image/source coordinate space:
///   offset_x = (monitor.x - bbox.min_x) / bbox.total_width
///   offset_y = (monitor.y - bbox.min_y) / bbox.total_height
///
/// QML can use these directly as fractional source offsets (0.0 – 1.0).
pub fn compute_span_offsets(monitors: &[MonitorInfo]) -> Vec<(String, f64, f64)> {
    let (total_w, total_h, min_x, min_y) = bounding_box(monitors);

    if total_w == 0 || total_h == 0 {
        return monitors
            .iter()
            .map(|m| (m.name.clone(), 0.0, 0.0))
            .collect();
    }

    monitors
        .iter()
        .map(|m| {
            let ox = (m.x - min_x) as f64 / total_w as f64;
            let oy = (m.y - min_y) as f64 / total_h as f64;
            (m.name.clone(), ox, oy)
        })
        .collect()
}

/// Find a monitor by name. Returns `None` if not found.
pub fn find_by_name<'a>(monitors: &'a [MonitorInfo], name: &str) -> Option<&'a MonitorInfo> {
    monitors.iter().find(|m| m.name == name)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_monitors() -> Vec<MonitorInfo> {
        vec![
            MonitorInfo {
                name: "DP-1".into(),
                width: 2560,
                height: 1440,
                x: 0,
                y: 0,
                scale: 1.0,
                active_workspace: None,
            },
            MonitorInfo {
                name: "HDMI-A-1".into(),
                width: 1920,
                height: 1080,
                x: 2560,
                y: 180,
                scale: 1.0,
                active_workspace: None,
            },
        ]
    }

    #[test]
    fn test_bounding_box() {
        let monitors = make_monitors();
        let (w, h, min_x, min_y) = bounding_box(&monitors);
        assert_eq!(w, 2560 + 1920);
        assert_eq!(h, 1440);
        assert_eq!(min_x, 0);
        assert_eq!(min_y, 0);
    }

    #[test]
    fn test_span_offsets() {
        let monitors = make_monitors();
        let offsets = compute_span_offsets(&monitors);

        assert_eq!(offsets.len(), 2);

        // DP-1 is at (0,0) so offset should be (0.0, 0.0)
        assert_eq!(offsets[0].0, "DP-1");
        assert!((offsets[0].1 - 0.0).abs() < 1e-9);
        assert!((offsets[0].2 - 0.0).abs() < 1e-9);

        // HDMI-A-1 is at (2560, 180)
        let total_w = (2560 + 1920) as f64;
        let total_h = 1440.0;
        let expected_ox = 2560.0 / total_w;
        let expected_oy = 180.0 / total_h;

        assert_eq!(offsets[1].0, "HDMI-A-1");
        assert!((offsets[1].1 - expected_ox).abs() < 1e-9);
        assert!((offsets[1].2 - expected_oy).abs() < 1e-9);
    }

    #[test]
    fn test_find_by_name() {
        let monitors = make_monitors();
        assert!(find_by_name(&monitors, "DP-1").is_some());
        assert!(find_by_name(&monitors, "eDP-1").is_none());
    }

    #[test]
    fn test_empty_monitors() {
        let (w, h, x, y) = bounding_box(&[]);
        assert_eq!((w, h, x, y), (0, 0, 0, 0));

        let offsets = compute_span_offsets(&[]);
        assert!(offsets.is_empty());
    }
}
