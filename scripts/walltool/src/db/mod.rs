use anyhow::{Context, Result};
use rusqlite::{params, Connection, OptionalExtension};
use std::path::PathBuf;
use std::sync::Mutex;

/// Central database handle. Wraps a `rusqlite::Connection` in a `Mutex`
/// so it can be shared across async tasks via `Arc<Db>`.
pub struct Db {
    conn: Mutex<Connection>,
}

// ── Data types returned by queries ──────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct WallpaperRow {
    pub id: i64,
    pub path: String,
    pub media_type: String,
    pub dominant_color: Option<String>,
    pub indexed_at: String,
}

#[derive(Debug, Clone)]
pub struct TagRow {
    pub wallpaper_id: i64,
    pub tag: String,
    pub confidence: f64,
}

#[derive(Debug, Clone)]
pub struct HistoryRow {
    pub id: i64,
    pub path: String,
    pub monitor: Option<String>,
    pub mode: String,
    pub timestamp: String,
}

#[derive(Debug, Clone)]
pub struct FavoriteRow {
    pub id: i64,
    pub path: String,
    pub added_at: String,
}

#[derive(Debug, Clone)]
pub struct SearchResult {
    pub id: i64,
    pub path: String,
    pub media_type: String,
    pub tags: Vec<String>,
    pub dominant_color: Option<String>,
    pub is_fav: bool,
    pub score: f64,
}

// ── Implementation ──────────────────────────────────────────────────────────

