{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE AllowAmbiguousTypes #-}

module Language.Exalog.Annotation
  ( AnnType(..)
  , PredicateAnn(..)
  , LiteralAnn(..)
  , ClauseAnn(..)
  , ProgramAnn(..)
  , type Ann
  , PeelableAnn(..)
  , DecorableAnn(..)
  ) where

import Protolude

import Language.Exalog.SrcLoc

data AnnType = ABase | ADelta AnnType | ADependency AnnType

data family PredicateAnn (a :: AnnType)
data instance PredicateAnn 'ABase = PredABase SrcSpan deriving (Eq, Ord, Show)

data family LiteralAnn (a :: AnnType)
data instance LiteralAnn   'ABase = LitABase  SrcSpan deriving (Eq, Ord, Show)

data family ClauseAnn  (a :: AnnType)
data instance ClauseAnn    'ABase = ClABase   SrcSpan deriving (Eq, Ord, Show)

data family ProgramAnn (a :: AnnType)
data instance ProgramAnn   'ABase = ProgABase SrcSpan deriving (Eq, Ord, Show)

type family Ann (a :: AnnType -> Type) :: (AnnType -> Type)

class PeelableAnn (f :: AnnType -> Type) (ann :: AnnType -> AnnType) where
  peelA :: f (ann a) -> f a

class DecorableAnn (f :: AnnType -> Type) (ann :: AnnType -> AnnType) where
  decorA :: f a -> f (ann a)
