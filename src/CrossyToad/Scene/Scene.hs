{-# LANGUAGE TemplateHaskell #-}

module CrossyToad.Scene.Scene
  ( Scene(..)
  , AsScene(..)
  , HasScene(..)
  , step
  ) where

import Control.Lens
import Control.Monad.State (MonadState)

import CrossyToad.Renderer.Renderer
import CrossyToad.Input.Input
import CrossyToad.Scene.Internal
import CrossyToad.Scene.Title.Title (stepTitle)
import CrossyToad.Scene.Game.Game (stepGame)

step :: (MonadState s m, HasScene s, Input m, Renderer m) => m ()
step = do
    s <- use scene
    step' s
  where
    step' Title = stepTitle
    step' Game = stepGame
    step' Quit = pure ()
