use anyhow::{Context, Result};
use tokio::net::UnixStream;

use super::framing::{read_message, write_message};
use super::{socket_path, Request, Response};

/// Send a request to the running daemon and return its response.
pub async fn send_request(request: &Request) -> Result<Response> {
    let path = socket_path();

    let mut stream = UnixStream::connect(&path)
        .await
        .with_context(|| format!("failed to connect to daemon socket at {}", path.display()))?;

    let (mut reader, mut writer) = stream.split();

    write_message(&mut writer, request)
        .await
        .context("failed to send request to daemon")?;

    // Shutdown the write half so the daemon knows we're done sending.
    drop(writer);

    let response: Response = read_message(&mut reader)
        .await
        .context("failed to read response from daemon")?;

    Ok(response)
}

/// Check whether the daemon is currently running by attempting a Ping.
pub async fn daemon_is_running() -> bool {
    match send_request(&Request::Ping).await {
        Ok(_) => true,
        Err(_) => false,
    }
}

/// Send a request and pretty-print the response for CLI usage.
/// If `json` is true, output raw JSON; otherwise, human-readable text.
pub async fn send_and_print(request: &Request, json: bool) -> Result<()> {
    let response = send_request(request).await?;

    match &response {
        Response::Ok(payload) => {
            if json {
                let out = serde_json::to_string_pretty(&response)
                    .context("failed to serialize response")?;
                println!("{out}");
            } else {
                use super::ResponsePayload;
                match payload {
                    ResponsePayload::Empty => {}
                    ResponsePayload::Text(text) => println!("{text}"),
                    ResponsePayload::Pong => println!("pong"),
                    ResponsePayload::Json(val) => {
                        println!(
                            "{}",
                            serde_json::to_string_pretty(val)
                                .unwrap_or_else(|_| val.to_string())
                        );
                    }
                    ResponsePayload::Monitors(monitors) => {
                        for m in monitors {
                            println!(
                                "{}: {}x{} pos=({},{}) scale={:.1}",
                                m.name, m.width, m.height, m.x, m.y, m.scale,
                            );
                        }
                    }
                    ResponsePayload::SearchResults(results) => {
                        for r in results {
                            println!(
                                "[{:>4}] {} tags=[{}] score={:.2}",
                                r.id,
                                r.path,
                                r.tags.join(", "),
                                r.score,
                            );
                        }
                        println!("── {} result(s)", results.len());
                    }
                    ResponsePayload::History(entries) => {
                        for e in entries {
                            println!(
                                "[{:>4}] {} ({})",
                                e.id,
                                e.path,
                                e.timestamp,
                            );
                        }
                    }
                    ResponsePayload::Favorites(entries) => {
                        for e in entries {
                            println!("[{:>4}] {} (added {})", e.id, e.path, e.added_at);
                        }
                    }
                    ResponsePayload::Profiles(names) => {
                        for name in names {
                            println!("  • {name}");
                        }
                    }
                    ResponsePayload::PaletteVariants(variants) => {
                        for v in variants {
                            println!("  • {v}");
                        }
                    }
                    ResponsePayload::ThemeParams(params) => {
                        println!("mode:               {}", params.mode);
                        println!("scheme_type:        {}", params.scheme_type);
                        if let Some(v) = params.contrast {
                            println!("contrast:           {v}");
                        }
                        if let Some(v) = params.source_color_index {
                            println!("source_color_index: {v}");
                        }
                        if let Some(v) = &params.prefer {
                            println!("prefer:             {v}");
                        }
                        if let Some(v) = &params.fallback_color {
                            println!("fallback_color:     {v}");
                        }
                        if let Some(v) = params.opacity {
                            println!("opacity:            {v}");
                        }
                        if let Some(v) = params.lightness_dark {
                            println!("lightness_dark:     {v}");
                        }
                        if let Some(v) = params.lightness_light {
                            println!("lightness_light:    {v}");
                        }
                    }
                    ResponsePayload::AwwwOpts(opts) => {
                        println!(
                            "{}",
                            serde_json::to_string_pretty(opts)
                                .unwrap_or_else(|_| format!("{opts:?}"))
                        );
                    }
                    ResponsePayload::SlideshowOpts(opts) => {
                        println!(
                            "{}",
                            serde_json::to_string_pretty(opts)
                                .unwrap_or_else(|_| format!("{opts:?}"))
                        );
                    }
                    ResponsePayload::ConfigFull(toml_text) => {
                        print!("{toml_text}");
                    }
                    ResponsePayload::MonitorConfigs(entries) => {
                        if entries.is_empty() {
                            println!("(no per-monitor overrides configured)");
                        } else {
                            for e in entries {
                                println!("[awww.monitor.\"{}\"]", e.monitor);
                                let opts = &e.options;
                                if let Some(v) = &opts.resize           { println!("  resize           = {v}"); }
                                if let Some(v) = &opts.fill_color       { println!("  fill_color       = {v}"); }
                                if let Some(v) = &opts.filter           { println!("  filter           = {v}"); }
                                if let Some(v) = &opts.transition_type  { println!("  transition_type  = {v}"); }
                                if let Some(v) = opts.transition_step   { println!("  transition_step  = {v}"); }
                                if let Some(v) = opts.transition_duration { println!("  transition_duration = {v}"); }
                                if let Some(v) = opts.transition_fps    { println!("  transition_fps   = {v}"); }
                                if let Some(v) = opts.transition_angle  { println!("  transition_angle = {v}"); }
                                if let Some(v) = &opts.transition_pos   { println!("  transition_pos   = {v}"); }
                                if let Some(v) = &opts.transition_bezier { println!("  transition_bezier = {v}"); }
                                if let Some(v) = &opts.transition_wave  { println!("  transition_wave  = {v}"); }
                                if let Some(v) = opts.invert_y          { println!("  invert_y         = {v}"); }
                            }
                        }
                    }
                    ResponsePayload::MonitorOpts(opts) => {
                        println!("{}", serde_json::to_string_pretty(&opts).unwrap_or_else(|_| format!("{opts:?}")));
                    }
                    ResponsePayload::IndexerOpts(info) => {
                        println!("ai_tagging:  {}", info.ai_tagging);
                        if info.watch_dirs.is_empty() {
                            println!("watch_dirs:  (none)");
                        } else {
                            for d in &info.watch_dirs {
                                println!("watch_dirs:  {d}");
                            }
                        }
                    }
                    ResponsePayload::ThemeAutoOpts(info) => {
                        println!("sunrise:  {}", info.sunrise);
                        println!("sunset:   {}", info.sunset);
                    }
                    ResponsePayload::DaemonStatus(info) => {
                        println!("uptime:      {}s", info.uptime_secs);
                        println!("memory:      {:.1} MiB", info.memory_mb);
                        println!("slideshow:   {}", if info.slideshow_active { "active" } else { "off" });
                        if let Some(interval) = info.slideshow_interval {
                            println!("  interval:  {interval}s");
                        }
                        println!("indexing:    {}", if info.indexing { "running" } else { "idle" });
                        println!("preview:     {}", if info.preview_active { "active" } else { "off" });
                        println!("game mode:   {}", if info.game_mode { "ON" } else { "off" });
                    }
                }
            }
        }
        Response::Err { message } => {
            if json {
                let out = serde_json::to_string_pretty(&response)
                    .context("failed to serialize error response")?;
                eprintln!("{out}");
            } else {
                eprintln!("error: {message}");
            }
            std::process::exit(1);
        }
    }

    Ok(())
}
