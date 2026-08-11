use std::path::Path;
use super::{PublicKey, SecretKey};

use serde::{Deserialize, Serialize};
use crate::blst::Signature;
use crate::blst::errors::{LoadConfigError, SaveConfigError, VerifyError};

#[derive(Debug, Clone)]
#[derive(Serialize, Deserialize)]
struct ConfigFileFormat {
    sk: String,
    dst: String,
}

impl ConfigFileFormat {
    pub fn dump_string(&self) -> Result<String, SaveConfigError> {
        Ok(serde_json::to_string(&self)?)
    }

    pub async fn dump_to_file(&self, path: impl AsRef<Path>) -> Result<(), SaveConfigError> {
        Ok(tokio::fs::write(path, self.dump_string()?).await?)
    }

    pub fn into_config(self) -> Result<Config, LoadConfigError> {
        let sk_bytes = hex::decode(self.sk.as_bytes())?;
        let sk = SecretKey::from_bytes(&sk_bytes)?;
        Ok(Config::new(sk, self.dst))
    }

    pub async fn load_from_file(path: impl AsRef<Path>) -> Result<Self, LoadConfigError> {
        let config_data = tokio::fs::read(path).await?;
        Ok(serde_json::from_slice(&config_data)?)
    }
}

#[derive(Debug, Clone)]
pub struct Config {
    pub secret_key: SecretKey,
    pub public_key: PublicKey,
    pub domain_separator: String,
}

impl Config {
    pub fn new(secret_key: SecretKey, dst: impl Into<String>) -> Self {
        let public_key = secret_key.sk_to_pk();
        Self {
            secret_key,
            public_key,
            domain_separator: dst.into(),
        }
    }

    pub async fn load_from_file(path: impl AsRef<Path>) -> Result<Self, LoadConfigError> {
        ConfigFileFormat::load_from_file(path)
            .await
            .and_then(ConfigFileFormat::into_config)
    }

    pub async fn dump_to_file(self, path: impl AsRef<Path>) -> Result<(), SaveConfigError> {
        self.into_file_format()
            .dump_to_file(path)
            .await
    }

    pub fn sign(&self, input: impl AsRef<[u8]>) -> Signature {
        self.secret_key.sign(input.as_ref(), self.domain_separator.as_bytes(), &[])
    }

    pub fn verify(&self, input: impl AsRef<[u8]>, proof: impl AsRef<[u8]>) -> Result<(), VerifyError> {
        let signature = Signature::from_bytes(proof.as_ref())
            .map_err(VerifyError::from_signature_error)?;

        VerifyError::map_verify_result(signature.verify(
            true,
            input.as_ref(),
            self.domain_separator.as_bytes(),
            &[],
            &self.public_key,
            true
        ))
    }

    fn into_file_format(self) -> ConfigFileFormat {
        ConfigFileFormat {
            sk: hex::encode(self.secret_key.to_bytes()),
            dst: self.domain_separator
        }
    }
}
