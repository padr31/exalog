{-# LANGUAGE DataKinds #-}

module Language.Exalog.RangeRestrictionSpec (spec) where

import Protolude

import Test.Hspec

import qualified Fixture.RangeRestriction as RRes
import qualified Fixture.DomainDependent as DDep

import           Language.Exalog.Annotation
import qualified Language.Exalog.KnowledgeBase.Set as KB
import           Language.Exalog.Logger
import           Language.Exalog.RangeRestriction

spec :: Spec
spec =
  describe "Range restriction" $ do
    parallel $ describe "Checking" $ do
      it "programGood is range-restricted" $
        runLoggerT vanillaEnv (checkRangeRestriction DDep.programGood) `shouldReturn` Just ()

      it "programBad1 violates range restriction" $
        runLoggerT vanillaEnv (checkRangeRestriction DDep.programBad1) `shouldReturn` Nothing

      it "programBad2 violates range restriction" $
        runLoggerT vanillaEnv (checkRangeRestriction DDep.programBad2) `shouldReturn` Nothing

    describe "Repair" $
      it "programSimple can be repaired" $ do
        let input = (RRes.prSimple, mempty :: KB.Set ('ARename 'ABase))
        let output = (RRes.prSimpleRepaired, mempty :: KB.Set 'ABase)
        runLoggerT vanillaEnv (fixRangeRestriction input) `shouldReturn` Just output
