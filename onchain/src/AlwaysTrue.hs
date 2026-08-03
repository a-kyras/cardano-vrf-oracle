-- | The simplest possible Plutus V3 spending validator: it always succeeds.
--
-- A V3 validator takes one argument (the @BuiltinData@-encoded @ScriptContext@)
-- and succeeds by *not* failing. This one ignores its argument entirely, so it
-- exercises the whole toolchain — GHC 9.6.6, the plugin, UPLC serialisation —
-- without any logic to get wrong.
module AlwaysTrue where

import PlutusTx
import PlutusTx.Prelude qualified as PlutusTx

{-# INLINEABLE alwaysTrueValidator #-}
alwaysTrueValidator :: BuiltinData -> PlutusTx.BuiltinUnit
alwaysTrueValidator _ctx = PlutusTx.check PlutusTx.True

-- | Hand the above to the plugin. This splice is the actual test of the setup.
alwaysTrueScript :: CompiledCode (BuiltinData -> PlutusTx.BuiltinUnit)
alwaysTrueScript = $$(PlutusTx.compile [||alwaysTrueValidator||])
