use blst::BLST_ERROR;

#[derive(Debug)]
#[derive(thiserror::Error)]
pub enum SaveConfigError {
    #[error(transparent)]
    Serialize(#[from] serde_json::Error),
    #[error(transparent)]
    IO(#[from] std::io::Error)
}

#[derive(Debug)]
#[derive(thiserror::Error)]
pub enum LoadConfigError {
    #[error(transparent)]
    IO(#[from] std::io::Error),
    #[error(transparent)]
    Deserialize(#[from] serde_json::Error),
    #[error(transparent)]
    Hex(#[from] hex::FromHexError),
    #[error("{0:?}")]
    Blst(BLST_ERROR),
}

impl From<BLST_ERROR> for LoadConfigError {
    fn from(value: BLST_ERROR) -> Self {
        Self::Blst(value)
    }
}

#[derive(Debug)]
#[derive(thiserror::Error)]
pub enum VerifyError {
    #[error("Invalid proof: {0:?}")]
    Signature(BLST_ERROR),

    #[error("Verification failed: {0:?}")]
    Verify(BLST_ERROR)
}

impl VerifyError {
    pub fn from_signature_error(inner: BLST_ERROR) -> Self {
        Self::Signature(inner)
    }

    pub fn map_verify_result(result: BLST_ERROR) -> Result<(), Self> {
        match result {
            BLST_ERROR::BLST_SUCCESS => Ok(()),
            error => Err(Self::Verify(error)),
        }
    }
}