//! Utility for generating new operator key and deployment configuration.
//!
//! Successful run generates JSON config file:
//!
//!     <out_path>/vrf_config.json - Configuration files containing sensitive information. Do not publish these.
//!
//! Usage:
//!
//!     gen_config --out config
//!     gen_config --out config --dst CUSTOM_TAG --seed DEADBEEF -f

mod args;

use std::process::ExitCode;
use clap::Parser;
use rand::{rng, Rng};
use sha2::{Digest, Sha256};
use tap::{TapFallible};
use tracing::{instrument};

use args::Args;
use common::blst::SecretKey;
use common::blst::types::Config;

fn generate_secret_key(maybe_seed_phrase: &Option<String>) -> Result<SecretKey, anyhow::Error> {
    let ikm: [u8; 32] = match maybe_seed_phrase {
        Some(phrase) => Sha256::digest(phrase.as_bytes()).into(),
        None => {
            let mut ikm = [0; 32];
            rng().fill_bytes(&mut ikm);
            ikm
        }
    };

    Ok(SecretKey::key_gen(&ikm, &[])
        .map_err(|err| anyhow::anyhow!("failed to generate secret: {err:?}"))?)
}

#[tokio::main]
async fn main() -> ExitCode {
    let args = Args::parse();
    args.logging.init_cli_logging();
    match run(args).await {
        Ok(_) => ExitCode::SUCCESS,
        Err(_) => ExitCode::FAILURE,
    }
}

#[instrument(skip_all, fields(path = %args.out.display()))]
async fn run(args: Args) -> Result<(), anyhow::Error> {
    let config_already_exists = args.out.exists();

    if config_already_exists && !args.force {
        tracing::error!("file already exists");
        anyhow::bail!("file already exists");
    }

    let sk = generate_secret_key(&args.seed)
        .tap_err(|err| tracing::error!(err = ?err, "failed to generate secret key"))?;

    let script_config = Config::new(sk, args.dst);

    if config_already_exists {
        tracing::warn!("overwriting existing params file");
    } else {
        if let Some(paren) = args.out.parent() {
            tokio::fs::create_dir_all(paren).await
                .tap_err(|err| tracing::error!(error = ?err, "failed to create parent directory"))?;
        }
    }

    script_config.dump_to_file(&args.out).await
        .tap_err(|err| tracing::error!(error = %err, "failed to save params file"))?;

    tracing::info!("config written to file");

    Ok(())
}
