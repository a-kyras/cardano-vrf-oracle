use std::path::PathBuf;
use clap::Parser;

use common::{
    blst::constants::IETF_MIN_SIG_DTF,
    tracing::LoggingArgs
};

/// Generate a fresh VRF operator key and the deployment config.
#[derive(Parser, Debug)]
#[command(version, about)]
pub struct Args {
    #[command(flatten)]
    pub logging: LoggingArgs,

    /// Output directory
    #[arg(long, env = "GEN_OUT_PATH", default_value = "./artifacts/config.json")]
    pub out: PathBuf,

    /// Hash-to-curve domain separation tag
    #[arg(long, env = "GEN_DST", default_value = IETF_MIN_SIG_DTF)]
    pub dst: String,

    /// Seed value for generating configuration.
    #[arg(long, env = "GEN_SEED")]
    pub seed: Option<String>,

    /// Overwrite existing files
    #[arg(long, short)]
    pub force: bool,
}