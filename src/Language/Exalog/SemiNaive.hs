{-# LANGUAGE DataKinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ExistentialQuantification #-}

module Language.Exalog.SemiNaive
  ( semiNaive
  , SemiNaive
  , evalSemiNaiveT
  , evalClauses
  ) where

import Protolude hiding (head, pred, sym)

import Control.Monad.Trans.Reader (ReaderT)

import qualified Data.List.NonEmpty as NE
import           Data.Maybe (mapMaybe, catMaybes)
import qualified Data.Vector.Sized as V

import           Language.Exalog.Core
import           Language.Exalog.Delta
import           Language.Exalog.Logger
import qualified Language.Exalog.Tuples as T
import qualified Language.Exalog.Relation as R
import           Language.Exalog.SrcLoc (Spannable(..))
import qualified Language.Exalog.Unification as U

type SemiNaiveT ann = ReaderT (R.Solution ann)
type SemiNaive  ann = SemiNaiveT ann (LoggerT IO)

evalSemiNaiveT :: SemiNaiveT ann m a -> R.Solution ann -> m a
evalSemiNaiveT = runReaderT

semiNaive :: forall a b. (SpannableAST a, Identifiable (PredicateAnn a) b)
          => Stratum ('ADelta a)
          -> SemiNaive ('ADelta a) (R.Solution ('ADelta a))
semiNaive stratum@(Stratum clss) = do
  initEDB <- ask

  (`fix` initEDB) $ \f edb -> do
    betterEDB <- local (const edb) step
    if areAllDeltaEmpty betterEDB
      then return betterEDB
      else f betterEDB
  where
  intentionalPreds :: [ PredicateBox a ]
  intentionalPreds = map peel $ intentionals stratum

  areAllDeltaEmpty :: R.Solution ('ADelta a) -> Bool
  areAllDeltaEmpty =
      R.isEmpty
    . R.filter (\(R.Relation p ts) -> decor p == Delta && (not . T.isEmpty) ts)

  -- Adds the current deltas to the normal version of the relation.
  -- Basicall S_{i+1} = S_i \cup delta S_i
  updateFromDelta :: R.Solution ('ADelta a) -> R.Solution ('ADelta a)
  updateFromDelta edb = foldr' updateFromDelta' edb intentionalPreds

  updateFromDelta' :: PredicateBox a
                   -> R.Solution ('ADelta a)
                   -> R.Solution ('ADelta a)
  updateFromDelta' (PredicateBox p) edb =
    let ts = R.findTuples (mkDeltaPredicate Delta p) edb
        tsPrev = R.findTuples (mkDeltaPredicate Prev p) edb
    in R.add (R.Relation (mkDeltaPredicate Current p) (ts <> tsPrev)) edb

  -- Sets Prev to PrevX2, Current to Prev
  shiftPrevs :: R.Solution ('ADelta a) -> R.Solution ('ADelta a)
  shiftPrevs edb = (`R.rename` edb) $ \p ->
    -- This is stupidly inefficient
    if PredicateBox (peel p) `elem` intentionalPreds
      then
        case decor p of
          Current -> updateDecor Prev   p
          Prev    -> updateDecor PrevX2 p
          _       -> p
      else
        p

  axeDeltaRedundancies :: R.Solution ('ADelta a) -> R.Solution ('ADelta a)
  axeDeltaRedundancies edb = (`R.atEach` edb) $ \(p, ts) ->
    case decor p of
      Delta -> ts `T.difference` R.findTuples (updateDecor Current p) edb
      _ -> ts

  step :: SemiNaive ('ADelta a) (R.Solution ('ADelta a))
  step = do
    let evalClauses' = evalClauses clss
    let maintenance = updateFromDelta . shiftPrevs . elimDecor PrevX2
    axeDeltaRedundancies <$> local maintenance evalClauses'

evalClauses :: (SpannableAST a, Identifiable (PredicateAnn a) b)
            => [ Clause a ] -> SemiNaive a (R.Solution a)
evalClauses clss = do
  rels <- mapM evalClause clss
  edb <- ask
  return $ foldr' R.add edb rels

evalClause :: forall a b. (SpannableAST a, Identifiable (PredicateAnn a) b)
           => Clause a -> SemiNaive a (R.Relation a)
evalClause cl@Clause{..} = deriveHead =<< foldM walkBody [ U.empty ] body
  where
  deriveHead :: [ U.Unifier ] -> SemiNaive a (R.Relation a)
  deriveHead unifiers
    | Literal{predicate = pred, terms = terms} <- head = do
      let preTuples = map (`U.substitute` terms) unifiers
      tuples <- lift $ traverse extractHeadTuple preTuples
      pure $ R.Relation pred . T.fromList $ tuples

  walkBody :: [ U.Unifier ] -> Literal a -> SemiNaive a [ U.Unifier ]
  walkBody unifiers lit = fmap (catMaybes . concat) $ sequence $ do
    unifier <- unifiers
    return $ fmap (`U.extend` unifier)
         <$> execLiteral (unifier `U.substitute` lit)

  extractHeadTuple :: V.Vector n Term -> Logger (V.Vector n Sym)
  extractHeadTuple = traverse (\case
    TSym sym -> pure sym
    TVar{}   -> scream (Just $ span cl) "Range-restriction is violated"
    TWild    -> scream (Just $ span cl) "Head contains a wildcard")

execLiteral :: (SpannableAST a, Identifiable (PredicateAnn a) b)
            => Literal a -> SemiNaive a [ U.Unifier ]
execLiteral lit@Literal{predicate = p@Predicate{nature = nature}, ..}
  | Extralogical foreignAction <- nature = do
    eTuples <- liftIO $ foreignAction terms
    case eTuples of
      Right tuples -> return $ handleTuples terms tuples
      Left msg -> lift $ scold (Just (span lit)) $
        "Fatal foreign function error: " <> msg
  | otherwise =
    handleTuples terms . T.toList . R.findTuples p <$> ask
  where
  handleTuples :: V.Vector n Term -> [ V.Vector n Sym ] -> [ U.Unifier ]
  handleTuples terms tuples =
    case polarity of
      Positive -> tuplesToUnifiers terms tuples
      Negative -> [ U.empty | null (tuplesToUnifiers terms tuples) ]

  tuplesToUnifiers :: V.Vector n Term -> [ V.Vector n Sym ] -> [ U.Unifier ]
  tuplesToUnifiers terms = mapMaybe (U.unify terms)
