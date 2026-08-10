{-# LANGUAGE NoImplicitPrelude #-}
-- | Pairing-based VRF verification on BLS12-381.
--
-- Construction: secret scalar @x@, public key @PK = x*G2@.
-- Proof over input @m@ is @sigma = x * hashToG1(m)@.
-- Verification check @e(sigma, G2) == e(hashToG1(m), PK)@, which holds
-- by bilinearity iff the same @x@ produced both sides.
--
-- Variant: minimal-signature-size (proof in G1, public key in G2).
module VRF.Verify
    ( verifyVrfProof
    , vrfOutput
    , vrfInputFromOutRef
    ) where

import PlutusLedgerApi.V3 ( TxOutRef )
import PlutusTx.Builtins ( serialiseData )
import PlutusTx.Prelude
import VRF.Params ( VrfParams(..) )

-- | Verify a VRF proof.
--
-- @pkCompressed@       96 bytes, compressed G2 point
-- @input@              the VRF input (see 'vrfInputFromOutRef')
-- @proofCompressed@    48 bytes, compressed G1 point
-- 
-- Uncompression also validates subgroup membership, so a malformed or off-subgroup point fails here.
{-# INLINABLE verifyVrfProof #-}
verifyVrfProof
    :: VrfParams
    -> BuiltinByteString
    -> BuiltinByteString
    -> Bool
verifyVrfProof params input proofCompressed =
        bls12_381_finalVerify lhs rhs
    where
        pkCompressed    = vpPubKey params
        dst             = vpDst params
        proof           = bls12_381_G1_uncompress proofCompressed
        pk              = bls12_381_G2_uncompress pkCompressed
        generator       = bls12_381_G2_uncompress bls12_381_G2_compressed_generator
        hashed          = bls12_381_G1_hashToGroup input dst
        lhs             = bls12_381_millerLoop proof generator
        rhs             = bls12_381_millerLoop hashed pk

-- | Derive the random output from a verified proof.
--
-- @proofCompressed@    48 bytes, compressed G1 point
--
-- The proof is a curve point: its encoding carries flag bits and algebraic structure, so it is not uniform.
-- Hashing flattens it to 32 uniform bytes.
--
-- Always derive this on-chain from the verified proof. Accepting it as redeemer data would let the publisher pair
-- a valid proof with a fabricated number.
{-# INLINABLE vrfOutput #-}
vrfOutput :: BuiltinByteString -> BuiltinByteString
vrfOutput = blake2b_256

-- | Derive the VRF input from the requester's own spent output reference.
--
-- The VRF is deterministic, so input uniqueness is what makes each request's randomness independent. A TxOutRef can
-- never repeat and is not chosen by the publisher, which gives both properties for free.
{-# INLINABLE vrfInputFromOutRef #-}
vrfInputFromOutRef :: TxOutRef -> BuiltinByteString
vrfInputFromOutRef = blake2b_256 . serialiseData . toBuiltinData
