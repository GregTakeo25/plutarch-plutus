{-# LANGUAGE TemplateHaskell #-}

module Examples.LetRec (tests) where

import Plutarch (pcon', pmatch', printTerm, punsafeBuiltin, punsafeCoerce)
import Plutarch.Bool (PBool (PFalse, PTrue), pif, (#==))
import Plutarch.Builtin (PAsData, PBuiltinList (PNil), PData, PIsData, pasConstr, pdata, pforgetData, pfromData, pfstBuiltin, psndBuiltin)
import Plutarch.Integer (PInteger)
import Plutarch.List (phead, ptail)
import Plutarch.Prelude
import Plutarch.Rec (FieldsFromData, PRecord (PRecord), ScottEncoded, ScottEncoding, field, fieldFromData, letrec)
import Plutarch.Rec.TH (deriveAll)
import Plutarch.String (PString, pdecodeUtf8, pencodeUtf8)
import qualified PlutusCore as PLC
import qualified Rank2.TH
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Utils
import Prelude hiding (even, odd)

data SampleRecord f = SampleRecord
  { sampleBool :: f PBool
  , sampleInt :: f PInteger
  , sampleString :: f PString
  }

data EvenOdd f = EvenOdd
  { even :: f (PInteger :--> PBool)
  , odd :: f (PInteger :--> PBool)
  }

type instance ScottEncoded EvenOdd a = (PInteger :--> PBool) :--> (PInteger :--> PBool) :--> a

$(Rank2.TH.deriveAll ''EvenOdd)
$(deriveAll ''SampleRecord) -- also autoderives the @type instance ScottEncoded@
instance FieldsFromData SampleRecord

instance PIsData (PRecord SampleRecord) where
  pfromData = strictRecordFromData
  pdata = recordData

--recordData :: (forall t. Term s (ScottEncoding SampleRecord t)) -> Term s (PAsData (PRecord SampleRecord))
recordData :: forall s. Term s (PRecord SampleRecord) -> Term s (PAsData (PRecord SampleRecord))
recordData r = pmatch r $ \(PRecord SampleRecord{sampleBool, sampleInt, sampleString})->
  punsafeBuiltin PLC.ConstrData # (0 :: Term s PInteger) #$
  pconsBuiltin # pforgetData (pdata sampleBool) #$
  pconsBuiltin # pforgetData (pdata sampleInt) #$
  pconsBuiltin # pforgetData (pdata $ pencodeUtf8 # sampleString) #$
  pcon PNil

pconsBuiltin :: Term s (a :--> PBuiltinList a :--> PBuiltinList a)
pconsBuiltin = phoistAcyclic $ pforce $ punsafeBuiltin PLC.MkCons

strictRecordFromData :: Term s (PAsData (PRecord SampleRecord)) -> Term s (PRecord SampleRecord)
strictRecordFromData d =
  plet (pasConstr # pforgetData d) $ \constr ->
    pif
      (pfstBuiltin # constr #== 0)
      (fillInFields #$ psndBuiltin # constr)
      perror
  where
    fillInFields :: Term s (PBuiltinList PData :--> PRecord SampleRecord)
    fillInFields = plam $ \bis ->
      plet (phead # bis) $ \b ->
        plet (ptail # bis) $ \is ->
          plet (phead # is) $ \i ->
            plet (phead #$ ptail # is) $ \s ->
              pcon
                ( PRecord $
                    SampleRecord
                      (pfromData $ punsafeCoerce b)
                      (pfromData $ punsafeCoerce i)
                      (pdecodeUtf8 #$ pfromData $ punsafeCoerce s)
                )

sampleRecord :: Term (s :: S) (ScottEncoding SampleRecord (t :: PType))
sampleRecord =
  pcon' $
    PRecord
      SampleRecord
        { sampleBool = pcon PFalse
        , sampleInt = 6
        , sampleString = "Salut, Monde!"
        }

sampleRecur :: Term (s :: S) (ScottEncoding SampleRecord (t :: PType))
sampleRecur =
  letrec $
    const
      SampleRecord
        { sampleBool = pcon PTrue
        , sampleInt = 12
        , sampleString = "Hello, World!"
        }

evenOdd :: Term (s :: S) (ScottEncoding EvenOdd (t :: PType))
evenOdd = letrec evenOddRecursion
  where
    evenOddRecursion :: EvenOdd (Term s) -> EvenOdd (Term s)
    evenOddRecursion EvenOdd {even, odd} =
      EvenOdd
        { even = plam $ \n -> pif (n #== 0) (pcon PTrue) (odd #$ n - 1)
        , odd = plam $ \n -> pif (n #== 0) (pcon PFalse) (even #$ n - 1)
        }

sampleData :: Term s (PAsData (PRecord SampleRecord))
sampleData = pdata (punsafeCoerce sampleRecord)

tests :: HasTester => TestTree
tests =
  testGroup
    "Records"
    [ testGroup
        "Simple"
        [ testCase "record construction" $
            printTerm (sampleRecord # field sampleInt)
              @?= "(program 1.0.0 ((\\i0 -> i1 False 6 \"Salut, Monde!\") (\\i0 -> \\i0 -> \\i0 -> i2)))"
        , testCase "record field" $
            equal' (sampleRecord # field sampleInt) "(program 1.0.0 6)"
        , testCase "record match" $
            equal' (pmatch' sampleRecord $ \(PRecord r) -> sampleString r) "(program 1.0.0 \"Salut, Monde!\")"
        ]
    , testGroup
        "Letrec"
        [ testCase "record" $ (printTerm $ sampleRecur # field sampleInt) @?= "(program 1.0.0 ((\\i0 -> (\\i0 -> i2 (\\i0 -> i2 i2 i1)) (\\i0 -> i2 (\\i0 -> i2 i2 i1))) (\\i0 -> \\i0 -> i1 True 12 \"Hello, World!\") (\\i0 -> \\i0 -> \\i0 -> i2)))"
        , testCase "record field" $ equal' (sampleRecur # field sampleInt) "(program 1.0.0 12)"
        , testCase "even" $ (printTerm $ evenOdd # field even) @?= "(program 1.0.0 ((\\i0 -> (\\i0 -> (\\i0 -> (\\i0 -> i2 (\\i0 -> i2 i2 i1)) (\\i0 -> i2 (\\i0 -> i2 i2 i1))) (\\i0 -> \\i0 -> i1 (\\i0 -> force (i4 (equalsInteger i1 0) (delay True) (delay (i3 (\\i0 -> \\i0 -> i1) (subtractInteger i1 1))))) (\\i0 -> force (i4 (equalsInteger i1 0) (delay False) (delay (i3 i5 (subtractInteger i1 1)))))) i2) (force ifThenElse)) (\\i0 -> \\i0 -> i2)))"
        , testCase "even 4" $ equal' (evenOdd # field even # (4 :: Term s PInteger)) "(program 1.0.0 True)"
        , testCase "even 5" $ equal' (evenOdd # field even # (5 :: Term s PInteger)) "(program 1.0.0 False)"
        ]
    , testGroup
        "Data"
        [ testCase "pdata" $ printTerm sampleData @?= "(program 1.0.0 ((\\i0 -> i1 False 6 \"Salut, Monde!\") (\\i0 -> \\i0 -> \\i0 -> constrData 0 (force mkCons ((\\i0 -> constrData (force ifThenElse i1 1 0) [  ]) i3) (force mkCons (iData i2) (force mkCons (bData (encodeUtf8 i1)) [  ]))))))"
        , testCase "fieldFromData term" $ (printTerm $ plam $ \dat-> plam pfromData #$ fieldFromData sampleInt # dat) @?= "(program 1.0.0 (\\i0 -> unIData ((\\i0 -> (\\i0 -> force (force ifThenElse (equalsInteger (force (force fstPair) i1) 0) (delay (force headList (force tailList (force (force sndPair) i1)))) (delay error))) (unConstrData i1)) i1)))"
        , testCase "fieldFromData value" $ equal' (fieldFromData sampleInt # sampleData) "(program 1.0.0 #06)"
        ]
    ]
