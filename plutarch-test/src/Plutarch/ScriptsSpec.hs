module Plutarch.ScriptsSpec (
  authorizedValidator,
  authorizedPolicy,
  authorizedStakeValidator,
  authValidatorCompiled,
  validatorEncoded,
  validatorHashEncoded,
  authValidatorHash,
  authStakeValidatorCompiled,
  stakeValidatorEncoded,
  authStakeValidatorHash,
  stakeValidatorHashEncoded,
  authPolicyCompiled,
  policyEncoded,
  policySymEncoded,
  authPolicySymbol,
  spec,
) where

import System.FilePath ((</>))

import Data.Text (Text)

import Data.Aeson.Extras (encodeSerialise)
import qualified Plutus.V1.Ledger.Api as Plutus
import qualified Plutus.V1.Ledger.Crypto as Plutus

import Plutarch (ClosedTerm, POpaque, popaque)
import Plutarch.Api.V1 (
  PScriptContext,
  mintingPolicySymbol,
  mkMintingPolicy,
  mkStakeValidator,
  mkValidator,
  stakeValidatorHash,
  validatorHash,
  type PMintingPolicy,
  type PStakeValidator,
  type PValidator,
 )
import Plutarch.Api.V1.Crypto (PPubKey, PPubKeyHash, PSignature (PSignature))
import Plutarch.Builtin (pasByteStr)
import Plutarch.Prelude
import Plutarch.Test (PlutarchGolden (PrintTerm), golden)
import Test.Syd (Spec, describe, it, pureGoldenTextFile)

spec :: Spec
spec = do
  describe "Scripts API" $ do
    describe "auth validator" $ do
      golden PrintTerm authValidatorTerm
      it "serialization" $
        pureGoldenTextFile
          ("goldens" </> "authValidator.plutus.golden")
          validatorEncoded
      it "hash" $
        pureGoldenTextFile
          ("goldens" </> "authValidator.hash.golden")
          validatorHashEncoded
    describe "auth policy" $ do
      golden PrintTerm authPolicyTerm
      it "serialization" $
        pureGoldenTextFile
          ("goldens" </> "authPolicy.plutus.golden")
          policyEncoded
      it "hash" $
        pureGoldenTextFile
          ("goldens" </> "authPolicy.hash.golden")
          policySymEncoded
    describe "auth stake validator" $ do
      golden PrintTerm authStakeValidatorTerm
      it "serialization" $
        pureGoldenTextFile
          ("goldens" </> "authStakeValidator.plutus.golden")
          stakeValidatorEncoded
      it "hash" $
        pureGoldenTextFile
          ("goldens" </> "authStakeValidator.hash.golden")
          stakeValidatorHashEncoded

{- |
  A parameterized Validator which may be unlocked
    by signing the Datum Message with the parameter PubKey.
-}
authorizedValidator ::
  ClosedTerm PPubKey ->
  Term s PByteString ->
  Term s PSignature ->
  Term s PScriptContext ->
  Term s POpaque
