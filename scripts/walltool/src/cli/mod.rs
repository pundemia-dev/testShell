use clap::{Args, Parser, Subcommand, ValueEnum};
use std::path::PathBuf;

// ══════════════════════════════════════════════════════════════════════════════
//  Global CLI
// ══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Parser)]
#[command(
    name = "walltool",
    version,
    about = "awww + matugen orchestrator",
    long_about = "Wallpaper daemon orchestrator: awww for rendering, matugen for Material You themes, SQLite for search"
)]
pub struct Cli {
    /// Format output as JSON
    #[arg(short, long, global = true)]
    pub json: bool,

    /// Enable verbose / debug logging
    #[arg(short, long, global = true)]
    pub verbose: bool,

    #[command(subcommand)]
    pub command: Commands,
}

// ══════════════════════════════════════════════════════════════════════════════
//  Top-level commands
// ══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Subcommand)]
pub enum Commands {
    /// Wallpaper management
    #[command(alias = "wp")]
    Wallpaper {
        #[command(subcommand)]
        action: WallpaperAction,
    },

    /// Theme & color scheme management (matugen)
    #[command(alias = "th")]
    Theme {
        #[command(subcommand)]
        action: ThemeAction,
    },

    /// Config profiles
    #[command(alias = "cfg")]
    Config {
        #[command(subcommand)]
        action: ConfigAction,
    },

    /// Monitor utilities
    #[command(alias = "mon")]
    Monitor {
        #[command(subcommand)]
        action: MonitorAction,
    },

    /// Daemon control
    #[command(alias = "d")]
    Daemon {
        #[command(subcommand)]
        action: DaemonAction,
    },
}

// ══════════════════════════════════════════════════════════════════════════════
//  Shared option groups (flattened into commands)
// ══════════════════════════════════════════════════════════════════════════════

/// Options passed directly to `awww img`
#[derive(Debug, Clone, Default, Args)]
pub struct AwwwOptions {
    /// Comma-separated list of outputs (maps to awww -o). Default: all.
    #[arg(short = 'o', long)]
    pub outputs: Option<String>,

    /// awww daemon namespace
    #[arg(short = 'n', long)]
    pub namespace: Option<String>,

    /// Resize mode: no, crop, fit, stretch
    #[arg(long, value_enum)]
    pub resize: Option<ResizeMode>,

    /// Fill color in hex format (rrggbb or rrggbbaa, # optional)
    #[arg(long, value_parser = parse_color)]
    pub fill_color: Option<String>,

    /// Image scaling filter
    #[arg(long, value_enum)]
    pub filter: Option<ImageFilter>,

    /// Transition type
    #[arg(long = "transition-type", value_enum)]
    pub transition_type: Option<TransitionType>,

    /// Transition step (1-255). Default: 2 for simple, 90 for others
    #[arg(long = "transition-step", value_parser = clap::value_parser!(u8).range(1..=255))]
    pub transition_step: Option<u8>,

    /// Transition duration in seconds
    #[arg(long = "transition-duration")]
    pub transition_duration: Option<f64>,

    /// Transition FPS (default: 30)
    #[arg(long = "transition-fps")]
    pub transition_fps: Option<u32>,

    /// Transition angle in degrees (for wipe/wave)
    #[arg(long = "transition-angle")]
    pub transition_angle: Option<f64>,

    /// Transition position (for grow/outer): center, top, left, 0.5,0.5, etc.
    #[arg(long = "transition-pos")]
    pub transition_pos: Option<String>,

    /// Bezier curve for fade transition (e.g. .54,0,.34,.99)
    #[arg(long = "transition-bezier")]
    pub transition_bezier: Option<String>,

    /// Wave parameters for wave transition (e.g. 20,20)
    #[arg(long = "transition-wave")]
    pub transition_wave: Option<String>,

