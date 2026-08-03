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

import AlwaysTrue

import Data.ByteString.Short qualified as Short
import Data.Set qualified as Set
import PlutusLedgerApi.Common (serialiseCompiledCode)
import PlutusTx.Blueprint
import System.Environment (getArgs)

alwaysTrueContractBlueprint :: ContractBlueprint
alwaysTrueContractBlueprint =
  MkContractBlueprint
    { contractId = Just "always-true"
    , contractPreamble = alwaysTruePreamble
    , contractValidators = Set.singleton alwaysTrueValidatorBlueprint
    , -- '()' is listed because the redeemer schema references it. Omit it and
      -- the blueprint contains a "$ref" pointing at nothing; the type checker
      -- does not catch that.
      contractDefinitions = deriveDefinitions @'[()]
    }

alwaysTruePreamble :: Preamble
alwaysTruePreamble =
  MkPreamble
    { preambleTitle = "Always True"
    , preambleDescription = Just "A validator that accepts every transaction"
    , preambleVersion = "1.0.0"
    , preamblePlutusVersion = PlutusV3
    , preambleLicense = Just "MIT"
    }

alwaysTrueValidatorBlueprint :: ValidatorBlueprint referencedTypes
alwaysTrueValidatorBlueprint =
  MkValidatorBlueprint
    { validatorTitle = "Always True"
    , validatorDescription = Just "Succeeds unconditionally"
    , validatorParameters = []
    , validatorRedeemer =
        MkArgumentBlueprint
          { argumentTitle = Just "Redeemer"
          , argumentDescription = Just "Ignored"
          , argumentPurpose = Set.singleton Spend
          , argumentSchema = definitionRef @()
          }
    , -- The validator inspects no datum, so it declares none.
      validatorDatum = Nothing
    , validatorCompiled =
        Just
          ( compiledValidator
              PlutusV3
              (Short.fromShort (serialiseCompiledCode alwaysTrueScript))
          )
    }

main :: IO ()
main =
  getArgs >>= \case
    [out] -> writeBlueprint out alwaysTrueContractBlueprint
    args -> fail $ "Expects one output path, got " <> show (length args)
