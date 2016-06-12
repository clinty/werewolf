{-|
Module      : Game.Werewolf.Variant.NoRoleReveal.Engine
Description : Suite of engine messages used throughout the game.

Copyright   : (c) Henry J. Wylde, 2016
License     : BSD3
Maintainer  : public@hjwylde.com

A 'Message' is used to relay information back to either all players or a single player. This module
defines suite of engine messages used throughout the werewolf game for the 'NoRoleReveal' variant.
-}

{-# LANGUAGE QuasiQuotes #-}

module Game.Werewolf.Variant.NoRoleReveal.Engine (
    -- * General
    playerBootedText,

    -- * Lynching
    playerLynchedText, werewolfLynchedText,

    -- * Sunrise
    playerDevouredText, playerPoisonedText, playerTurnedToStoneText,
) where

import Data.String.Humanise
import Data.String.Interpolate.Extra
import Data.Text                     (Text)

import Game.Werewolf

playerBootedText :: Player -> Text
playerBootedText player = [iFile|variant/no-role-reveal/engine/general/player-booted.txt|]

playerLynchedText :: Player -> Text
playerLynchedText player = [iFile|variant/no-role-reveal/engine/lynching/player-lynched.txt|]

werewolfLynchedText :: Player -> Text
werewolfLynchedText werewolf = [iFile|variant/no-role-reveal/engine/lynching/werewolf-lynched.txt|]

playerDevouredText :: Player -> Text
playerDevouredText player = [iFile|variant/no-role-reveal/engine/sunrise/player-devoured.txt|]

playerPoisonedText :: Player -> Text
playerPoisonedText player = [iFile|variant/no-role-reveal/engine/sunrise/player-poisoned.txt|]

playerTurnedToStoneText :: Player -> Text
playerTurnedToStoneText player = [iFile|variant/no-role-reveal/engine/sunrise/player-turned-to-stone.txt|]