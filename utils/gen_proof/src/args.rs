use std::path::PathBuf;
use clap::{Parser};
use common::tracing::LoggingArgs;

/// Off-chain verification of signature, using secret script configuration.
#[derive(Parser, Debug)]
#[command(version, about)]
pub struct Args {
    #[command(flatten)]
    pub logging: LoggingArgs,

    /// Path to script configuration
    #[arg(long, env = "CONFIG_PATH", default_value = "./artifacts/config.json")]
    pub config: PathBuf,

    #[command(flatten)]
    pub input: Input,
}

#[derive(Debug, clap::Args)]
#[group(required = true, multiple = false)]
pub struct Input {
    /// Input to gen_proof in hex-string format
    #[arg(long, global = true)]
    hex: Option<String>,

    /// Input to gen_proof in raw text format
    #[arg(long, global = true)]
    text: Option<String>
}

impl Input {
    pub fn bytes(&self) -> Result<Vec<u8>, anyhow::Error> {
        if let Some(hex) = &self.hex {
            Ok(hex::decode(hex)?)
        } else {
            // SAFETY: Unwrap here is safe, as the values are required and mutually exclusive.
            //         Thus, if hex is missing text must be present.
            Ok(self.text.clone().unwrap().into_bytes())
        }
    }
}
