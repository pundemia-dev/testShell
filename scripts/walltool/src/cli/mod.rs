use clap::{Args, Parser, Subcommand, ValueEnum};
use std::path::PathBuf;

// ── Global CLI ──────────────────────────────────────────────────────────────

#[derive(Debug, Parser)]
#[command(
    name = "walltool",
    version,
    about = "Ultimate Wallpaper & Theme Manager",
    long_about = "Desktop wallpaper combo: Hyprland + Matugen + AI tagging + SQLite search"
)]
pub struct Cli {
    /// Format output as JSON (for QML consumption)
    #[arg(short, long, global = true)]
    pub json: bool,

    /// Enable verbose / debug logging
    #[arg(short, long, global = true)]
    pub verbose: bool,

    #[command(subcommand)]
    pub command: Commands,
}

// ── Top-level commands ──────────────────────────────────────────────────────

#[derive(Debug, Subcommand)]
pub enum Commands {
    /// Wallpaper management
    #[command(alias = "wp")]
    Wallpaper {
        #[command(subcommand)]
        action: WallpaperAction,
    },

    /// Theme & color scheme management
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

    /// Monitor utilities (Hyprland IPC)
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

// ── Shared / flattened option groups ────────────────────────────────────────

#[derive(Debug, Clone, Args)]
pub struct DisplayOptions {
    /// Target monitor name (e.g. DP-1). Default: all monitors.
    #[arg(short, long)]
    pub monitor: Option<String>,

    /// Display mode
    #[arg(long, default_value = "fill")]
    pub mode: DisplayMode,
}

#[derive(Debug, Clone, ValueEnum, Default)]
pub enum DisplayMode {
    #[default]
    Fill,
    Fit,
    Center,
    Stretch,
    Span,
}

#[derive(Debug, Clone, Args)]
pub struct MediaOptions {
    /// Mute audio (video / web wallpapers)
    #[arg(long)]
    pub mute: bool,

    /// Volume level 0-100
    #[arg(long, value_parser = clap::value_parser!(u8).range(0..=100))]
    pub volume: Option<u8>,

    /// Skip Matugen theme generation
    #[arg(long)]
    pub no_theme: bool,
}

#[derive(Debug, Clone, Args)]
pub struct DotfileOptions {
    /// Include hidden (dot) files and directories
    #[arg(short = 'i', long)]
    pub include_dot: bool,

    /// Use ONLY hidden (dot) files and directories
    #[arg(short = 'o', long, conflicts_with = "include_dot")]
    pub only_dot: bool,
}

#[derive(Debug, Clone, ValueEnum)]
pub enum MediaType {
    Image,
    Video,
    Web,
    All,
}

// ── 1. Wallpaper ────────────────────────────────────────────────────────────

#[derive(Debug, Subcommand)]
pub enum WallpaperAction {
    /// Set wallpaper from file or URL
    #[command(alias = "s")]
    Set(WpSetArgs),

    /// Set random wallpaper from directory
    #[command(alias = "rnd")]
    Random(WpRandomArgs),

    /// Search local wallpaper DB (AI tags, paths, colors)
    Search(WpSearchArgs),

    /// Toggle hidden state of a file (add/remove leading dot)
    ToggleHidden {
        /// File path to toggle
        path: String,
    },

    /// Trigger background indexing of a directory
    Index(WpIndexArgs),

    /// Clear wallpaper (black screen), stop players
    Clear {
        /// Target monitor (all if omitted)
        monitor: Option<String>,
    },

    /// Print current wallpaper state
    #[command(alias = "cur")]
    Current {
        /// Target monitor (all if omitted)
        monitor: Option<String>,
    },

    /// Resume video / GIF playback
    Play {
        monitor: Option<String>,
    },

    /// Pause video / GIF playback
    Pause {
        monitor: Option<String>,
    },

    /// Toggle mute on the fly
    ToggleMute {
        monitor: Option<String>,
    },

    /// Wallpaper history navigation
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
    /// File path or URL
    pub path: String,

    #[command(flatten)]
    pub display: DisplayOptions,

    #[command(flatten)]
    pub media: MediaOptions,
}

#[derive(Debug, Args)]
pub struct WpRandomArgs {
    /// Directory to pick from
    pub dir: PathBuf,

    /// Filter by media type
    #[arg(short = 't', long = "type")]
    pub media_type: Option<MediaType>,

    /// Search subdirectories
    #[arg(short, long)]
    pub recursive: bool,

    /// Filter by AI tags or filename
    #[arg(short, long)]
    pub query: Option<String>,

    #[command(flatten)]
    pub dots: DotfileOptions,

    #[command(flatten)]
    pub display: DisplayOptions,

    #[command(flatten)]
    pub media: MediaOptions,
}

#[derive(Debug, Args)]
pub struct WpSearchArgs {
    /// Search query (name, AI tags, colors)
    pub query: String,

    /// Max results
    #[arg(short, long, default_value_t = 50)]
    pub limit: usize,

    /// Search within history instead of the index
    #[arg(long)]
    pub history: bool,

    /// Search within favorites instead of the index
    #[arg(long)]
    pub favorites: bool,