    /// Invert Y in transition-pos
    #[arg(long = "invert-y")]
    pub invert_y: bool,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
pub enum ResizeMode {
    No,
    Crop,
    Fit,
    Stretch,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
pub enum ImageFilter {
    Nearest,
    Bilinear,
    CatmullRom,
    Mitchell,
    Lanczos3,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
pub enum TransitionType {
    None,
    Simple,
    Fade,
    Left,
    Right,
    Top,
    Bottom,
    Wipe,
    Wave,
    Grow,
    Center,
    Any,
    Outer,
    Random,
}

/// Parse color: accepts #rrggbb, rrggbb, #rrggbbaa, rrggbbaa → always outputs rrggbbaa
fn parse_color(s: &str) -> Result<String, String> {
    let s = s.trim_start_matches('#');
    match s.len() {
        6 => {
            // Validate hex
            if s.chars().all(|c| c.is_ascii_hexdigit()) {
                Ok(format!("{s}ff"))
            } else {
                Err(format!("invalid hex color: {s}"))
            }
        }
        8 => {
            if s.chars().all(|c| c.is_ascii_hexdigit()) {
                Ok(s.to_string())
            } else {
                Err(format!("invalid hex color: {s}"))
            }
        }
        _ => Err(format!(
            "color must be 6 or 8 hex digits (rrggbb or rrggbbaa), got: {s}"
        )),
    }
}

/// Search and filter options (for search, random, slideshow)
#[derive(Debug, Clone, Default, Args)]
pub struct SearchOptions {
    /// Filter by search query (path, tags, color)
    #[arg(short = 'q', long)]
    pub query: Option<String>,

    /// Limit results to history entries
    #[arg(long)]
    pub history: bool,

    /// Limit results to favorites
    #[arg(long)]
    pub favorites: bool,

    /// Include hidden (dot) files
    #[arg(short = 'i', long = "include-dot")]
    pub include_dot: bool,

    /// Only hidden (dot) files
    #[arg(long = "only-dot", conflicts_with = "include_dot")]
    pub only_dot: bool,

    /// Sort field
    #[arg(long = "sort-by", value_enum, default_value = "score")]
    pub sort_by: SortField,

    /// Reverse sort order
    #[arg(long)]
    pub reverse: bool,

    /// Max results
    #[arg(short = 'l', long, default_value_t = 50)]
    pub limit: usize,
}

#[derive(Debug, Clone, Copy, Default, ValueEnum)]
pub enum SortField {
    #[default]
    Score,
    Time,
    Name,
    Color,
}

/// Matugen-specific options
#[derive(Debug, Clone, Args)]
pub struct MatugenCliOptions {
    /// Skip theme generation
    #[arg(long = "no-theme")]
    pub no_theme: bool,
}

// ══════════════════════════════════════════════════════════════════════════════
//  1. Wallpaper commands
// ══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Subcommand)]
pub enum WallpaperAction {
    /// Set wallpaper (awww img + matugen + history)
    #[command(alias = "s")]
    Set(WpSetArgs),

    /// Preview mode: start, stop, commit
    Preview {
        #[command(subcommand)]
        action: PreviewAction,
    },

    /// Set random wallpaper from directory
    #[command(alias = "rnd")]
    Random(WpRandomArgs),

    /// Search wallpaper DB
    Search(WpSearchArgs),

    /// Toggle hidden state (add/remove leading dot)
    ToggleHidden {
        path: String,
    },

    /// Per-wallpaper awww options
    Options {
        #[command(subcommand)]
        action: WpOptionsAction,
    },

    /// Index directory into DB
    Index(WpIndexArgs),

    /// Clear screen (awww clear)
    Clear(WpClearArgs),

    /// Clear awww cache
    ClearCache,

    /// Restore last wallpaper (awww restore)
    Restore(WpRestoreArgs),

    /// Wallpaper history
    #[command(alias = "h")]
    History {
        #[command(subcommand)]
        action: HistoryAction,
    },

    /// Favorites management
    #[command(alias = "f")]
    Fav {
        #[command(subcommand)]
        action: FavAction,
    },
}

#[derive(Debug, Args)]
pub struct WpSetArgs {
    /// Image path
    pub path: String,

    #[command(flatten)]
    pub awww: AwwwOptions,

    #[command(flatten)]
    pub matugen: MatugenCliOptions,
}

#[derive(Debug, Subcommand)]
pub enum PreviewAction {
    /// Start preview (saves backup, doesn't write to history)
    Start(WpPreviewStartArgs),

    /// Stop preview (restore from backup)
    Stop,

    /// Commit preview (write to history, clear backup)
    Commit,
}

#[derive(Debug, Args)]
pub struct WpPreviewStartArgs {
    /// Image path
    pub path: String,

