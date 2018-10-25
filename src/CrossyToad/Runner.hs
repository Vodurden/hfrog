module CrossyToad.Runner (mainLoop) where

import Control.Lens (use)
import Control.Monad (unless)
import Control.Monad.Reader (MonadReader)
import Control.Monad.State (MonadState)

import           CrossyToad.Config
import           CrossyToad.Vars (HasVars)
import           CrossyToad.Effect.Renderer
import           CrossyToad.Effect.Input
import           CrossyToad.Scene.Scene (HasScene)
import qualified CrossyToad.Scene.Scene as Scene

mainLoop ::
  ( MonadReader Config m, MonadState s m
  , HasVars s
  , HasScene s
  , Input m
  , Renderer m
  ) => m ()
mainLoop = do
  updateInput

  clearScreen
  Scene.step
  drawScreen

  scene <- use Scene.scene
  unless (scene == Scene.Quit) mainLoop