    #[command(flatten)]
    pub dots: DotfileOptions,
}

#[derive(Debug, Args)]
pub struct WpIndexArgs {
    /// Directory to index
    pub dir: PathBuf,

    /// Re-index files already present in DB
    #[arg(long)]
    pub force: bool,
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

    /// Go back in history
    #[command(alias = "p")]
    Prev,

    /// Go forward in history
    #[command(alias = "n")]
    Next,

    /// Clear history
    #[command(alias = "clr")]
    Clear,
}

// ── 1b. Favorites ───────────────────────────────────────────────────────────

#[derive(Debug, Subcommand)]
pub enum FavAction {
    /// Add to favorites (current wallpaper if path omitted)
    #[command(alias = "a")]
    Add {
        path: Option<PathBuf>,
    },

    /// Remove from favorites
    #[command(alias = "rm")]
    Rm {
        /// Path or DB id
        target: String,
    },

    /// List favorites
    #[command(alias = "ls")]
    List {
        #[arg(short, long, default_value_t = 50)]
        limit: usize,
    },

    /// Set random wallpaper from favorites only
    #[command(alias = "sr")]
    SetRandom {
        #[command(flatten)]
        display: DisplayOptions,

        #[command(flatten)]
        media: MediaOptions,
    },
}

// ── 2. Theme ────────────────────────────────────────────────────────────────

#[derive(Debug, Subcommand)]
pub enum ThemeAction {
    /// Generate theme from an image without setting it as wallpaper
    #[command(alias = "gen")]
    Generate {
        /// Image path
        path: PathBuf,
    },

    /// Dark / light mode control
    Mode {
        #[command(subcommand)]
        action: ThemeModeAction,
    },

    /// Matugen palette variant
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
    /// Toggle between dark and light
    #[command(alias = "t")]
    Toggle,
    /// Automatic mode (time-of-day / sunset)
    Auto,
    /// Print current mode
    #[command(alias = "cur")]
    Current,
}

#[derive(Debug, Clone, ValueEnum)]
pub enum ThemeModeValue {
    Dark,
    Light,
}

#[derive(Debug, Subcommand)]
pub enum ThemePaletteAction {
    /// Set Matugen palette variant
    Set {
        /// e.g. tonal-spot, fidelity, monochrome, rainbow
        variant: String,
    },
    /// List available palette variants
    #[command(alias = "ls")]
    List,
    /// Print current variant
    #[command(alias = "cur")]
    Current,
}

// ── 3. Config / Profiles ────────────────────────────────────────────────────

#[derive(Debug, Subcommand)]
pub enum ConfigAction {
    /// Profile management (wallpapers + monitors + theme = 1 snapshot)
    Profile {
        #[command(subcommand)]
        action: ProfileAction,
    },

    /// Open config.toml in $EDITOR
    Edit,
}

#[derive(Debug, Subcommand)]
pub enum ProfileAction {
    /// Save current state as a named profile
    #[command(alias = "sv")]
    Save { name: String },

    /// Load and apply a saved profile
    #[command(alias = "ld")]
    Load { name: String },

    /// List all profiles
    #[command(alias = "ls")]
    List,

    /// Delete a profile
    #[command(alias = "rm")]
    Rm { name: String },
}

// ── 4. Monitor ──────────────────────────────────────────────────────────────

#[derive(Debug, Subcommand)]
pub enum MonitorAction {
    /// List monitors: resolution, position, scale
    #[command(alias = "ls")]
    List,

    /// Flash monitor names on screen for 3 seconds
    Identify,
}

// ── 5. Daemon ───────────────────────────────────────────────────────────────

#[derive(Debug, Subcommand)]
pub enum DaemonAction {
    /// Start daemon (blocking, intended for hyprland.conf exec-once)
    Start,

    /// Send shutdown signal to daemon
    Stop,

    /// Print daemon status (uptime, RAM, slideshow, AI indexer)
    #[command(alias = "st")]
    Status,

    /// Game Mode: pause all video, stop slideshow timers, freeze AI indexer
    PauseAll,

    /// Exit Game Mode: resume background activity
    ResumeAll,

    /// Slideshow management
    Slideshow {
        #[command(subcommand)]
        action: SlideshowAction,
    },
}

#[derive(Debug, Subcommand)]
pub enum SlideshowAction {
    /// Start slideshow from a directory
    Start(SlideshowStartArgs),

    /// Stop slideshow
    Stop {
        /// Stop only for this monitor (all if omitted)
        monitor: Option<String>,
    },
}

#[derive(Debug, Args)]
pub struct SlideshowStartArgs {
    /// Directory with wallpapers
    pub dir: PathBuf,

    /// Interval in seconds (default 900 = 15 min)
    #[arg(short = 'i', long, default_value_t = 900)]
    pub interval: u64,

    /// Target monitor (all if omitted)
    #[arg(long)]
    pub monitor: Option<String>,

    /// Filter by media type
    #[arg(short = 't', long = "type")]
    pub media_type: Option<MediaType>,

    #[command(flatten)]
    pub dots: DotfileOptions,

    /// Filter by AI tags or filename
    #[arg(short, long)]
    pub query: Option<String>,
}
