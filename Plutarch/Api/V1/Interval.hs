{-# LANGUAGE UndecidableInstances #-}

module Plutarch.Api.V1.Interval (
  PInterval (PInterval),
  PLowerBound (PLowerBound),
  PUpperBound (PUpperBound),
  PExtended (PFinite, PPosInf, PNegInf),
  type PClosure,
) where

import qualified GHC.Generics as GHC
import Generics.SOP (Generic)

import Plutarch.DataRepr (
  PDataFields,
  PIsDataReprInstances (PIsDataReprInstances),
  PLabeledType ((:=)),
 )
import Plutarch.Prelude

type PClosure = PBool

newtype PInterval a (s :: S)
  = PInterval
      ( Term
          s
          ( PDataRecord
              '[ "from" ':= PLowerBound a
               , "to" ':= PUpperBound a
               ]
          )
      )
  deriving stock (GHC.Generic)
  deriving anyclass (Generic)
  deriving anyclass (PIsDataRepr)
  deriving
    (PMatch, PIsData, PDataFields)
    via PIsDataReprInstances (PInterval a)

newtype PLowerBound a (s :: S)
  = PLowerBound
      ( Term
          s
          ( PDataRecord
              '[ "_0" ':= PExtended a
               , "_1" ':= PClosure
               ]
          )
      )
  deriving stock (GHC.Generic)
  deriving anyclass (Generic)
  deriving anyclass (PIsDataRepr)
  deriving
    (PMatch, PIsData, PDataFields)
    via (PIsDataReprInstances (PLowerBound a))

newtype PUpperBound a (s :: S)
  = PUpperBound
      ( Term
          s
          ( PDataRecord
              '[ "_0" ':= PExtended a
               , "_1" ':= PClosure
               ]
          )
      )
  deriving stock (GHC.Generic)
  deriving anyclass (Generic)
  deriving anyclass (PIsDataRepr)
  deriving
    (PMatch, PIsData, PDataFields)
    via (PIsDataReprInstances (PUpperBound a))

data PExtended a (s :: S)
  = PNegInf (Term s (PDataRecord '[]))
  | PFinite (Term s (PDataRecord '["_0" ':= a]))
  | PPosInf (Term s (PDataRecord '[]))
  deriving stock (GHC.Generic)
  deriving anyclass (Generic)
  deriving anyclass (PIsDataRepr)
  deriving
    (PMatch, PIsData)
    via (PIsDataReprInstances (PExtended a))
