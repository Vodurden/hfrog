{-# LANGUAGE TupleSections #-}

module CrossyToad.Scene.Game.Game
  ( scene
  , initialize
  , handleInput
  , step
  , stepIntent
  , render
  , module CrossyToad.Scene.Game.GameState
  ) where

import           Control.Lens.Extended
import           Control.Monad.State.Strict (execStateT)
import           Data.Foldable (foldl', foldlM)
import           Linear.V2

import           CrossyToad.Input.MonadInput (MonadInput)
import qualified CrossyToad.Input.MonadInput as MonadInput
import           CrossyToad.Input.InputState (InputState)
import           CrossyToad.Logger.MonadLogger (MonadLogger(..))
import qualified CrossyToad.Renderer.Asset.ImageAsset as ImageAsset
import qualified CrossyToad.Renderer.MonadRenderer as MonadRenderer
import           CrossyToad.Renderer.MonadRenderer (MonadRenderer)
import qualified CrossyToad.Renderer.Animated as Animated
import           CrossyToad.Physics.Physics (Direction(..))
import           CrossyToad.Scene.Scene (Scene)
import qualified CrossyToad.Scene.Scene as Scene
import           CrossyToad.Scene.MonadScene (MonadScene)
import qualified CrossyToad.Scene.MonadScene as MonadScene
import           CrossyToad.Scene.Game.Car (HasCars(..))
import qualified CrossyToad.Scene.Game.Car as Car
import qualified CrossyToad.Scene.Game.Collision as Collision
import           CrossyToad.Scene.Game.Command (Command(..))
import qualified CrossyToad.Scene.Game.Entity as Entity
import           CrossyToad.Scene.Game.GameState (GameState, HasGameState(..))
import qualified CrossyToad.Scene.Game.GameState as GameState
import           CrossyToad.Scene.Game.Intent (Intent(..))
import qualified CrossyToad.Scene.Game.Intent as Intent
import           CrossyToad.Scene.Game.SpawnPoint (SpawnPoint, HasSpawnPoints(..))
import qualified CrossyToad.Scene.Game.SpawnPoint as SpawnPoint
import           CrossyToad.Scene.Game.Toad (HasToad(..))
import qualified CrossyToad.Scene.Game.Toad as Toad
import           CrossyToad.Time.MonadTime (MonadTime(..))

scene ::
  ( MonadRenderer m
  , MonadScene m
  , MonadInput m
  , MonadLogger m
  , MonadTime m
  ) => Scene m
scene = Scene.mk initialize tick

initialize :: GameState
initialize = GameState.mk &
    (gameState.toad .~ Toad.mk (V2 (7*64) (13*64)))
    . (gameState.cars .~ [])
    . (gameState.spawnPoints .~ spawnPoints')
  where
    spawnPoints' :: [SpawnPoint]
    spawnPoints' =
      [ -- River Spawns
        -- TODO

        -- Road Spawns
        SpawnPoint.mk (V2 (20*64) (7*64 )) West ((,Entity.Car) <$> [0,1,1]) 2
      , SpawnPoint.mk (V2 (20*64) (8*64 )) West ((,Entity.Car) <$> [0,0.5,0.5,0.5]) 1
      , SpawnPoint.mk (V2 0       (9*64 )) East ((,Entity.Car) <$> [0.5,2]) 3
      , SpawnPoint.mk (V2 (20*64) (10*64)) West ((,Entity.Car) <$> [0.5,2,4]) 3
      ]

tick ::
  ( MonadRenderer m
  , MonadScene m
  , MonadInput m
  , MonadLogger m
  , MonadTime m
  ) => GameState -> m GameState
tick gameState' = do
  inputState' <- MonadInput.getInputState
  gameState'' <- handleInput inputState' gameState'
  gameState''' <- step gameState''

  MonadRenderer.clearScreen
  render gameState'''
  MonadRenderer.drawScreen

  pure gameState'''

-- | Update the GameState and Scene based on the user input
handleInput :: (MonadScene m, HasGameState ent) => InputState -> ent -> m ent
handleInput input ent' =
  foldlM (flip stepIntent) ent' (Intent.fromInputState input)

stepIntent :: (MonadScene m, HasGameState ent) => Intent -> ent -> m ent
stepIntent (Move dir) ent = pure $ ent & gameState . toad %~ (Toad.jump dir)
stepIntent Exit ent = MonadScene.delayPop >> pure ent

step :: (MonadLogger m, MonadTime m, HasGameState ent) => ent -> m ent
step ent = do
  stepGameState ent

-- | Step all the GameState specific logic
stepGameState :: (MonadLogger m, MonadTime m, HasGameState ent) => ent -> m ent
stepGameState ent' = flip execStateT ent' $ do
  modifyingM (gameState.toad) Toad.step

  spCommands <- zoom (gameState.spawnPoints) SpawnPoint.stepAll
  id %= (runCommands spCommands)

  modifyingM (gameState.cars) Car.stepAll
  modifyingM gameState Collision.step

runCommands :: forall ent. (HasGameState ent) => [Command] -> ent -> ent
runCommands commands ent' = foldl' (flip runCommand) ent' commands
  where runCommand :: Command -> ent -> ent
        runCommand (Spawn Entity.Car pos dir) = gameState . cars %~ (Car.mk pos dir :)
        runCommand (Spawn Entity.RiverLog _ _) = id
        runCommand Kill = id

render :: (MonadRenderer m, HasGameState ent) => ent -> m ()
render ent = do
  renderBackground'
  sequence_ $ MonadRenderer.runRenderCommand <$> Car.render <$> (ent ^. gameState . cars)
  MonadRenderer.runRenderCommand $ Animated.render (ent ^. gameState . toad)

renderBackground' :: (MonadRenderer m) => m ()
renderBackground' = do
  MonadRenderer.drawTileRow ImageAsset.Swamp (V2 0 0    ) 20 (V2 64 64)
  MonadRenderer.drawTileRow ImageAsset.Water (V2 0 1*64 ) 20 (V2 64 64)
  MonadRenderer.drawTileRow ImageAsset.Water (V2 0 2*64 ) 20 (V2 64 64)
  MonadRenderer.drawTileRow ImageAsset.Water (V2 0 3*64 ) 20 (V2 64 64)
  MonadRenderer.drawTileRow ImageAsset.Water (V2 0 4*64 ) 20 (V2 64 64)
  MonadRenderer.drawTileRow ImageAsset.Water (V2 0 5*64 ) 20 (V2 64 64)
  MonadRenderer.drawTileRow ImageAsset.Grass (V2 0 6*64 ) 20 (V2 64 64)
  MonadRenderer.drawTileRow ImageAsset.Road  (V2 0 7*64 ) 20 (V2 64 64)
  MonadRenderer.drawTileRow ImageAsset.Road  (V2 0 8*64 ) 20 (V2 64 64)
  MonadRenderer.drawTileRow ImageAsset.Road  (V2 0 9*64 ) 20 (V2 64 64)
  MonadRenderer.drawTileRow ImageAsset.Road  (V2 0 10*64) 20 (V2 64 64)
  MonadRenderer.drawTileRow ImageAsset.Road  (V2 0 11*64) 20 (V2 64 64)
  MonadRenderer.drawTileRow ImageAsset.Grass (V2 0 12*64) 20 (V2 64 64)
