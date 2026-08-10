-- | The only module containig a Plinth spliced compiled code.
--
-- Keeping @$$(compile ...)@ out of all other modules.
-- This is due to a broken RustRover Haskell LSP, that breaks diagnostics here.
module VRF.Compiled
    ( compiledVerifier
    ) where

import PlutusTx ( liftCodeDef, unsafeApplyCode )
import PlutusTx.Code ( CompiledCode )
import PlutusTx.Prelude ( BuiltinByteString )
import PlutusTx.Prelude qualified as PlutusTx
import PlutusTx.TH ( compile )
import VRF.Params ( VrfParams )
import VRF.Verify ( verifyVrfProof )

compiledVerifier
    :: VrfParams
    -> CompiledCode (BuiltinByteString -> BuiltinByteString -> PlutusTx.Bool)
compiledVerifier params =
    $$(compile [|| verifyVrfProof ||]) `unsafeApplyCode` liftCodeDef params