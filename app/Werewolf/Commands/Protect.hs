{-|
Module      : Werewolf.Commands.Protect
Description : Options and handler for the protect subcommand.

Copyright   : (c) Henry J. Wylde, 2015
License     : BSD3
Maintainer  : public@hjwylde.com

Options and handler for the protect subcommand.
-}

module Werewolf.Commands.Protect (
    -- * Options
    Options(..),

    -- * Handle
    handle,
) where

import Control.Monad.Except
import Control.Monad.Extra
import Control.Monad.State
import Control.Monad.Writer

import Data.Text (Text)

import Game.Werewolf.Command
import Game.Werewolf.Engine
import Game.Werewolf.Response

data Options = Options
    { argTarget :: Text
    } deriving (Eq, Show)

handle :: MonadIO m => Text -> Options -> m ()
handle callerName (Options targetName) = do
    unlessM doesGameExist $ exitWith failure
        { messages = [noGameRunningMessage callerName]
        }

    game <- readGame

    let command = protectCommand callerName targetName

    case runExcept (runWriterT $ execStateT (apply command >> checkStage >> checkGameOver) game) of
        Left errorMessages      -> exitWith failure { messages = errorMessages }
        Right (game', messages) -> writeGame game' >> exitWith success { messages = messages }
