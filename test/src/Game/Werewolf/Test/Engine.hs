{-|
Module      : Game.Werewolf.Test.Engine
Copyright   : (c) Henry J. Wylde, 2016
License     : BSD3
Maintainer  : public@hjwylde.com
-}

{-# OPTIONS_HADDOCK hide, prune #-}
{-# LANGUAGE OverloadedStrings #-}

module Game.Werewolf.Test.Engine (
    -- * Tests
    allEngineTests,
) where

import Control.Lens         hiding (elements)
import Control.Monad.Except
import Control.Monad.Writer

import           Data.Either.Extra
import           Data.List.Extra
import qualified Data.Map          as Map
import           Data.Maybe
import           Data.Text         (Text)

import           Game.Werewolf.Command
import           Game.Werewolf.Engine          hiding (doesPlayerExist, getDevourEvent,
                                                getVoteResult, isDefendersTurn, isGameOver,
                                                isScapegoatsTurn, isSeersTurn, isVillagesTurn,
                                                isWerewolvesTurn, isWildChildsTurn, isWitchsTurn,
                                                isWolfHoundsTurn, killPlayer)
import           Game.Werewolf.Internal.Game
import           Game.Werewolf.Internal.Player
import           Game.Werewolf.Internal.Role   hiding (angel, name, werewolf)
import qualified Game.Werewolf.Internal.Role   as Role
import           Game.Werewolf.Test.Arbitrary
import           Game.Werewolf.Test.Util

import Prelude hiding (round)

import Test.QuickCheck
import Test.QuickCheck.Monadic
import Test.Tasty
import Test.Tasty.QuickCheck

allEngineTests :: [TestTree]
allEngineTests =
    [ testProperty "check stage skips defender's turn when no defender"         prop_checkStageSkipsDefendersTurnWhenNoDefender
    , testProperty "check stage skips scapegoat's turn when no seer"            prop_checkStageSkipsScapegoatsTurnWhenNoScapegoat
    , testProperty "check stage skips seer's turn when no seer"                 prop_checkStageSkipsSeersTurnWhenNoSeer
    , testProperty "check stage skips village's turn when allowed voters empty" prop_checkStageSkipsVillagesTurnWhenAllowedVotersEmpty
    , testProperty "check stage skips wild-child's turn when no wild-child"     prop_checkStageSkipsWildChildsTurnWhenNoWildChild
    , testProperty "check stage skips witch's turn when no witch"               prop_checkStageSkipsWitchsTurnWhenNoWitch
    , testProperty "check stage skips wolf-hound's turn when no wolf-hound"     prop_checkStageSkipsWolfHoundsTurnWhenNoWolfHound
    , testProperty "check stage does nothing when game over"                    prop_checkStageDoesNothingWhenGameOver

    , testProperty "check defender's turn advances to wolf-hound's turn"    prop_checkDefendersTurnAdvancesToWolfHoundsTurn
    , testProperty "check defender's turn advances when no defender"        prop_checkDefendersTurnAdvancesWhenNoDefender
    , testProperty "check defender's turn does nothing unless protected"    prop_checkDefendersTurnDoesNothingUnlessProtected

    , testProperty "check scapegoat's turn advances to seer's turn"             prop_checkScapegoatsTurnAdvancesToSeersTurn
    , testProperty "check scapegoat's turn does nothing while scapegoat blamed" prop_checkScapegoatsTurnDoesNothingWhileScapegoatBlamed

    , testProperty "check seer's turn advances to wild-child's turn"    prop_checkSeersTurnAdvancesToWildChildsTurn
    , testProperty "check seer's turn advances when no seer"            prop_checkSeersTurnAdvancesWhenNoSeer
    , testProperty "check seer's turn resets sees"                      prop_checkSeersTurnResetsSee
    , testProperty "check seer's turn does nothing unless seen"         prop_checkSeersTurnDoesNothingUnlessSeen

    , testProperty "check sunrise increments round"     prop_checkSunriseIncrementsRound
    , testProperty "check sunrise sets angel's role"    prop_checkSunriseSetsAngelsRole

    , testProperty "check sunset sets wild-child's allegiance when role model dead" prop_checkSunsetSetsWildChildsAllegianceWhenRoleModelDead

    , testProperty "check villages' turn advances to scapegoat's turn"                      prop_checkVillagesTurnAdvancesToScapegoatsTurn
    , testProperty "check villages' turn lynches one player when consensus"                 prop_checkVillagesTurnLynchesOnePlayerWhenConsensus
    , testProperty "check villages' turn lynches no one when target is village idiot"       prop_checkVillagesTurnLynchesNoOneWhenTargetIsVillageIdiot
    , testProperty "check villages' turn lynches no one when conflicted and no scapegoats"  prop_checkVillagesTurnLynchesNoOneWhenConflictedAndNoScapegoats
    , testProperty "check villages' turn lynches scapegoat when conflicted"                 prop_checkVillagesTurnLynchesScapegoatWhenConflicted
    , testProperty "check villages' turn resets votes"                                      prop_checkVillagesTurnResetsVotes
    , testProperty "check villages' turn sets allowed voters"                               prop_checkVillagesTurnSetsAllowedVoters
    , testProperty "check villages' turn does nothing unless all voted"                     prop_checkVillagesTurnDoesNothingUnlessAllVoted

    , testProperty "check werewolves' turn advances to witch's turn"                    prop_checkWerewolvesTurnAdvancesToWitchsTurn
    , testProperty "check werewolves' turn skips witch's turn when healed and poisoned" prop_checkWerewolvesTurnSkipsWitchsTurnWhenHealedAndPoisoned
    , testProperty "check werewolves' turn kills one player when consensus"             prop_checkWerewolvesTurnKillsOnePlayerWhenConsensus
    , testProperty "check werewolves' turn kills no one when conflicted"                prop_checkWerewolvesTurnKillsNoOneWhenConflicted
    , testProperty "check werewolves' turn kills no one when target defended"           prop_checkWerewolvesTurnKillsNoOneWhenTargetDefended
    , testProperty "check werewolves' turn resets protect"                              prop_checkWerewolvesTurnResetsProtect
    , testProperty "check werewolves' turn resets votes"                                prop_checkWerewolvesTurnResetsVotes
    , testProperty "check werewolves' turn does nothing unless all voted"               prop_checkWerewolvesTurnDoesNothingUnlessAllVoted

    , testProperty "check wild-child's turn advances to defender's turn"    prop_checkWildChildsTurnAdvancesToDefendersTurn
    , testProperty "check wild-child's turn advances when no wild-child"    prop_checkWildChildsTurnAdvancesWhenNoWildChild
    , testProperty "check wild-child's turn does nothing unless chosen"     prop_checkWildChildsTurnDoesNothingUnlessRoleModelChosen

    , testProperty "check witch's turn advances to villages' turn"              prop_checkWitchsTurnAdvancesToVillagesTurn
    , testProperty "check witch's turn advances when no witch"                  prop_checkWitchsTurnAdvancesWhenNoWitch
    , testProperty "check witch's turn heals devouree when healed"              prop_checkWitchsTurnHealsDevoureeWhenHealed
    , testProperty "check witch's turn kills one player when poisoned"          prop_checkWitchsTurnKillsOnePlayerWhenPoisoned
    , testProperty "check witch's turn does nothing when passed"                prop_checkWitchsTurnDoesNothingWhenPassed
    , testProperty "check witch's turn does nothing unless actioned or passed"  prop_checkWitchsTurnDoesNothingUnlessActionedOrPassed
    , testProperty "check witch's turn resets heal"                             prop_checkWitchsTurnResetsHeal
    , testProperty "check witch's turn resets poison"                           prop_checkWitchsTurnResetsPoison
    , testProperty "check witch's turn clears passes"                           prop_checkWitchsTurnClearsPasses

    , testProperty "check wolf-hound's turn advances to werewolves' turn"   prop_checkWolfHoundsTurnAdvancesToWerewolvesTurn
    , testProperty "check wolf-hound's turn advances when no wolf-hound"    prop_checkWolfHoundsTurnAdvancesWhenNoWolfHound
    , testProperty "check wolf-hound's turn does nothing unless chosen"     prop_checkWolfHoundsTurnDoesNothingUnlessChosen

    , testProperty "check game over advances stage when zero allegiances alive" prop_checkGameOverAdvancesStageWhenZeroAllegiancesAlive
    , testProperty "check game over advances stage when one allegiance alive" prop_checkGameOverAdvancesStageWhenOneAllegianceAlive
    -- TODO (hjw): pending
    --, testProperty "check game over does nothing when at least two allegiances alive"   prop_checkGameOverDoesNothingWhenAtLeastTwoAllegiancesAlive
    , testProperty "check game over advances stage when second round and angel dead" prop_checkGameOverAdvancesStageWhenSecondRoundAndAngelDead

    , testProperty "start game uses given players"                              prop_startGameUsesGivenPlayers
    , testProperty "start game errors unless unique player names"               prop_startGameErrorsUnlessUniquePlayerNames
    , testProperty "start game errors when less than 7 players"                 prop_startGameErrorsWhenLessThan7Players
    , testProperty "start game errors when more than 24 players"                prop_startGameErrorsWhenMoreThan24Players
    , testProperty "start game errors when more than 1 of a restricted role"    prop_startGameErrorsWhenMoreThan1OfARestrictedRole

    , testProperty "create players uses given player names" prop_createPlayersUsesGivenPlayerNames
    , testProperty "create players uses given roles"        prop_createPlayersUsesGivenRoles
    , testProperty "create players creates alive players"   prop_createPlayersCreatesAlivePlayers

    , testProperty "pad roles returns n roles"          prop_padRolesReturnsNRoles
    , testProperty "pad roles uses given roles"         prop_padRolesUsesGivenRoles
    , testProperty "pad roles proportions allegiances"  prop_padRolesProportionsAllegiances
    ]

prop_checkStageSkipsDefendersTurnWhenNoDefender :: GameWithRoleModel -> Bool
prop_checkStageSkipsDefendersTurnWhenNoDefender (GameWithRoleModel game) =
    isWolfHoundsTurn $ run_ checkStage game'
    where
        defendersName   = game ^?! players . defenders . name
        game'           = killPlayer defendersName game

prop_checkStageSkipsScapegoatsTurnWhenNoScapegoat :: GameAtScapegoatsTurn -> Bool
prop_checkStageSkipsScapegoatsTurnWhenNoScapegoat (GameAtScapegoatsTurn game) =
    isScapegoatsTurn $ run_ checkStage game

prop_checkStageSkipsSeersTurnWhenNoSeer :: GameWithLynchVotes -> Property
prop_checkStageSkipsSeersTurnWhenNoSeer (GameWithLynchVotes game) =
    has (players . angels . alive) (run_ checkStage game')
    ==> isScapegoatsTurn game' || isWildChildsTurn game' || isDefendersTurn game'
    where
        seersName   = game ^?! players . seers . name
        game'       = run_ (apply (quitCommand seersName) >> checkStage) game

prop_checkStageSkipsVillagesTurnWhenAllowedVotersEmpty :: GameAtWitchsTurn -> Property
prop_checkStageSkipsVillagesTurnWhenAllowedVotersEmpty (GameAtWitchsTurn game) =
    forAll (arbitraryPassCommand game') $ \(Blind passCommand) -> do
        isSeersTurn $ run_ (apply passCommand >> checkStage) game'
    where
        game' = game & allowedVoters .~ []

prop_checkStageSkipsWildChildsTurnWhenNoWildChild :: GameWithSee -> Bool
prop_checkStageSkipsWildChildsTurnWhenNoWildChild (GameWithSee game) =
    isDefendersTurn $ run_ checkStage game'
    where
        wildChildsName  = game ^?! players . wildChildren . name
        game'           = killPlayer wildChildsName game

prop_checkStageSkipsWitchsTurnWhenNoWitch :: GameWithDevourVotes -> Property
prop_checkStageSkipsWitchsTurnWhenNoWitch (GameWithDevourVotes game) =
    null (run_ checkStage game' ^.. players . angels)
    ==> isVillagesTurn $ run_ checkStage game'
    where
        witchsName  = game ^?! players . witches . name
        game'       = killPlayer witchsName game

prop_checkStageSkipsWolfHoundsTurnWhenNoWolfHound :: GameWithProtect -> Bool
prop_checkStageSkipsWolfHoundsTurnWhenNoWolfHound (GameWithProtect game) =
    isWerewolvesTurn $ run_ checkStage game'
    where
        wolfHoundsName  = game ^?! players . wolfHounds . name
        game'           = killPlayer wolfHoundsName game

prop_checkStageDoesNothingWhenGameOver :: GameAtGameOver -> Property
prop_checkStageDoesNothingWhenGameOver (GameAtGameOver game) =
    run_ checkStage game === game

prop_checkDefendersTurnAdvancesToWolfHoundsTurn :: GameWithProtect -> Bool
prop_checkDefendersTurnAdvancesToWolfHoundsTurn (GameWithProtect game) =
    isWolfHoundsTurn $ run_ checkStage game

prop_checkDefendersTurnAdvancesWhenNoDefender :: GameAtDefendersTurn -> Bool
prop_checkDefendersTurnAdvancesWhenNoDefender (GameAtDefendersTurn game) = do
    let defender    = game ^?! players . defenders
    let command     = quitCommand $ defender ^. name

    not . isDefendersTurn $ run_ (apply command >> checkStage) game

prop_checkDefendersTurnDoesNothingUnlessProtected :: GameAtDefendersTurn -> Bool
prop_checkDefendersTurnDoesNothingUnlessProtected (GameAtDefendersTurn game) =
    isDefendersTurn $ run_ checkStage game

prop_checkScapegoatsTurnAdvancesToSeersTurn :: GameWithAllowedVoters -> Bool
prop_checkScapegoatsTurnAdvancesToSeersTurn (GameWithAllowedVoters game) =
    isSeersTurn $ run_ checkStage game

prop_checkScapegoatsTurnDoesNothingWhileScapegoatBlamed :: GameAtScapegoatsTurn -> Bool
prop_checkScapegoatsTurnDoesNothingWhileScapegoatBlamed (GameAtScapegoatsTurn game) =
    isScapegoatsTurn $ run_ checkStage game

prop_checkSeersTurnAdvancesToWildChildsTurn :: GameWithSee -> Bool
prop_checkSeersTurnAdvancesToWildChildsTurn (GameWithSee game) =
    isWildChildsTurn $ run_ checkStage game

prop_checkSeersTurnAdvancesWhenNoSeer :: GameAtSeersTurn -> Bool
prop_checkSeersTurnAdvancesWhenNoSeer (GameAtSeersTurn game) = do
    let seer    = game ^?! players . seers
    let command = quitCommand $ seer ^. name

    not . isSeersTurn $ run_ (apply command >> checkStage) game

prop_checkSeersTurnResetsSee :: GameWithSee -> Bool
prop_checkSeersTurnResetsSee (GameWithSee game) =
    isNothing $ run_ checkStage game ^. see

prop_checkSeersTurnDoesNothingUnlessSeen :: GameAtSeersTurn -> Bool
prop_checkSeersTurnDoesNothingUnlessSeen (GameAtSeersTurn game) =
    isSeersTurn $ run_ checkStage game

prop_checkSunriseIncrementsRound :: GameAtSunrise -> Property
prop_checkSunriseIncrementsRound (GameAtSunrise game) =
    run_ checkStage game ^. round === game ^. round + 1

prop_checkSunriseSetsAngelsRole :: GameAtSunrise -> Bool
prop_checkSunriseSetsAngelsRole (GameAtSunrise game) = do
    let angel = game ^?! players . angels
    let game' = run_ checkStage game

    is simpleVillager $ game' ^?! players . traverse . filteredBy name (angel ^. name)

prop_checkSunsetSetsWildChildsAllegianceWhenRoleModelDead :: GameWithRoleModelAtVillagesTurn -> Property
prop_checkSunsetSetsWildChildsAllegianceWhenRoleModelDead (GameWithRoleModelAtVillagesTurn game) = do
    let game' = foldr (\player -> run_ (apply $ voteLynchCommand (player ^. name) (roleModel' ^. name))) game (game ^. players)

    isn't angel roleModel' && isn't villageIdiot roleModel'
        ==> is werewolf $ run_ checkStage game' ^?! players . wildChildren
    where
        roleModel' = game ^?! players . traverse . filteredBy name (fromJust $ game ^. roleModel)

prop_checkVillagesTurnAdvancesToScapegoatsTurn :: GameWithScapegoatBlamed -> Bool
prop_checkVillagesTurnAdvancesToScapegoatsTurn (GameWithScapegoatBlamed game) =
    isScapegoatsTurn $ run_ checkStage game

prop_checkVillagesTurnLynchesOnePlayerWhenConsensus :: GameWithLynchVotes -> Property
prop_checkVillagesTurnLynchesOnePlayerWhenConsensus (GameWithLynchVotes game) =
    length (getVoteResult game) == 1
    && isn't villageIdiot target
    ==> length (run_ checkStage game ^.. players . traverse . dead) == 1
    where
        target = head $ getVoteResult game

prop_checkVillagesTurnLynchesNoOneWhenTargetIsVillageIdiot :: GameAtVillagesTurn -> Bool
prop_checkVillagesTurnLynchesNoOneWhenTargetIsVillageIdiot (GameAtVillagesTurn game) = do
    let game' = foldr (\player -> run_ (apply $ voteLynchCommand (player ^. name) (villageIdiot ^. name))) game (game ^. players)

    none (is dead) (run_ checkStage game' ^. players)
    where
        villageIdiot = game ^?! players . villageIdiots

-- TODO (hjw): tidy this test
prop_checkVillagesTurnLynchesNoOneWhenConflictedAndNoScapegoats :: Game -> Property
prop_checkVillagesTurnLynchesNoOneWhenConflictedAndNoScapegoats game =
    forAll (runArbitraryCommands n game') $ \game'' ->
    length (getVoteResult game'') > 1
    ==> run_ checkStage game'' ^. players == game' ^. players
    where
        scapegoatsName  = game ^?! players . scapegoats . name
        game'           = killPlayer scapegoatsName game & stage .~ VillagesTurn
        n               = length $ game' ^. players

prop_checkVillagesTurnLynchesScapegoatWhenConflicted :: GameAtScapegoatsTurn -> Bool
prop_checkVillagesTurnLynchesScapegoatWhenConflicted (GameAtScapegoatsTurn game) =
    is dead $ run_ checkStage game ^?! players . scapegoats

prop_checkVillagesTurnResetsVotes :: GameWithLynchVotes -> Bool
prop_checkVillagesTurnResetsVotes (GameWithLynchVotes game) =
    Map.null $ run_ checkStage game ^. votes

prop_checkVillagesTurnSetsAllowedVoters :: GameWithLynchVotes -> Property
prop_checkVillagesTurnSetsAllowedVoters (GameWithLynchVotes game) =
    game' ^. allowedVoters === expectedAllowedVoters ^.. names
    where
        game' = run_ checkStage game
        expectedAllowedVoters
            | game' ^. villageIdiotRevealed = filter (isn't villageIdiot) $ game' ^. players
            | otherwise                     = game' ^.. players . traverse . alive

prop_checkVillagesTurnDoesNothingUnlessAllVoted :: GameAtVillagesTurn -> Property
prop_checkVillagesTurnDoesNothingUnlessAllVoted (GameAtVillagesTurn game) =
    forAll (runArbitraryCommands n game) $ \game' ->
    isVillagesTurn $ run_ checkStage game'
    where
        n = length (game ^. players) - 1

prop_checkWerewolvesTurnAdvancesToWitchsTurn :: GameWithDevourVotes -> Property
prop_checkWerewolvesTurnAdvancesToWitchsTurn (GameWithDevourVotes game) =
    length (getVoteResult game) == 1
    ==> isWitchsTurn $ run_ checkStage game

prop_checkWerewolvesTurnSkipsWitchsTurnWhenHealedAndPoisoned :: GameWithDevourVotes -> Bool
prop_checkWerewolvesTurnSkipsWitchsTurnWhenHealedAndPoisoned (GameWithDevourVotes game) =
    not . isWitchsTurn $ run_ checkStage game'
    where
        game' = game & healUsed .~ True & poisonUsed .~ True

prop_checkWerewolvesTurnKillsOnePlayerWhenConsensus :: GameWithDevourVotes -> Property
prop_checkWerewolvesTurnKillsOnePlayerWhenConsensus (GameWithDevourVotes game) =
    length (getVoteResult game) == 1
    ==> isJust . getDevourEvent $ run_ checkStage game

prop_checkWerewolvesTurnKillsNoOneWhenConflicted :: GameWithDevourVotes -> Property
prop_checkWerewolvesTurnKillsNoOneWhenConflicted (GameWithDevourVotes game) =
    length (getVoteResult game) > 1
    ==> isNothing . getDevourEvent $ run_ checkStage game

prop_checkWerewolvesTurnKillsNoOneWhenTargetDefended :: GameWithProtectAndDevourVotes -> Property
prop_checkWerewolvesTurnKillsNoOneWhenTargetDefended (GameWithProtectAndDevourVotes game) =
    length (getVoteResult game) == 1
    ==> isNothing . getDevourEvent $ run_ checkStage game'
    where
        target  = head $ getVoteResult game
        game'   = game & protect .~ Just (target ^. name)

prop_checkWerewolvesTurnResetsProtect :: GameWithProtectAndDevourVotes -> Bool
prop_checkWerewolvesTurnResetsProtect (GameWithProtectAndDevourVotes game) =
    isNothing $ run_ checkStage game ^. protect

prop_checkWerewolvesTurnResetsVotes :: GameWithDevourVotes -> Bool
prop_checkWerewolvesTurnResetsVotes (GameWithDevourVotes game) =
    Map.null $ run_ checkStage game ^. votes

prop_checkWerewolvesTurnDoesNothingUnlessAllVoted :: GameAtWerewolvesTurn -> Property
prop_checkWerewolvesTurnDoesNothingUnlessAllVoted (GameAtWerewolvesTurn game) =
    forAll (runArbitraryCommands n game) $ \game' ->
    isWerewolvesTurn $ run_ checkStage game'
    where
        n = length (game ^.. players . werewolves) - 1

prop_checkWildChildsTurnAdvancesToDefendersTurn :: GameAtWildChildsTurn -> Property
prop_checkWildChildsTurnAdvancesToDefendersTurn (GameAtWildChildsTurn game) =
    forAll (arbitraryChoosePlayerCommand game) $ \(Blind command) ->
    isDefendersTurn $ run_ (apply command >> checkStage) game

prop_checkWildChildsTurnAdvancesWhenNoWildChild :: GameAtWildChildsTurn -> Bool
prop_checkWildChildsTurnAdvancesWhenNoWildChild (GameAtWildChildsTurn game) = do
    let wildChild   = game ^?! players . wildChildren
    let command     = quitCommand $ wildChild ^. name

    not . isWildChildsTurn $ run_ (apply command >> checkStage) game

prop_checkWildChildsTurnDoesNothingUnlessRoleModelChosen :: GameAtWildChildsTurn -> Bool
prop_checkWildChildsTurnDoesNothingUnlessRoleModelChosen (GameAtWildChildsTurn game) =
    isWildChildsTurn $ run_ checkStage game

prop_checkWitchsTurnAdvancesToVillagesTurn :: GameAtWitchsTurn -> Property
prop_checkWitchsTurnAdvancesToVillagesTurn (GameAtWitchsTurn game) =
    forAll (arbitraryPassCommand game) $ \(Blind command) ->
    isVillagesTurn $ run_ (apply command >> checkStage) game

prop_checkWitchsTurnAdvancesWhenNoWitch :: GameAtWitchsTurn -> Bool
prop_checkWitchsTurnAdvancesWhenNoWitch (GameAtWitchsTurn game) = do
    let witch   = game ^?! players . witches
    let command = quitCommand $ witch ^. name

    not . isWitchsTurn $ run_ (apply command >> checkStage) game

prop_checkWitchsTurnHealsDevoureeWhenHealed :: GameWithHeal -> Property
prop_checkWitchsTurnHealsDevoureeWhenHealed (GameWithHeal game) =
    forAll (arbitraryPassCommand game) $ \(Blind command) ->
    none (is dead) (run_ (apply command >> checkStage) game ^. players)

prop_checkWitchsTurnKillsOnePlayerWhenPoisoned :: GameWithPoison -> Property
prop_checkWitchsTurnKillsOnePlayerWhenPoisoned (GameWithPoison game) =
    forAll (arbitraryPassCommand game) $ \(Blind command) ->
    length (run_ (apply command >> checkStage) game ^.. players . traverse . dead) == 1

prop_checkWitchsTurnDoesNothingWhenPassed :: GameAtWitchsTurn -> Property
prop_checkWitchsTurnDoesNothingWhenPassed (GameAtWitchsTurn game) =
    forAll (arbitraryPassCommand game) $ \(Blind command) ->
    none (is dead) $ run_ (apply command >> checkStage) game ^. players

prop_checkWitchsTurnDoesNothingUnlessActionedOrPassed :: GameAtWitchsTurn -> Bool
prop_checkWitchsTurnDoesNothingUnlessActionedOrPassed (GameAtWitchsTurn game) =
    isWitchsTurn $ run_ checkStage game

prop_checkWitchsTurnResetsHeal :: GameWithHeal -> Property
prop_checkWitchsTurnResetsHeal (GameWithHeal game) =
    forAll (arbitraryPassCommand game) $ \(Blind command) ->
    not $ run_ (apply command >> checkStage) game ^. heal

prop_checkWitchsTurnResetsPoison :: GameWithPoison -> Property
prop_checkWitchsTurnResetsPoison (GameWithPoison game) =
    forAll (arbitraryPassCommand game) $ \(Blind command) ->
    isNothing $ run_ (apply command >> checkStage) game ^. poison

prop_checkWitchsTurnClearsPasses :: GameAtWitchsTurn -> Property
prop_checkWitchsTurnClearsPasses (GameAtWitchsTurn game) =
    forAll (arbitraryPassCommand game) $ \(Blind command) ->
    null $ run_ (apply command >> checkStage) game ^. passes

prop_checkWolfHoundsTurnAdvancesToWerewolvesTurn :: GameAtWolfHoundsTurn -> Property
prop_checkWolfHoundsTurnAdvancesToWerewolvesTurn (GameAtWolfHoundsTurn game) =
    forAll (arbitraryChooseAllegianceCommand game) $ \(Blind command) ->
    isWerewolvesTurn $ run_ (apply command >> checkStage) game

prop_checkWolfHoundsTurnAdvancesWhenNoWolfHound :: GameAtWolfHoundsTurn -> Bool
prop_checkWolfHoundsTurnAdvancesWhenNoWolfHound (GameAtWolfHoundsTurn game) = do
    let wolfHound   = game ^?! players . wolfHounds
    let command     = quitCommand $ wolfHound ^. name

    not . isWolfHoundsTurn $ run_ (apply command >> checkStage) game

prop_checkWolfHoundsTurnDoesNothingUnlessChosen :: GameAtWolfHoundsTurn -> Bool
prop_checkWolfHoundsTurnDoesNothingUnlessChosen (GameAtWolfHoundsTurn game) =
    isWolfHoundsTurn $ run_ checkStage game

prop_checkGameOverAdvancesStageWhenZeroAllegiancesAlive :: GameWithZeroAllegiancesAlive -> Bool
prop_checkGameOverAdvancesStageWhenZeroAllegiancesAlive (GameWithZeroAllegiancesAlive game) =
    isGameOver $ run_ checkGameOver game

prop_checkGameOverAdvancesStageWhenOneAllegianceAlive :: GameWithOneAllegianceAlive -> Property
prop_checkGameOverAdvancesStageWhenOneAllegianceAlive (GameWithOneAllegianceAlive game) =
    forAll (sublistOf $ game ^.. players . traverse . alive) $ \players' -> do
        let game' = foldr killPlayer game (players' ^.. names)

        isGameOver $ run_ checkGameOver game'

-- TODO (hjw): pending
--prop_checkGameOverDoesNothingWhenAtLeastTwoAllegiancesAlive :: GameWithDeadPlayers -> Property
--prop_checkGameOverDoesNothingWhenAtLeastTwoAllegiancesAlive (GameWithDeadPlayers game) =
--    length (nub . map (view $ role . allegiance) . filterAlive $ game ^. players) > 1
--    ==> not . isGameOver $ run_ checkGameOver game

prop_checkGameOverAdvancesStageWhenSecondRoundAndAngelDead :: GameOnSecondRound -> Bool
prop_checkGameOverAdvancesStageWhenSecondRoundAndAngelDead (GameOnSecondRound game) = do
    let angel = game ^?! players . angels
    let game' = killPlayer (angel ^. name) game

    isGameOver $ run_ checkGameOver game'

prop_startGameUsesGivenPlayers :: Property
prop_startGameUsesGivenPlayers =
    forAll arbitraryPlayerSet $ \players' ->
    (fst . fromRight . runExcept . runWriterT $ startGame "" players') ^. players == players'

prop_startGameErrorsUnlessUniquePlayerNames :: Game -> Property
prop_startGameErrorsUnlessUniquePlayerNames game =
    forAll (elements players') $ \player ->
    isLeft (runExcept . runWriterT $ startGame "" (player:players'))
    where
        players' = game ^. players

prop_startGameErrorsWhenLessThan7Players :: [Player] -> Property
prop_startGameErrorsWhenLessThan7Players players =
    length players < 7
    ==> isLeft . runExcept . runWriterT $ startGame "" players

prop_startGameErrorsWhenMoreThan24Players :: Property
prop_startGameErrorsWhenMoreThan24Players =
    forAll (resize 30 $ listOf arbitrary) $ \players ->
        length players > 24
        ==> isLeft . runExcept . runWriterT $ startGame "" players

prop_startGameErrorsWhenMoreThan1OfARestrictedRole :: [Player] -> Property
prop_startGameErrorsWhenMoreThan1OfARestrictedRole players =
    any (\role' -> length (players ^.. traverse . filteredBy role role') > 1) restrictedRoles
    ==> isLeft . runExcept . runWriterT $ startGame "" players

prop_createPlayersUsesGivenPlayerNames :: [Text] -> [Role] -> Property
prop_createPlayersUsesGivenPlayerNames playerNames extraRoles = monadicIO $ do
    players <- createPlayers playerNames (padRoles extraRoles (length playerNames))

    return $ playerNames == players ^.. names

prop_createPlayersUsesGivenRoles :: [Text] -> [Role] -> Property
prop_createPlayersUsesGivenRoles playerNames extraRoles = monadicIO $ do
    let roles' = padRoles extraRoles (length playerNames)

    players <- createPlayers playerNames roles'

    return $ roles' == players ^.. roles

prop_createPlayersCreatesAlivePlayers :: [Text] -> [Role] -> Property
prop_createPlayersCreatesAlivePlayers playerNames extraRoles = monadicIO $ do
    players <- createPlayers playerNames (padRoles extraRoles (length playerNames))

    return $ all (is alive) players

prop_padRolesReturnsNRoles :: [Role] -> Int -> Property
prop_padRolesReturnsNRoles extraRoles n = monadicIO $ do
    let roles = padRoles extraRoles n

    return $ length roles == n

prop_padRolesUsesGivenRoles :: [Role] -> Int -> Property
prop_padRolesUsesGivenRoles extraRoles n = monadicIO $ do
    let roles = padRoles extraRoles n

    return $ extraRoles `isSubsequenceOf` roles

prop_padRolesProportionsAllegiances :: [Role] -> Int -> Property
prop_padRolesProportionsAllegiances extraRoles n = monadicIO $ do
    let roles           = padRoles extraRoles n
    let werewolvesCount = length . elemIndices Role.Werewolves $ roles ^.. traverse . allegiance

    return $ werewolvesCount == n `quot` 5 + 1
