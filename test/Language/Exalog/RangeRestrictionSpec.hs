module Language.Exalog.RangeRestrictionSpec (spec) where

import Protolude

import Test.Hspec

import qualified Fixture.DomainDependent as DDep

import Language.Exalog.Logger
import Language.Exalog.RangeRestriction

spec :: Spec
spec =
  describe "Range restriction" $ do
    it "programGood is range-restricted" $
      runLoggerT (checkRangeRestriction DDep.programGood) `shouldReturn` Just ()

    it "programBad1 violates range restriction" $
      runLoggerT (checkRangeRestriction DDep.programBad1) `shouldReturn` Nothing

    it "programBad2 violates range restriction" $
      runLoggerT (checkRangeRestriction DDep.programBad2) `shouldReturn` Nothing