impl Db {
    /// Open (or create) the database at the given path and run migrations.
    pub fn open(path: &PathBuf) -> Result<Self> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)
                .with_context(|| format!("create db directory: {}", parent.display()))?;
        }

        let conn = Connection::open(path)
            .with_context(|| format!("open sqlite db at {}", path.display()))?;

        // Performance pragmas
        conn.execute_batch(
            "PRAGMA journal_mode = WAL;
             PRAGMA synchronous  = NORMAL;
             PRAGMA foreign_keys = ON;
             PRAGMA busy_timeout = 5000;",
        )
        .context("set pragmas")?;

        let db = Self {
            conn: Mutex::new(conn),
        };
        db.migrate()?;
        Ok(db)
    }

    /// Default database path: `~/.cache/walltool/walltool.db`
    pub fn default_path() -> PathBuf {
        directories::ProjectDirs::from("", "", "walltool")
            .map(|d| d.cache_dir().to_path_buf())
            .unwrap_or_else(|| {
                let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
                PathBuf::from(home).join(".cache").join("walltool")
            })
            .join("walltool.db")
    }

    // ── Schema / Migrations ─────────────────────────────────────────────

    fn migrate(&self) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS wallpapers (
                id             INTEGER PRIMARY KEY AUTOINCREMENT,
                path           TEXT    NOT NULL UNIQUE,
                media_type     TEXT    NOT NULL DEFAULT 'image',
                dominant_color TEXT,
                width          INTEGER,
                height         INTEGER,
                file_size      INTEGER,
                indexed_at     TEXT    NOT NULL DEFAULT (datetime('now'))
            );

            CREATE TABLE IF NOT EXISTS tags (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                wallpaper_id  INTEGER NOT NULL REFERENCES wallpapers(id) ON DELETE CASCADE,
                tag           TEXT    NOT NULL,
                confidence    REAL    NOT NULL DEFAULT 1.0,
                UNIQUE(wallpaper_id, tag)
            );
            CREATE INDEX IF NOT EXISTS idx_tags_tag ON tags(tag);
            CREATE INDEX IF NOT EXISTS idx_tags_wp  ON tags(wallpaper_id);

            CREATE TABLE IF NOT EXISTS history (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                path       TEXT    NOT NULL,
                monitor    TEXT,
                mode       TEXT    NOT NULL DEFAULT 'fill',
                timestamp  TEXT    NOT NULL DEFAULT (datetime('now'))
            );
            CREATE INDEX IF NOT EXISTS idx_history_ts ON history(timestamp DESC);

            CREATE TABLE IF NOT EXISTS favorites (
                id       INTEGER PRIMARY KEY AUTOINCREMENT,
                path     TEXT    NOT NULL UNIQUE,
                added_at TEXT    NOT NULL DEFAULT (datetime('now'))
            );

            CREATE TABLE IF NOT EXISTS color_palette (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                wallpaper_id  INTEGER NOT NULL REFERENCES wallpapers(id) ON DELETE CASCADE,
                role          TEXT    NOT NULL,
                hex           TEXT    NOT NULL,
                UNIQUE(wallpaper_id, role)
            );
            CREATE INDEX IF NOT EXISTS idx_palette_wp ON color_palette(wallpaper_id);
            ",
        )
        .context("run migrations")?;
        Ok(())
    }

    // ── Wallpapers CRUD ─────────────────────────────────────────────────

    /// Insert or ignore a wallpaper record. Returns the row id.
    pub fn upsert_wallpaper(
        &self,
        path: &str,
        media_type: &str,
        dominant_color: Option<&str>,
        width: Option<u32>,
        height: Option<u32>,
        file_size: Option<u64>,
    ) -> Result<i64> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO wallpapers (path, media_type, dominant_color, width, height, file_size)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)
             ON CONFLICT(path) DO UPDATE SET
                media_type     = excluded.media_type,
                dominant_color = COALESCE(excluded.dominant_color, wallpapers.dominant_color),
                width          = COALESCE(excluded.width,          wallpapers.width),
                height         = COALESCE(excluded.height,         wallpapers.height),
                file_size      = COALESCE(excluded.file_size,      wallpapers.file_size),
                indexed_at     = datetime('now')",
            params![
                path,
                media_type,
                dominant_color,
                width.map(|v| v as i64),
                height.map(|v| v as i64),
                file_size.map(|v| v as i64),
            ],
        )
        .context("upsert wallpaper")?;

        let id: i64 = conn
            .query_row(
                "SELECT id FROM wallpapers WHERE path = ?1",
                params![path],
                |row| row.get(0),
            )
            .context("get wallpaper id after upsert")?;

        Ok(id)
    }

    /// Check whether a wallpaper path is already indexed.
    pub fn wallpaper_exists(&self, path: &str) -> Result<bool> {
        let conn = self.conn.lock().unwrap();
        let exists: bool = conn
            .query_row(
                "SELECT EXISTS(SELECT 1 FROM wallpapers WHERE path = ?1)",
                params![path],
                |row| row.get(0),
            )
            .context("check wallpaper exists")?;
        Ok(exists)
    }

    /// Get a wallpaper row by path.
    pub fn get_wallpaper_by_path(&self, path: &str) -> Result<Option<WallpaperRow>> {
        let conn = self.conn.lock().unwrap();
        let row = conn
            .query_row(
                "SELECT id, path, media_type, dominant_color, indexed_at
                 FROM wallpapers WHERE path = ?1",
                params![path],
                |row| {
                    Ok(WallpaperRow {
                        id: row.get(0)?,
                        path: row.get(1)?,
                        media_type: row.get(2)?,
                        dominant_color: row.get(3)?,
                        indexed_at: row.get(4)?,
                    })
                },
            )
            .optional()
            .context("get wallpaper by path")?;
        Ok(row)
    }

    // ── Tags CRUD ───────────────────────────────────────────────────────

    /// Insert tags for a wallpaper (batch). Replaces existing tags.
    pub fn set_tags(&self, wallpaper_id: i64, tags: &[(String, f64)]) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "DELETE FROM tags WHERE wallpaper_id = ?1",
            params![wallpaper_id],
        )
        .context("clear old tags")?;

        let mut stmt = conn
            .prepare(
                "INSERT INTO tags (wallpaper_id, tag, confidence) VALUES (?1, ?2, ?3)",
            )
            .context("prepare tag insert")?;

        for (tag, confidence) in tags {
            stmt.execute(params![wallpaper_id, tag, confidence])
                .with_context(|| format!("insert tag '{tag}'"))?;
        }
        Ok(())
    }

    /// Get all tags for a wallpaper.
    pub fn get_tags(&self, wallpaper_id: i64) -> Result<Vec<TagRow>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn
            .prepare(
                "SELECT wallpaper_id, tag, confidence FROM tags
                 WHERE wallpaper_id = ?1 ORDER BY confidence DESC",
            )
            .context("prepare get_tags")?;

        let rows = stmt
            .query_map(params![wallpaper_id], |row| {
                Ok(TagRow {
                    wallpaper_id: row.get(0)?,
                    tag: row.get(1)?,
                    confidence: row.get(2)?,
                })
            })
            .context("query tags")?
            .collect::<Result<Vec<_>, _>>()
            .context("collect tags")?;

        Ok(rows)
    }

    // ── Search ──────────────────────────────────────────────────────────

    /// Full-text search across wallpaper paths, tags, and dominant colors.
    /// Returns results ranked by relevance (tag confidence sum + path match).
    pub fn search(&self, query: &str, limit: usize, include_dot: bool, only_dot: bool) -> Result<Vec<SearchResult>> {
        let conn = self.conn.lock().unwrap();

        let pattern = format!("%{query}%");
        let unlimited = limit == 0;

        // Build SQL dynamically: omit LIMIT clause when unlimited,
        // otherwise over-fetch to compensate for post-query dot-filtering.
        let base_sql = "SELECT w.id, w.path, w.media_type, w.dominant_color,
                    COALESCE(tag_score, 0.0) + COALESCE(path_score, 0.0) AS score
             FROM wallpapers w
             LEFT JOIN (
                 SELECT wallpaper_id, SUM(confidence) AS tag_score
                 FROM tags WHERE tag LIKE ?1
                 GROUP BY wallpaper_id
             ) t ON t.wallpaper_id = w.id
             LEFT JOIN (
                 SELECT id, 1.0 AS path_score
                 FROM wallpapers WHERE path LIKE ?1
             ) p ON p.id = w.id
             WHERE tag_score IS NOT NULL OR path_score IS NOT NULL
                OR w.dominant_color LIKE ?1
             ORDER BY score DESC";

        let rows: Vec<(i64, String, String, Option<String>, f64)> = if unlimited {
            let mut stmt = conn.prepare(base_sql).context("prepare search")?;
            stmt.query_map(params![pattern], |row| {
                    Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?, row.get(4)?))
                })
                .context("query search")?
                .collect::<Result<Vec<_>, _>>()
                .context("collect search")?
        } else {
            let fetch_limit: i64 = if include_dot || only_dot {
                (limit * 3) as i64
            } else {
                (limit * 2) as i64
            };
            let sql = format!("{base_sql} LIMIT ?2");
            let mut stmt = conn.prepare(&sql).context("prepare search")?;
            stmt.query_map(params![pattern, fetch_limit], |row| {
                    Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?, row.get(4)?))
                })
                .context("query search")?
                .collect::<Result<Vec<_>, _>>()
                .context("collect search")?
        };

        // Enrich each result with tags + fav status, applying dot-filter
        let mut results = Vec::with_capacity(rows.len());
        for (id, path, media_type, dominant_color, score) in rows {
            if !self.passes_dot_filter(&path, include_dot, only_dot) {
                continue;
            }
            if !unlimited && results.len() >= limit {
                break;
            }
            let tags = self.get_tags_inner(&conn, id)?;
            let is_fav = self.fav_contains_inner(&conn, &path)?;

            results.push(SearchResult {
                id,
                path,
                media_type,
                tags,
                dominant_color,
                is_fav,
                score,
            });
        }

        Ok(results)
    }

    /// Search within history entries, optionally filtered by query substring.
    pub fn search_history(&self, query: &str, limit: usize, include_dot: bool, only_dot: bool) -> Result<Vec<SearchResult>> {
        let conn = self.conn.lock().unwrap();

        let pattern = format!("%{query}%");
        let unlimited = limit == 0;

        let base_sql = "SELECT DISTINCT h.path, h.id
             FROM history h
             WHERE h.path LIKE ?1
             ORDER BY h.id DESC";

        let rows: Vec<(String, i64)> = if unlimited {
            let mut stmt = conn.prepare(base_sql).context("prepare search_history")?;
            stmt.query_map(params![pattern], |row| {
                    Ok((row.get(0)?, row.get(1)?))
                })
                .context("query search_history")?
                .collect::<Result<Vec<_>, _>>()
                .context("collect search_history")?
        } else {
            let sql = format!("{base_sql} LIMIT ?2");
            let mut stmt = conn.prepare(&sql).context("prepare search_history")?;
            stmt.query_map(params![pattern, limit as i64], |row| {
                    Ok((row.get(0)?, row.get(1)?))
                })
                .context("query search_history")?
                .collect::<Result<Vec<_>, _>>()
                .context("collect search_history")?
        };

        let mut results = Vec::new();
        for (path, id) in rows {
            if !self.passes_dot_filter(&path, include_dot, only_dot) {
                continue;
            }
            let (media_type, dominant_color, tags) = self.enrich_from_index(&conn, &path)?;
            let is_fav = self.fav_contains_inner(&conn, &path)?;

            results.push(SearchResult {
                id,
                path,
                media_type,
                tags,
                dominant_color,
                is_fav,
                score: 1.0,
            });
        }

        Ok(results)
    }

    /// Search within favorites, optionally filtered by query substring.
    pub fn search_favorites(&self, query: &str, limit: usize, include_dot: bool, only_dot: bool) -> Result<Vec<SearchResult>> {
        let conn = self.conn.lock().unwrap();

        let pattern = format!("%{query}%");
        let unlimited = limit == 0;

        let base_sql = "SELECT f.id, f.path
             FROM favorites f
             WHERE f.path LIKE ?1
             ORDER BY f.added_at DESC";

        let rows: Vec<(i64, String)> = if unlimited {
            let mut stmt = conn.prepare(base_sql).context("prepare search_favorites")?;
            stmt.query_map(params![pattern], |row| {
                    Ok((row.get(0)?, row.get(1)?))
                })
                .context("query search_favorites")?
                .collect::<Result<Vec<_>, _>>()
                .context("collect search_favorites")?
        } else {
            let sql = format!("{base_sql} LIMIT ?2");
            let mut stmt = conn.prepare(&sql).context("prepare search_favorites")?;
            stmt.query_map(params![pattern, limit as i64], |row| {
                    Ok((row.get(0)?, row.get(1)?))
                })
                .context("query search_favorites")?
                .collect::<Result<Vec<_>, _>>()
                .context("collect search_favorites")?
        };

        let mut results = Vec::new();
        for (id, path) in rows {
            if !self.passes_dot_filter(&path, include_dot, only_dot) {
                continue;
            }
            let (media_type, dominant_color, tags) = self.enrich_from_index(&conn, &path)?;

            results.push(SearchResult {
                id,
                path,
                media_type,
                tags,
                dominant_color,
                is_fav: true,
                score: 1.0,
            });
        }

        Ok(results)
    }

    /// Search history intersected with favorites (Alt+Shift).
    pub fn search_history_favorites(&self, query: &str, limit: usize, include_dot: bool, only_dot: bool) -> Result<Vec<SearchResult>> {
        let conn = self.conn.lock().unwrap();

        let pattern = format!("%{query}%");
        let unlimited = limit == 0;

        let base_sql = "SELECT DISTINCT h.path, h.id
             FROM history h
             INNER JOIN favorites f ON f.path = h.path
             WHERE h.path LIKE ?1
             ORDER BY h.id DESC";

        let rows: Vec<(String, i64)> = if unlimited {
            let mut stmt = conn.prepare(base_sql).context("prepare search_history_favorites")?;
            stmt.query_map(params![pattern], |row| {
                    Ok((row.get(0)?, row.get(1)?))
                })
                .context("query search_history_favorites")?
                .collect::<Result<Vec<_>, _>>()
                .context("collect search_history_favorites")?
        } else {
            let sql = format!("{base_sql} LIMIT ?2");
            let mut stmt = conn.prepare(&sql).context("prepare search_history_favorites")?;
            stmt.query_map(params![pattern, limit as i64], |row| {
                    Ok((row.get(0)?, row.get(1)?))
                })
                .context("query search_history_favorites")?
                .collect::<Result<Vec<_>, _>>()
                .context("collect search_history_favorites")?
        };

        let mut results = Vec::new();
        for (path, id) in rows {
            if !self.passes_dot_filter(&path, include_dot, only_dot) {
                continue;
            }
            let (media_type, dominant_color, tags) = self.enrich_from_index(&conn, &path)?;

            results.push(SearchResult {
                id,
                path,
                media_type,
                tags,
                dominant_color,
                is_fav: true,
                score: 1.0,
            });
        }

        Ok(results)
    }

    /// Dot-file filter helper.
    fn passes_dot_filter(&self, path: &str, include_dot: bool, only_dot: bool) -> bool {
        let fname = std::path::Path::new(path)
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();
        let is_dot = fname.starts_with('.');

        if only_dot && !is_dot {
            return false;
        }
        if !include_dot && !only_dot && is_dot {
            return false;
        }
        true
    }

    /// Enrich a path with media_type/dominant_color/tags from the wallpapers index.
    /// Falls back to extension-based detection if not indexed.
    fn enrich_from_index(&self, conn: &rusqlite::Connection, path: &str) -> Result<(String, Option<String>, Vec<String>)> {
        let row = conn.query_row(
            "SELECT id, media_type, dominant_color FROM wallpapers WHERE path = ?1",
            params![path],
            |row| Ok((row.get::<_, i64>(0)?, row.get::<_, String>(1)?, row.get::<_, Option<String>>(2)?)),
        ).optional().context("enrich lookup")?;

        match row {
            Some((wp_id, media_type, dominant_color)) => {
                let tags = self.get_tags_inner(conn, wp_id)?;
                Ok((media_type, dominant_color, tags))
            }
            None => {
                // Fallback: detect media type from extension
                let media_type = detect_media_type_from_ext(path);
                Ok((media_type, None, Vec::new()))
            }
        }
    }

    /// Get tags for a wallpaper by id (internal, takes conn reference).
    fn get_tags_inner(&self, conn: &rusqlite::Connection, wallpaper_id: i64) -> Result<Vec<String>> {
        let mut stmt = conn
            .prepare_cached(
                "SELECT tag FROM tags WHERE wallpaper_id = ?1 ORDER BY confidence DESC LIMIT 10",
            )
            .context("prepare tag lookup")?;
        let tags: Vec<String> = stmt
            .query_map(params![wallpaper_id], |row| row.get(0))
            .context("query tags")?
            .collect::<Result<Vec<_>, _>>()
            .context("collect tags")?;
        Ok(tags)
    }

    /// Check fav status without locking conn (internal).
    fn fav_contains_inner(&self, conn: &rusqlite::Connection, path: &str) -> Result<bool> {
        let exists: bool = conn
            .query_row(
                "SELECT EXISTS(SELECT 1 FROM favorites WHERE path = ?1)",
                params![path],
                |row| row.get(0),
            )
            .context("fav_contains_inner")?;
        Ok(exists)
    }

    // ── History CRUD ────────────────────────────────────────────────────

    /// Record a wallpaper change in history.
    pub fn history_push(&self, path: &str, monitor: Option<&str>, mode: &str) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO history (path, monitor, mode) VALUES (?1, ?2, ?3)",
            params![path, monitor, mode],
        )
        .context("insert history")?;
        Ok(())
    }

    /// List recent history entries, newest first.
    pub fn history_list(&self, limit: usize) -> Result<Vec<HistoryRow>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn
            .prepare(
                "SELECT id, path, monitor, mode, timestamp
                 FROM history ORDER BY id DESC LIMIT ?1",
            )
            .context("prepare history_list")?;

        let rows = stmt
            .query_map(params![limit as i64], |row| {
                Ok(HistoryRow {
                    id: row.get(0)?,
                    path: row.get(1)?,
                    monitor: row.get(2)?,
                    mode: row.get(3)?,
                    timestamp: row.get(4)?,
                })
            })
            .context("query history")?
            .collect::<Result<Vec<_>, _>>()
            .context("collect history")?;

        Ok(rows)
    }

    /// Get the Nth previous entry from history (0 = most recent).
    pub fn history_nth(&self, offset: usize) -> Result<Option<HistoryRow>> {
        let conn = self.conn.lock().unwrap();
        let row = conn
            .query_row(
                "SELECT id, path, monitor, mode, timestamp
                 FROM history ORDER BY id DESC LIMIT 1 OFFSET ?1",
                params![offset as i64],
                |row| {
                    Ok(HistoryRow {
                        id: row.get(0)?,
                        path: row.get(1)?,
                        monitor: row.get(2)?,
                        mode: row.get(3)?,
                        timestamp: row.get(4)?,
                    })
                },
            )
            .optional()
            .context("history_nth")?;
        Ok(row)
    }

    /// Clear all history.
    pub fn history_clear(&self) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM history", [])
            .context("clear history")?;
        Ok(())
    }

    // ── Favorites CRUD ──────────────────────────────────────────────────

    /// Add a path to favorites. No-op if already exists.
    pub fn fav_add(&self, path: &str) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR IGNORE INTO favorites (path) VALUES (?1)",
            params![path],
        )
        .context("fav_add")?;
        Ok(())
    }

    /// Remove from favorites by path or numeric id.
    pub fn fav_rm(&self, target: &str) -> Result<bool> {
        let conn = self.conn.lock().unwrap();

        let affected = if let Ok(id) = target.parse::<i64>() {
            conn.execute("DELETE FROM favorites WHERE id = ?1", params![id])
                .context("fav_rm by id")?
        } else {
            conn.execute("DELETE FROM favorites WHERE path = ?1", params![target])
                .context("fav_rm by path")?
        };

        Ok(affected > 0)
    }

    /// List favorites, newest first.
    pub fn fav_list(&self, limit: usize) -> Result<Vec<FavoriteRow>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn
            .prepare(
                "SELECT id, path, added_at FROM favorites
                 ORDER BY added_at DESC LIMIT ?1",
            )
            .context("prepare fav_list")?;

        let rows = stmt
            .query_map(params![limit as i64], |row| {
                Ok(FavoriteRow {
                    id: row.get(0)?,
                    path: row.get(1)?,
                    added_at: row.get(2)?,
                })
            })
            .context("query favorites")?
            .collect::<Result<Vec<_>, _>>()
            .context("collect favorites")?;

        Ok(rows)
    }

    /// Check whether a path is in favorites.
    pub fn fav_contains(&self, path: &str) -> Result<bool> {
        let conn = self.conn.lock().unwrap();
        let exists: bool = conn
            .query_row(
                "SELECT EXISTS(SELECT 1 FROM favorites WHERE path = ?1)",
                params![path],
                |row| row.get(0),
            )
            .context("fav_contains")?;
        Ok(exists)
    }

    /// Get all favorite paths (for random selection).
    pub fn fav_all_paths(&self) -> Result<Vec<String>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn
            .prepare("SELECT path FROM favorites")
            .context("prepare fav_all_paths")?;

        let paths = stmt
            .query_map([], |row| row.get(0))
            .context("query fav paths")?
            .collect::<Result<Vec<String>, _>>()
            .context("collect fav paths")?;

        Ok(paths)
    }

    // ── Color palette CRUD ──────────────────────────────────────────────

    /// Store a color palette for a wallpaper (from Matugen output).
    pub fn set_palette(
        &self,
        wallpaper_id: i64,
        colors: &[(String, String)],
    ) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "DELETE FROM color_palette WHERE wallpaper_id = ?1",
            params![wallpaper_id],
        )
        .context("clear old palette")?;

        let mut stmt = conn
            .prepare(
                "INSERT INTO color_palette (wallpaper_id, role, hex) VALUES (?1, ?2, ?3)",
            )
            .context("prepare palette insert")?;

        for (role, hex) in colors {
            stmt.execute(params![wallpaper_id, role, hex])
                .with_context(|| format!("insert palette role '{role}'"))?;
        }
        Ok(())
    }

    /// Get the stored color palette for a wallpaper.
    pub fn get_palette(&self, wallpaper_id: i64) -> Result<Vec<(String, String)>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn
            .prepare(
                "SELECT role, hex FROM color_palette WHERE wallpaper_id = ?1 ORDER BY role",
            )
            .context("prepare get_palette")?;

        let rows = stmt
            .query_map(params![wallpaper_id], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
            })
            .context("query palette")?
            .collect::<Result<Vec<_>, _>>()
            .context("collect palette")?;

        Ok(rows)
    }

    // ── Utility ─────────────────────────────────────────────────────────

    /// Total number of indexed wallpapers.
    pub fn wallpaper_count(&self) -> Result<i64> {
        let conn = self.conn.lock().unwrap();
        let count: i64 = conn
            .query_row("SELECT COUNT(*) FROM wallpapers", [], |row| row.get(0))
            .context("wallpaper_count")?;
        Ok(count)
    }

    /// Number of wallpapers that have at least one AI tag.
    pub fn tagged_count(&self) -> Result<i64> {
        let conn = self.conn.lock().unwrap();
        let count: i64 = conn
            .query_row(
                "SELECT COUNT(DISTINCT wallpaper_id) FROM tags",
                [],
                |row| row.get(0),
            )
            .context("tagged_count")?;
        Ok(count)
    }
}

