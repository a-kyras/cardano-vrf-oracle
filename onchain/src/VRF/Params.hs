{-# LANGUAGE NoImplicitPrelude #-}
module VRF.Params
  ( ietfDefaultDst
  , mkVrfParams
  , VrfParams(..)
  ) where

import PlutusTx ( makeLift )
import PlutusTx.Prelude

-- | Default hash-to-curve DST: the IETF basic-scheme ciphersuite ID for
-- minimal-signature-size (signature in G1). 43 bytes of printable ASCII.
{-# INLINEABLE ietfDefaultDst #-}
ietfDefaultDst :: BuiltinByteString
ietfDefaultDst = "BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_NUL_"

-- | Deployment parameters, lifted into the compiled script.
--   Both are fixed before the script hash is computed -- not in redeemer data.
data VrfParams = VrfParams
    { vpPubKey :: BuiltinByteString -- compressed G2 public key, 96 bytes
    , vpDst    :: BuiltinByteString -- hash-to-curve domain separation tag, defaults to ietfDefaultDst
    }

makeLift ''VrfParams

-- | Off-chain construction. Substitutes the IETF default when no DST is given.
{-# INLINABLE mkVrfParams #-}
mkVrfParams :: BuiltinByteString -> Maybe BuiltinByteString -> VrfParams
mkVrfParams pk mdst = VrfParams pk $ fromMaybe ietfDefaultDst mdst