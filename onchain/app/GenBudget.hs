-- | Budget verifier. Checks that:
--
-- 1. Does a proof produced by the Rust signer verify under the Plinth verifier (serialisation / DST agreement)
-- 2. What does the verification cost (execution budget)
--
-- Usage:
--
-- > cabal run gen-budget -- <pk-hex> <dst> <input-hex> <proof-hex>
--
--   pk-hex     96 bytes, compressed G2 public key
--   dst        hash-to-curve domain separation tag, as plain ASCII text
--   input-hex  the VRF input bytes that were signed
--   proof-hex  48 bytes, compressed G1 proof
module Main where

import Data.ByteString qualified as BS
import Data.ByteString.Base16 qualified as B16
import Data.ByteString.Char8 qualified as BS8
import Data.ByteString.Short qualified as Short
import Data.Text qualified as T
import PlutusLedgerApi.Common ( serialiseCompiledCode )
import PlutusTx.Builtins ( toBuiltin )
import PlutusTx.Code ( CompiledCode, unsafeApplyCode )
import PlutusTx.Eval ( EvalResult (..), evaluateCompiledCode )
import PlutusTx.Lift ( liftCodeDef )
import System.Environment ( getArgs )
import System.Exit ( exitFailure )
import VRF.Compiled ( compiledVerifier )
import VRF.Params ( VrfParams (..) )

-- | Apply the parameterised verifier to its two runtime arguments.
applied
  :: VrfParams
  -> BS.ByteString
  -> BS.ByteString
  -> CompiledCode Bool
applied params input proof =
  compiledVerifier params
    `unsafeApplyCode` liftCodeDef (toBuiltin input)
    `unsafeApplyCode` liftCodeDef (toBuiltin proof)

main :: IO ()
main =
  getArgs >>= \case
    [pkHex, dst, inputHex, proofHex] -> do
      pk <- orDie "public key" (B16.decode (BS8.pack pkHex))
      input <- orDie "input" (B16.decode (BS8.pack inputHex))
      proof <- orDie "proof" (B16.decode (BS8.pack proofHex))

      warnLength "public key" 96 pk
      warnLength "proof" 48 proof

      let params =
            VrfParams
              { vpPubKey = toBuiltin pk
              , vpDst = toBuiltin (BS8.pack dst)
              }
          scriptBytes = Short.fromShort (serialiseCompiledCode (compiledVerifier params))
          result = evaluateCompiledCode (applied params input proof)
          resultText = case evalResult result of
            Left err -> "EVALUATION FAILED\n" <> show err
            Right term -> show term

      putStrLn $ "dst:                   " <> show dst <> " (" <> show (length dst) <> " bytes)"
      putStrLn $ "unapplied script size: " <> show (BS.length scriptBytes) <> " bytes"
      putStrLn $ "budget:                " <> show (evalResultBudget result)
      putStrLn $ "result:                " <> resultText
      mapM_ (putStrLn . ("trace: " <>) . T.unpack) (evalResultTraces result)
    args ->
      die $
        "Usage: gen-budget <pk-hex> <dst> <input-hex> <proof-hex>\n"
          <> "  got "
          <> show (length args)
          <> " arguments"
  where
    orDie what = \case
      Left err -> die (what <> ": " <> err)
      Right v -> pure v

    warnLength what expected bs
      | BS.length bs == expected = pure ()
      | otherwise =
          putStrLn $
            "WARNING: "
              <> what
              <> " is "
              <> show (BS.length bs)
              <> " bytes, expected "
              <> show (expected :: Int)

    die msg = putStrLn ("error: " <> msg) >> exitFailure