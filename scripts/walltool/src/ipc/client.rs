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
                    ResponsePayload::WallpaperState(states) => {
                        for s in states {
                            println!(
                                "[{}] {} ({}) mode={} offset=({:.1}, {:.1}) muted={} vol={} paused={}",
                                s.monitor,
                                s.path.as_deref().unwrap_or("<none>"),
                                s.media_type,
                                s.mode,
                                s.offset_x,
                                s.offset_y,
                                s.muted,
                                s.volume,
                                s.paused,
                            );
                        }
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
                    ResponsePayload::DaemonStatus(info) => {
                        println!("uptime:      {}s", info.uptime_secs);
                        println!("memory:      {:.1} MiB", info.memory_mb);
                        println!("monitors:    {}", info.monitors);
                        println!("slideshow:   {}", if info.slideshow_active { "active" } else { "off" });
                        if let Some(interval) = info.slideshow_interval {
                            println!("  interval:  {interval}s");
                        }
                        println!("ai indexer:  {}", if info.ai_indexing { "running" } else { "idle" });
                        if info.ai_queue_size > 0 {
                            println!("  queue:     {} items", info.ai_queue_size);
                        }
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
