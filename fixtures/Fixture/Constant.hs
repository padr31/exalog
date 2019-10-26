{-# LANGUAGE DataKinds #-}

module Fixture.Constant
  ( program
  , initEDB
  , rPred
  , rTuples
  ) where

import Protolude

import           Data.Maybe (fromJust)

import qualified Data.List.NonEmpty as NE
import qualified Data.Vector.Sized as V
import           Data.Singletons.TypeLits

import           Language.Exalog.Core
import qualified Language.Exalog.Tuples as T
import           Language.Exalog.Relation
import           Language.Exalog.SrcLoc

import Fixture.Util

cPred, rPred :: Predicate 2 'ABase
cPred = Predicate (PredABase dummySpan) "c" SNat Logical
rPred = Predicate (PredABase dummySpan) "r" SNat Logical

c,r :: Term -> Term -> Literal 'ABase
c t t' = lit cPred $ fromJust $ V.fromList [ t, t' ]
r t t' = lit rPred $ fromJust $ V.fromList [ t, t' ]

{-
- r("c","1") :- c("a","b").
- r(X  ,"2") :- c("a",X).
- r("c","3") :- c("q","b").
- r("e","4") :- r(X,Y), c("a",X).
- r("f","5") :- c("a",X), r(X,Y).
-}
program :: Program 'ABase
program = Program (ProgABase dummySpan)
  (Stratum <$>
    [ [ Clause (ClABase dummySpan) (r (tsym ("c" :: Text)) (tsym ("1" :: Text))) $ NE.fromList [ c (tsym ("a" :: Text)) (tsym ("b" :: Text)) ]
      , Clause (ClABase dummySpan) (r (tvar "X") (tsym ("2" :: Text))) $ NE.fromList [ c (tsym ("a" :: Text)) (tvar "X") ]
      , Clause (ClABase dummySpan) (r (tsym ("c" :: Text)) (tsym ("3" :: Text))) $ NE.fromList [ c (tsym ("q" :: Text)) (tsym ("b" :: Text)) ]
      , Clause (ClABase dummySpan) (r (tsym ("e" :: Text)) (tsym ("4" :: Text))) $ NE.fromList
        [ r (tvar "X") (tvar "Y")
        , c (tsym ("a" :: Text)) (tvar "X") ]
      , Clause (ClABase dummySpan) (r (tsym ("f" :: Text)) (tsym ("5" :: Text))) $ NE.fromList
        [ c (tsym ("a" :: Text)) (tvar "X")
        , r (tvar "X") (tvar "Y") ]
      ]
    ])
  [ PredicateBox rPred ]

cTuples :: [ V.Vector 2 Text ]
cTuples = fromJust . V.fromList <$>
  [ [ "a"     , "b" ]
  , [ "a"     , "c" ]
  , [ "a"     , "d" ]
  ]

cRel :: Relation 'ABase
cRel = Relation cPred . T.fromList $ fmap symbol <$> cTuples

initEDB :: Solution 'ABase
initEDB = fromList [ cRel ]

rTuples :: T.Tuples 2
rTuples = T.fromList $ fmap symbol . fromJust . V.fromList <$>
  ([ [ "c", "1" ]
  , [ "b", "2" ]
  , [ "c", "2" ]
  , [ "d", "2" ]
  , [ "e", "4" ]
  , [ "f", "5" ]
  ] :: [ [ Text ] ])