    #[command(flatten)]
    pub awww: AwwwOptions,
}

#[derive(Debug, Args)]
pub struct WpRandomArgs {
    /// Directory to pick from
    pub dir: PathBuf,

    /// Recursive search
    #[arg(short, long)]
    pub recursive: bool,

    #[command(flatten)]
    pub search: SearchOptions,

    #[command(flatten)]
    pub awww: AwwwOptions,

    #[command(flatten)]
    pub matugen: MatugenCliOptions,
}

#[derive(Debug, Args)]
pub struct WpSearchArgs {
    /// Search query
    pub query: String,

    #[command(flatten)]
    pub search: SearchOptions,

    /// Output as JSON
    #[arg(short, long)]
    pub json: bool,
}

#[derive(Debug, Subcommand)]
pub enum WpOptionsAction {
    /// Set per-wallpaper options
    Set(WpOptionsSetArgs),

    /// Get per-wallpaper options
    Get {
        /// Wallpaper path (current if omitted)
        path: Option<String>,
    },

    /// Clear per-wallpaper options
    Clear {
        /// Wallpaper path (current if omitted)
        path: Option<String>,
    },
}

#[derive(Debug, Args)]
pub struct WpOptionsSetArgs {
    /// Wallpaper path (current if omitted)
    pub path: Option<String>,

    #[command(flatten)]
    pub awww: AwwwOptions,
}

#[derive(Debug, Args)]
pub struct WpIndexArgs {
    /// Directory to index
    pub dir: PathBuf,

    /// Re-index existing files
    #[arg(long)]
    pub force: bool,
}

#[derive(Debug, Args)]
pub struct WpClearArgs {
    /// Fill color (rrggbb or rrggbbaa)
    #[arg(value_parser = parse_color)]
    pub color: Option<String>,

    /// Outputs (comma-separated)
    #[arg(short = 'o', long)]
    pub outputs: Option<String>,

    /// Namespace
    #[arg(short = 'n', long)]
    pub namespace: Option<String>,
}

#[derive(Debug, Args)]
pub struct WpRestoreArgs {
    /// Outputs (comma-separated)
    #[arg(short = 'o', long)]
    pub outputs: Option<String>,

    /// Namespace
    #[arg(short = 'n', long)]
    pub namespace: Option<String>,
}

// ── 1a. History ─────────────────────────────────────────────────────────────

#[derive(Debug, Subcommand)]
pub enum HistoryAction {
    /// List recent wallpapers
    #[command(alias = "ls")]
    List {
        #[arg(short, long, default_value_t = 20)]
        limit: usize,
    },

    /// Go back (instant transition, no history write)
    #[command(alias = "p")]
    Prev,

    /// Go forward
    #[command(alias = "n")]
    Next,

    /// Clear all history
    #[command(alias = "clr")]
    Clear,
}

// ── 1b. Favorites ───────────────────────────────────────────────────────────

#[derive(Debug, Subcommand)]
pub enum FavAction {
    /// Add to favorites (current if path omitted)
    #[command(alias = "a")]
    Add {
        path: Option<PathBuf>,
    },

    /// Remove from favorites
    #[command(alias = "rm")]
    Rm {
        /// Path or ID
        target: String,
    },

    /// List favorites
    #[command(alias = "ls")]
    List {
        #[arg(short, long, default_value_t = 50)]
        limit: usize,
    },

    /// Random from favorites
    #[command(alias = "sr")]
    SetRandom {
        #[command(flatten)]
        awww: AwwwOptions,
    },
}

// ══════════════════════════════════════════════════════════════════════════════
//  2. Theme commands (matugen)
// ══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Subcommand)]
pub enum ThemeAction {
    /// Generate theme from image (without setting wallpaper)
    #[command(alias = "gen")]
    Generate {
        path: PathBuf,
    },

    /// Set a single matugen parameter (for QML sliders)
    Set {
        /// Parameter name (scheme-type, contrast, lightness-dark, etc.)
        param: String,
        /// Parameter value
        value: String,
    },

    /// Get current theme state (all parameters as JSON)
    Get,

    /// Dark/light mode control
    Mode {
        #[command(subcommand)]
        action: ThemeModeAction,
    },

