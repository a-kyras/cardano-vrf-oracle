pub mod args;

use clap::Parser;
use std::process::{ExitCode};
use tracing::{instrument};
use tap::TapFallible;

use args::Args;
use common::blst::types::Config;

#[tokio::main]
async fn main() -> ExitCode {
    let args = Args::parse();
    args.logging.init_cli_logging();

    match run(args).await {
        Ok(_) => ExitCode::SUCCESS,
        Err(_) => ExitCode::FAILURE,
    }
}

#[instrument(skip_all, fields(config = %args.config.display()))]
async fn run(args: Args) -> Result<(), anyhow::Error> {
    let config = Config::load_from_file(args.config).await
        .tap_err(|err| tracing::error!(error = %err, "failed to load config file"))?;

    let input = args.input.bytes()
        .tap_err(|err| tracing::error!(error = %err, "invalid input"))?;
    let input_hex = hex::encode(&input);

    let proof = config.sign(&input);
    let proof_hex = hex::encode(proof.to_bytes());

    tracing::info!(%proof_hex, input_hex, "success");

    Ok(())
}