authorizedValidator authKey datumMessage redeemerSig _ctx =
  pif
    (pverifySignature # pto authKey # datumMessage # pto redeemerSig)
    (popaque $ pcon PUnit)
    perror

{- |
  A parameterized MintingPolicy which allows minting if
   the parameter PubKeyHash signs the transaction.
-}
authorizedPolicy ::
  forall s.
  ClosedTerm (PAsData PPubKeyHash) ->
  Term s PData ->
  Term s PScriptContext ->
  Term s POpaque
authorizedPolicy authHash _redeemer ctx =
  let sigs :: Term s (PBuiltinList (PAsData PPubKeyHash))
      sigs = pfromData (pfield @"signatories" #$ pfield @"txInfo" # ctx)
   in pif
        (pelem # authHash # sigs)
        (popaque $ pcon PUnit)
        perror

{- |
  A parameterized StakeValidator which allows any StakeValidator action
  if the parameter PubKeyHash signs the transaction.
-}
authorizedStakeValidator ::
  forall s.
  ClosedTerm (PAsData PPubKeyHash) ->
  Term s PData ->
  Term s PScriptContext ->
  Term s POpaque
authorizedStakeValidator authHash _redeemer ctx =
  let sigs :: Term s (PBuiltinList (PAsData PPubKeyHash))
      sigs = pfromData (pfield @"signatories" #$ pfield @"txInfo" # ctx)
   in pif
        (pelem # authHash # sigs)
        (popaque $ pcon PUnit)
        perror

adminPubKey :: Plutus.PubKey
adminPubKey = "11661a8aca9b09bb93eefda295b5da2be3f944d1f4253ab29da17db580f50d02d26218e33fbba5e0cc1b0c0cadfb67a5f9a90157dcc19eecd7c9373b0415c888"

adminPubKeyHash :: Plutus.PubKeyHash
adminPubKeyHash = "cc1360b04bdd0825e0c6552abb2af9b4df75b71f0c7cca20256b1f4f"

{- |
  We can compile a `Validator` using `mkValidator` &
  `pwrapValidatorFromData`
-}
authValidatorCompiled :: Plutus.Validator
authValidatorCompiled =
  mkValidator authValidatorTerm

authValidatorTerm :: ClosedTerm PValidator
authValidatorTerm =
  plam $ \datum redeemer ctx ->
    authorizedValidator
      (pconstant adminPubKey)
      (pasByteStr # datum)
      (pcon $ PSignature $ pasByteStr # redeemer)
      ctx

-- | `validatorHash` gets the Plutus `ValidatorHash`
authValidatorHash :: Plutus.ValidatorHash
authValidatorHash = validatorHash authValidatorCompiled

-- | Similarly, for a MintingPolicy
authPolicyCompiled :: Plutus.MintingPolicy
authPolicyCompiled =
  mkMintingPolicy authPolicyTerm

authPolicyTerm :: ClosedTerm PMintingPolicy
authPolicyTerm =
  plam $ \redeemer ctx ->
    authorizedPolicy
      (pconstantData adminPubKeyHash)
      redeemer
      ctx

-- | `mintingPolicySymbol` gets the Plutus `CurrencySymbol`
authPolicySymbol :: Plutus.CurrencySymbol
authPolicySymbol =
  mintingPolicySymbol authPolicyCompiled

-- | ...And for a StakeValidator
authStakeValidatorCompiled :: Plutus.StakeValidator
authStakeValidatorCompiled =
  mkStakeValidator authStakeValidatorTerm

authStakeValidatorTerm :: ClosedTerm PStakeValidator
authStakeValidatorTerm =
  plam $ \redeemer ctx ->
    authorizedStakeValidator
      (pconstantData adminPubKeyHash)
      redeemer
      ctx

-- | `stakeValidatorHash` gets the Plutus `StakeValidatorHash`
authStakeValidatorHash :: Plutus.StakeValidatorHash
authStakeValidatorHash = stakeValidatorHash authStakeValidatorCompiled

-- | `encodeSerialise` will get the hex-encoded serialisation of a script
validatorEncoded :: Text
validatorEncoded = encodeSerialise authValidatorCompiled

-- | Similarly, with a `MintingPolicy`
policyEncoded :: Text
policyEncoded = encodeSerialise authPolicyCompiled

-- | And with a `StakeValidator`
stakeValidatorEncoded :: Text
stakeValidatorEncoded = encodeSerialise authStakeValidatorCompiled

{- |
  We can also encode `ValidatorHash` the same way.

  NB:
  The serialisation from Codec.Serialise will prepend a 4-hexit prefix,
  tagging the type, so this will differ slightly from the encoding
  of the `Show` & `IsString` instances.
  Also note that this is not the addr1/CIP-0019 Address encoding of the script.
-}
validatorHashEncoded :: Text
validatorHashEncoded = encodeSerialise authValidatorHash

-- | The same goes for `CurrencySymbol`
policySymEncoded :: Text
policySymEncoded = encodeSerialise authPolicySymbol

-- | ... And `StakeValidatorHash`
stakeValidatorHashEncoded :: Text
stakeValidatorHashEncoded = encodeSerialise authStakeValidatorHash