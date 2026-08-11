mod args;

use std::process::ExitCode;
use args::Args;

use clap::Parser;
use tap::TapFallible;
use tracing::instrument;
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

    let proof_bytes = hex::decode(&args.proof)
        .tap_err(|err| tracing::error!(error = %err, "failed to decode proof"))?;

    let input = args.input.bytes()
        .tap_err(|err| tracing::error!(error = %err, "invalid input"))?;
    let input_hex = hex::encode(&input);

    config.verify(&input, &proof_bytes)
        .tap_err(|err| tracing::error!(error = %err, proof_hex = args.proof, input_hex, "failed"))?;

    tracing::info!(proof_hex = args.proof, input_hex, "success");

    Ok(())
}
