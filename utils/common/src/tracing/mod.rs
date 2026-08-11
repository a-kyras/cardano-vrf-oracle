use std::io::IsTerminal;

use clap::{Args, ValueEnum};
use tracing_subscriber::EnvFilter;
use tracing_subscriber::filter::LevelFilter;
use tracing_subscriber::fmt::format::FmtSpan;

#[derive(Debug, Clone, Copy, ValueEnum)]
pub enum UseColor {
    Auto,
    Always,
    Never,
}

#[derive(Debug, Args)]
pub struct LoggingArgs {
    /// Directive based filter. This filter overrides all other filters.
    #[arg(long, env = "RUST_LOG", value_name = "FILTER", global = true)]
    log_filter: Option<String>,

    /// Log level filter
    #[arg(long, env = "LOG_LEVEL", value_name = "LEVEL", default_value = "info", global = true)]
    log_level: LevelFilter,

    /// Specify to use color and other ansi text ornaments
    #[arg(long, short, env = "LOG_COLOR", default_value = "auto", global = true)]
    log_color: UseColor
}

impl LoggingArgs {
    pub fn init_cli_logging(&self) {
        let builder = tracing_subscriber::fmt()
            .compact()
            .with_span_events(FmtSpan::NONE)
            .with_writer(std::io::stderr)
            .without_time()
            .with_target(false)
            .with_ansi(self.use_ansi());

        if let Some(filter) = &self.log_filter {
            builder.with_env_filter(EnvFilter::new(filter))
                .init()
        } else {
            builder.with_max_level(self.log_level)
                .init()
        }
    }

    fn use_ansi(&self) -> bool {
        match self.log_color {
            UseColor::Always => true,
            UseColor::Never => false,
            UseColor::Auto => std::io::stderr().is_terminal(),
        }
    }
}