/// Detect media type from file extension (no DB needed).
fn detect_media_type_from_ext(path: &str) -> String {
    let lower = path.to_ascii_lowercase();
    if lower.ends_with(".gif") {
        return "gif".into();
    }
    const VIDEO_EXTS: &[&str] = &[".mp4", ".mkv", ".webm", ".avi", ".mov", ".wmv", ".flv", ".m4v"];
    if VIDEO_EXTS.iter().any(|e| lower.ends_with(e)) {
        return "video".into();
    }
    "image".into()
}

/// Update the path of a wallpaper in all tables (after rename).
impl Db {
    pub fn rename_path(&self, old_path: &str, new_path: &str) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("UPDATE wallpapers SET path = ?1 WHERE path = ?2", params![new_path, old_path])
            .context("rename wallpapers")?;
        conn.execute("UPDATE history SET path = ?1 WHERE path = ?2", params![new_path, old_path])
            .context("rename history")?;
        conn.execute("UPDATE favorites SET path = ?1 WHERE path = ?2", params![new_path, old_path])
            .context("rename favorites")?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use tempfile::NamedTempFile;

    fn test_db() -> Db {
        let tmp = NamedTempFile::new().unwrap();
        let path = PathBuf::from(tmp.path());
        Db::open(&path).unwrap()
    }