    /// Palette variant
    Palette {
        #[command(subcommand)]
        action: ThemePaletteAction,
    },
}

#[derive(Debug, Subcommand)]
pub enum ThemeModeAction {
    /// Set dark or light
    Set {
        #[arg(value_enum)]
        mode: ThemeModeValue,
    },
    /// Toggle dark ↔ light
    #[command(alias = "t")]
    Toggle,
    /// Auto mode (time-based)
    Auto,
    /// Current mode
    #[command(alias = "cur")]
    Current,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
pub enum ThemeModeValue {
    Dark,
    Light,
}

#[derive(Debug, Subcommand)]
pub enum ThemePaletteAction {
    /// Set palette variant
    Set {
        /// scheme-tonal-spot, scheme-fidelity, etc.
        variant: String,
    },
    /// List available variants
    #[command(alias = "ls")]
    List,
    /// Current variant
    #[command(alias = "cur")]
    Current,
}

// ══════════════════════════════════════════════════════════════════════════════
//  3. Config / Profiles
// ══════════════════════════════════════════════════════════════════════════════

// ── ADDITIONS TO cli/mod.rs ──────────────────────────────────────────────────
// Replace the existing ConfigAction enum with this expanded version.

#[derive(Debug, Subcommand)]
pub enum ConfigAction {
    /// Profile management
    Profile {
        #[command(subcommand)]
        action: ProfileAction,
    },

    // ── awww.defaults ────────────────────────────────────────────────────────

    /// Set awww default option (e.g. resize, transition_type)
    #[command(name = "set-awww-default", alias = "sad")]
    SetAwwwDefault {
        /// Option key: resize | fill_color | filter | transition_type |
        ///   transition_step | transition_duration | transition_fps |
        ///   transition_angle | transition_pos | transition_bezier |
        ///   transition_wave | invert_y
        key: String,
        /// Option value
        value: String,
    },

    /// Get all awww default options
    #[command(name = "get-awww-defaults", alias = "gad")]
    GetAwwwDefaults,

    // ── awww.global ──────────────────────────────────────────────────────────

    /// Set awww global namespace
    #[command(name = "set-namespace", alias = "sn")]
    SetNamespace {
        /// Namespace string (empty string to clear)
        value: String,
    },

    /// Get awww global namespace
    #[command(name = "get-namespace", alias = "gn")]
    GetNamespace,

    // ── awww.monitor.<name> ──────────────────────────────────────────────────

    /// List monitors with per-monitor config overrides
    #[command(name = "list-monitors", alias = "lm")]
    ListMonitorConfigs,

    /// Get per-monitor awww overrides for a specific monitor
    #[command(name = "get-monitor", alias = "gm")]
    GetMonitorOptions {
        /// Monitor name (e.g. DP-1, HDMI-A-1)
        monitor: String,
    },

    /// Set a per-monitor awww override option
    #[command(name = "set-monitor", alias = "sm")]
    SetMonitorOption {
        /// Monitor name (e.g. DP-1)
        monitor: String,
        /// Option key (same keys as set-awww-default)
        key: String,
        /// Option value
        value: String,
    },

    /// Remove all per-monitor overrides for a monitor
    #[command(name = "rm-monitor", alias = "rmm")]
    RmMonitorOptions {
        /// Monitor name
        monitor: String,
    },

    // ── matugen.defaults ─────────────────────────────────────────────────────

    /// Get all matugen default parameters
    #[command(name = "get-matugen-defaults", alias = "gmd")]
    GetMatugenDefaults,

    /// Set a matugen default parameter (persisted to config.toml)
    #[command(name = "set-matugen-default", alias = "smd")]
    SetMatugenDefault {
        /// Parameter: mode | scheme_type | contrast | source_color_index |
        ///   prefer | fallback_color | opacity | lightness_dark | lightness_light
        key: String,
        /// Value (use "null" to clear optional fields)
        value: String,
    },

    // ── theme.auto ───────────────────────────────────────────────────────────

    /// Get theme auto-mode schedule (sunrise/sunset)
    #[command(name = "get-theme-auto", alias = "gta")]
    GetThemeAuto,

    /// Set theme auto-mode schedule option
    #[command(name = "set-theme-auto", alias = "sta")]
    SetThemeAuto {
        /// Option: sunrise | sunset
        key: String,
        /// Time in HH:MM format (e.g. 07:00)
        value: String,
    },

