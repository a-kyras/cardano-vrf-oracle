-- | Writes a CIP-57 blueprint for 'AlwaysTrue' to the path given as argv[1].
--
-- The blueprint is the handoff artifact: JSON containing the compiled script
-- plus schemas for its datum/redeemer, consumed by off-chain code. Emitting one
-- successfully proves the plugin ran and the UPLC serialised.
--
-- Note @PlutusV3@ appears twice, in the preamble *and* in 'compiledValidator'.
-- Both must match the ledger API the validator was written against — declaring
-- V2 for a V3 script yields a wrong script hash (so a wrong address) and UPLC
-- the V2 evaluator cannot run. The upstream plinth-template gets this wrong.
module Main where

import VRF.Compiled

import Data.ByteString qualified as BS
import Data.ByteString.Base16 qualified as B16
import Data.ByteString.Char8 qualified as BS8
import Data.ByteString.Short qualified as Short
import Data.Set qualified as Set
import PlutusLedgerApi.Common ( serialiseCompiledCode )
import PlutusTx.Blueprint
import PlutusTx.Builtins ( toBuiltin )
import System.Environment ( getArgs )
import VRF.Params ( VrfParams(..) )

vrfContractBlueprint :: VrfParams -> ContractBlueprint
vrfContractBlueprint params =
  MkContractBlueprint
    { contractId = Just "vrf-oracle"
    , contractPreamble = vrfPreamble
    , contractValidators = Set.singleton (vrfVerifierBlueprint params)
    , contractDefinitions = deriveDefinitions @'[()]
    }

vrfPreamble :: Preamble
vrfPreamble =
  MkPreamble
    { preambleTitle = "VRF Oracle"
    , preambleDescription =
        Just "Pairing-based VRF verification on BLS12-381 (minimal-signature-size)"
    , preambleVersion = "0.1.0"
    , preamblePlutusVersion = PlutusV3
    , preambleLicense = Just "MIT"
    }

vrfVerifierBlueprint :: VrfParams -> ValidatorBlueprint referencedTypes
vrfVerifierBlueprint params =
  MkValidatorBlueprint
    { validatorTitle = "VRF Verifier"
    , validatorDescription = Just "Placeholder: pure verification function, not yet a validator"
    , validatorParameters = []
    , validatorRedeemer =
        MkArgumentBlueprint
          { argumentTitle = Just "Redeemer"
          , argumentDescription = Just "Placeholder until the request validator exists"
          , argumentPurpose = Set.singleton Spend
          , argumentSchema = definitionRef @()
          }
    , -- No datum is inspected yet, so none is declared.
      validatorDatum = Nothing
    , validatorCompiled =
        Just
          ( compiledValidator
              PlutusV3
              (Short.fromShort (serialiseCompiledCode (compiledVerifier params)))
          )
    }

main :: IO ()
main =
  getArgs >>= \case
    [out, pkHex, dst] -> do
        pk <- case B16.decode (BS8.pack pkHex) of
            Left err -> fail ("public key: " <> err)
            Right bs
                | BS.length bs == 96 -> pure bs
                | otherwise -> fail ("public key must be 96 bytes, got" <> show (BS.length bs))
        let params = VrfParams
                { vpPubKey = toBuiltin pk
                , vpDst    = toBuiltin (BS8.pack dst)
                }
        writeBlueprint out (vrfContractBlueprint params)
    args -> fail $ "Usage: gen-blueprint <out.json> <pubkey-hex> <dst>, got " <> show (length args) <> " args"