    #[test]
    fn test_upsert_and_search() {
        let db = test_db();

        let id = db
            .upsert_wallpaper("/tmp/test.jpg", "image", Some("#ff0000"), Some(1920), Some(1080), None)
            .unwrap();
        assert!(id > 0);

        db.set_tags(id, &[("neon".into(), 0.9), ("city".into(), 0.7)])
            .unwrap();

        let results = db.search("neon", 10, false, false).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].path, "/tmp/test.jpg");
        assert!(results[0].tags.contains(&"neon".to_string()));
    }

    #[test]
    fn test_history() {
        let db = test_db();
        db.history_push("/tmp/a.jpg", Some("DP-1"), "fill").unwrap();
        db.history_push("/tmp/b.jpg", None, "span").unwrap();

        let list = db.history_list(10).unwrap();
        assert_eq!(list.len(), 2);
        assert_eq!(list[0].path, "/tmp/b.jpg"); // newest first

        let nth = db.history_nth(1).unwrap();
        assert!(nth.is_some());
        assert_eq!(nth.unwrap().path, "/tmp/a.jpg");

        db.history_clear().unwrap();
        assert_eq!(db.history_list(10).unwrap().len(), 0);
    }

    #[test]
    fn test_favorites() {
        let db = test_db();
        db.fav_add("/tmp/fav.png").unwrap();
        assert!(db.fav_contains("/tmp/fav.png").unwrap());

        let list = db.fav_list(10).unwrap();
        assert_eq!(list.len(), 1);

        db.fav_rm("/tmp/fav.png").unwrap();
        assert!(!db.fav_contains("/tmp/fav.png").unwrap());
    }

    #[test]
    fn test_palette() {
        let db = test_db();
        let id = db
            .upsert_wallpaper("/tmp/pal.jpg", "image", None, None, None, None)
            .unwrap();

        let colors = vec![
            ("primary".into(), "#aabbcc".into()),
            ("secondary".into(), "#112233".into()),
        ];
        db.set_palette(id, &colors).unwrap();

        let palette = db.get_palette(id).unwrap();
        assert_eq!(palette.len(), 2);
    }

    #[test]
    fn test_search_unlimited() {
        let db = test_db();
        // Insert 10 wallpapers
        for i in 0..10 {
            db.upsert_wallpaper(&format!("/tmp/wall_{i}.jpg"), "image", None, None, None, None)
                .unwrap();
        }

        // limit=0 should return all 10
        let results = db.search("wall", 0, false, false).unwrap();
        assert_eq!(results.len(), 10);

        // limit=3 should return only 3
        let results = db.search("wall", 3, false, false).unwrap();
        assert_eq!(results.len(), 3);

        // limit=0 with empty query should also return all
        let results = db.search("", 0, false, false).unwrap();
        assert_eq!(results.len(), 10);
    }

    #[test]
    fn test_search_history_unlimited() {
        let db = test_db();
        for i in 0..5 {
            db.history_push(&format!("/tmp/h_{i}.jpg"), None, "fill").unwrap();
        }

        let results = db.search_history("", 0, false, false).unwrap();
        assert_eq!(results.len(), 5);

        let results = db.search_history("", 2, false, false).unwrap();
        assert_eq!(results.len(), 2);
    }

    #[test]
    fn test_search_favorites_unlimited() {
        let db = test_db();
        for i in 0..5 {
            db.fav_add(&format!("/tmp/f_{i}.png")).unwrap();
        }

        let results = db.search_favorites("", 0, false, false).unwrap();
        assert_eq!(results.len(), 5);

        let results = db.search_favorites("", 2, false, false).unwrap();
        assert_eq!(results.len(), 2);
    }

    #[test]
    fn test_search_dot_filter_default() {
        let db = test_db();
        db.upsert_wallpaper("/tmp/visible.jpg", "image", None, None, None, None).unwrap();
        db.upsert_wallpaper("/tmp/.hidden.jpg", "image", None, None, None, None).unwrap();

        // Default: exclude dot files
        let results = db.search("jpg", 50, false, false).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].path, "/tmp/visible.jpg");
    }

    #[test]
    fn test_search_dot_filter_include() {
        let db = test_db();
        db.upsert_wallpaper("/tmp/visible.jpg", "image", None, None, None, None).unwrap();
        db.upsert_wallpaper("/tmp/.hidden.jpg", "image", None, None, None, None).unwrap();

        // include_dot: both visible and hidden
        let results = db.search("jpg", 50, true, false).unwrap();
        assert_eq!(results.len(), 2);
    }

    #[test]
    fn test_search_dot_filter_only() {
        let db = test_db();
        db.upsert_wallpaper("/tmp/visible.jpg", "image", None, None, None, None).unwrap();
        db.upsert_wallpaper("/tmp/.hidden.jpg", "image", None, None, None, None).unwrap();

        // only_dot: only hidden
        let results = db.search("jpg", 50, false, true).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].path, "/tmp/.hidden.jpg");
    }

    #[test]
    fn test_search_history_dot_filter() {
        let db = test_db();
        db.history_push("/tmp/normal.jpg", Some("DP-1"), "fill").unwrap();
        db.history_push("/tmp/.secret.jpg", Some("DP-1"), "fill").unwrap();

        // Default: exclude dot files
        let results = db.search_history("jpg", 50, false, false).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].path, "/tmp/normal.jpg");

        // include_dot
        let results = db.search_history("jpg", 50, true, false).unwrap();
        assert_eq!(results.len(), 2);

        // only_dot
        let results = db.search_history("jpg", 50, false, true).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].path, "/tmp/.secret.jpg");
    }

    #[test]
    fn test_search_favorites_dot_filter() {
        let db = test_db();
        db.fav_add("/tmp/fav_normal.png").unwrap();
        db.fav_add("/tmp/.fav_hidden.png").unwrap();

        // Default: exclude dot files
        let results = db.search_favorites("png", 50, false, false).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].path, "/tmp/fav_normal.png");

        // include_dot
        let results = db.search_favorites("png", 50, true, false).unwrap();
        assert_eq!(results.len(), 2);

        // only_dot
        let results = db.search_favorites("png", 50, false, true).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].path, "/tmp/.fav_hidden.png");
    }

    #[test]
    fn test_search_history_favorites_dot_filter() {
        let db = test_db();
        db.history_push("/tmp/both.jpg", Some("DP-1"), "fill").unwrap();
        db.history_push("/tmp/.both_hidden.jpg", Some("DP-1"), "fill").unwrap();
        db.fav_add("/tmp/both.jpg").unwrap();
        db.fav_add("/tmp/.both_hidden.jpg").unwrap();

        // Default: exclude dot
        let results = db.search_history_favorites("jpg", 50, false, false).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].path, "/tmp/both.jpg");

        // include_dot
        let results = db.search_history_favorites("jpg", 50, true, false).unwrap();
        assert_eq!(results.len(), 2);

        // only_dot
        let results = db.search_history_favorites("jpg", 50, false, true).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].path, "/tmp/.both_hidden.jpg");
    }

    #[test]
    fn test_rename_path() {
        let db = test_db();

        // Set up wallpaper, history, and favorite with old path
        db.upsert_wallpaper("/tmp/old.jpg", "image", None, None, None, None).unwrap();
        db.history_push("/tmp/old.jpg", Some("DP-1"), "fill").unwrap();
        db.fav_add("/tmp/old.jpg").unwrap();

        // Rename
        db.rename_path("/tmp/old.jpg", "/tmp/.old.jpg").unwrap();

        // Wallpaper index updated
        assert!(db.wallpaper_exists("/tmp/.old.jpg").unwrap());
        assert!(!db.wallpaper_exists("/tmp/old.jpg").unwrap());

        // History updated
        let history = db.history_list(10).unwrap();
        assert_eq!(history[0].path, "/tmp/.old.jpg");

        // Favorites updated
        assert!(db.fav_contains("/tmp/.old.jpg").unwrap());
        assert!(!db.fav_contains("/tmp/old.jpg").unwrap());
    }

    #[test]
    fn test_search_enriches_from_index() {
        let db = test_db();

        // Index a file with tags and color
        let id = db.upsert_wallpaper("/tmp/enriched.jpg", "image", Some("#ff0000"), None, None, None).unwrap();
        db.set_tags(id, &[("landscape".into(), 0.95)]).unwrap();

        // Add to history and favorites
        db.history_push("/tmp/enriched.jpg", None, "fill").unwrap();
        db.fav_add("/tmp/enriched.jpg").unwrap();

        // Search history — should have enriched data
        let results = db.search_history("enriched", 10, false, false).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].media_type, "image");
        assert_eq!(results[0].dominant_color.as_deref(), Some("#ff0000"));
        assert!(results[0].tags.contains(&"landscape".to_string()));
        assert!(results[0].is_fav);

        // Search favorites — should also be enriched
        let results = db.search_favorites("enriched", 10, false, false).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].dominant_color.as_deref(), Some("#ff0000"));
        assert!(results[0].tags.contains(&"landscape".to_string()));
    }

    #[test]
    fn test_fav_rm_by_id() {
        let db = test_db();
        db.fav_add("/tmp/byid.png").unwrap();

        let list = db.fav_list(10).unwrap();
        assert_eq!(list.len(), 1);
        let id = list[0].id;

        // Remove by numeric id
        let removed = db.fav_rm(&id.to_string()).unwrap();
        assert!(removed);
        assert!(!db.fav_contains("/tmp/byid.png").unwrap());
    }

    #[test]
    fn test_history_nth_bounds() {
        let db = test_db();
        db.history_push("/tmp/a.jpg", None, "fill").unwrap();

        // offset 0 = most recent
        assert!(db.history_nth(0).unwrap().is_some());
        // offset 1 = out of bounds
        assert!(db.history_nth(1).unwrap().is_none());
        // large offset
        assert!(db.history_nth(999).unwrap().is_none());
    }

    #[test]
    fn test_passes_dot_filter() {
        let db = test_db();

        // Regular file — default filter keeps it
        assert!(db.passes_dot_filter("/tmp/photo.jpg", false, false));
        // Regular file — only_dot excludes it
        assert!(!db.passes_dot_filter("/tmp/photo.jpg", false, true));

        // Dot file — default filter excludes it
        assert!(!db.passes_dot_filter("/tmp/.hidden.jpg", false, false));
        // Dot file — include_dot keeps it
        assert!(db.passes_dot_filter("/tmp/.hidden.jpg", true, false));
        // Dot file — only_dot keeps it
        assert!(db.passes_dot_filter("/tmp/.hidden.jpg", false, true));
    }
}