    // ── slideshow ────────────────────────────────────────────────────────────

    /// Set slideshow option (e.g. dir, interval, include_hidden)
    #[command(name = "set-slideshow", alias = "ss")]
    SetSlideshowOption {
        /// Option key: dir | interval | include_hidden | only_hidden |
        ///   only_favorites | text_filter
        key: String,
        /// Option value
        value: String,
    },

    /// Get all slideshow options
    #[command(name = "get-slideshow", alias = "gs")]
    GetSlideshowOptions,

    // ── indexer ──────────────────────────────────────────────────────────────

    /// Get indexer configuration (watch_dirs, ai_tagging)
    #[command(name = "get-indexer", alias = "gi")]
    GetIndexer,

    /// Set indexer option
    #[command(name = "set-indexer", alias = "si")]
    SetIndexer {
        /// Option key: ai_tagging | add_watch_dir | rm_watch_dir
        key: String,
        /// Option value
        value: String,
    },

    // ── full config ──────────────────────────────────────────────────────────

    /// Show entire config as pretty-printed TOML
    #[command(name = "show", alias = "cat")]
    Show,

    /// Open config.toml in $EDITOR
    Edit,
}

// #[derive(Debug, Subcommand)]
// pub enum ConfigAction {
//     /// Profile management
//     Profile {
//         #[command(subcommand)]
//         action: ProfileAction,
//     },

//     /// Set awww default option (e.g. resize, transition_type)
//     #[command(name = "set-awww-default")]
//     SetAwwwDefault {
//         /// Option key (resize, filter, transition_type, etc.)
//         key: String,
//         /// Option value
//         value: String,
//     },

//     /// Get all awww default options
//     #[command(name = "get-awww-defaults")]
//     GetAwwwDefaults,

//     /// Set slideshow option (e.g. dir, interval, include_hidden)
//     #[command(name = "set-slideshow")]
//     SetSlideshowOption {
//         /// Option key (dir, interval, include_hidden, only_hidden, only_favorites, text_filter)
//         key: String,
//         /// Option value
//         value: String,
//     },

//     /// Get all slideshow options
//     #[command(name = "get-slideshow")]
//     GetSlideshowOptions,

//     /// Open config.toml in $EDITOR
//     Edit,
// }

#[derive(Debug, Subcommand)]
pub enum ProfileAction {
    /// Save current state
    #[command(alias = "sv")]
    Save { name: String },

    /// Load profile
    #[command(alias = "ld")]
    Load { name: String },

    /// List profiles
    #[command(alias = "ls")]
    List,

    /// Delete profile
    #[command(alias = "rm")]
    Rm { name: String },
}

// ══════════════════════════════════════════════════════════════════════════════
//  4. Monitor
// ══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Subcommand)]
pub enum MonitorAction {
    /// List monitors (via awww query)
    #[command(alias = "ls")]
    List,

    /// Identify monitors (awww query + notification)
    Identify,
}

// ══════════════════════════════════════════════════════════════════════════════
//  5. Daemon
// ══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Subcommand)]
pub enum DaemonAction {
    /// Start daemon (blocking)
    Start,

    /// Stop daemon
    Stop,

    /// Daemon status
    #[command(alias = "st")]
    Status,

    /// Game mode: awww pause + freeze timers
    PauseAll,

    /// Resume: awww restore (instant transition)
    ResumeAll,

    /// Slideshow
    Slideshow {
        #[command(subcommand)]
        action: SlideshowAction,
    },
}

#[derive(Debug, Subcommand)]
pub enum SlideshowAction {
    /// Start slideshow
    Start(SlideshowStartArgs),

    /// Stop slideshow
    Stop {
        /// Monitor (all if omitted)
        monitor: Option<String>,
    },
}

#[derive(Debug, Args)]
pub struct SlideshowStartArgs {
    /// Directory
    pub dir: PathBuf,

    /// Interval in seconds (default: 900 = 15 min)
    #[arg(short = 'i', long, default_value_t = 900)]
    pub interval: u64,

    /// Target monitor
    #[arg(long)]
    pub monitor: Option<String>,

    #[command(flatten)]
    pub search: SearchOptions,

    #[command(flatten)]
    pub awww: AwwwOptions,
}
