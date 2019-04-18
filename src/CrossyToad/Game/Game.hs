{-# LANGUAGE TupleSections #-}

module CrossyToad.Game.Game
  ( scene
  , initialize
  , handleInput
  , step
  , stepIntent
  , render
  , module CrossyToad.Game.GameState
  ) where

import           Control.Lens.Extended
import           Control.Monad.State.Strict.Extended (execStateT, hoistState)
import           Data.Foldable (foldl', foldlM)
import           Linear.V2

import           CrossyToad.Input.InputState (InputState)
import           CrossyToad.Logger.MonadLogger (MonadLogger(..))
import qualified CrossyToad.Renderer.Asset.ImageAsset as ImageAsset
import qualified CrossyToad.Renderer.MonadRenderer as MonadRenderer
import           CrossyToad.Renderer.MonadRenderer (MonadRenderer)
import qualified CrossyToad.Renderer.Animated as Animated
import qualified CrossyToad.Renderer.Sprite as Sprite
import           CrossyToad.Physics.Physics (Direction(..))
import           CrossyToad.Scene.Scene (Scene)
import qualified CrossyToad.Scene.Scene as Scene
import           CrossyToad.Scene.MonadScene (MonadScene)
import qualified CrossyToad.Scene.MonadScene as MonadScene
import qualified CrossyToad.Game.Car as Car
import qualified CrossyToad.Game.RiverLog as RiverLog
import qualified CrossyToad.Game.Collision as Collision
import           CrossyToad.Game.Command (Command(..))
import qualified CrossyToad.Game.Entity as Entity
import           CrossyToad.Game.GameState (GameState, HasGameState(..))
import qualified CrossyToad.Game.GameState as GameState
import           CrossyToad.Game.Intent (Intent(..))
import qualified CrossyToad.Game.Intent as Intent
import           CrossyToad.Game.SpawnPoint (SpawnPoint, HasSpawnPoints(..))
import qualified CrossyToad.Game.SpawnPoint as SpawnPoint
import           CrossyToad.Game.Toad (HasToad(..))
import qualified CrossyToad.Game.Toad as Toad
import           CrossyToad.Time.Seconds
import           CrossyToad.Time.TickSeconds

scene ::
  ( MonadRenderer m
  , MonadScene m
  , MonadLogger m
  ) => Scene m
scene = Scene.mk initialize handleInput tick render

initialize :: GameState
initialize = GameState.mk &
    (gameState.toad .~ Toad.mk (V2 (7*64) (13*64)))
    . (gameState.cars .~ [])
    . (gameState.riverLogs .~ [])
    . (gameState.spawnPoints .~ spawnPoints')
  where
    spawnPoints' :: [SpawnPoint]
    spawnPoints' =
      [ -- River Spawns
        SpawnPoint.mk (V2 0       (1*64 )) East ((,Entity.RiverLog) <$> [1]) 5
        -- TODO

        -- Road Spawns
      , SpawnPoint.mk (V2 (20*64) (7*64 )) West ((,Entity.Car) <$> [0,1,1]) 2
      , SpawnPoint.mk (V2 (20*64) (8*64 )) West ((,Entity.Car) <$> [0,0.6,0.6,0.6]) 1
      , SpawnPoint.mk (V2 0       (9*64 )) East ((,Entity.Car) <$> [0.5,2]) 3
      , SpawnPoint.mk (V2 (20*64) (10*64)) West ((,Entity.Car) <$> [0.5,2,4]) 3
      ]

tick :: MonadLogger m => Seconds -> GameState -> m GameState
tick seconds gameState' = do
  step (TickSeconds seconds) gameState'

-- | Update the GameState and Scene based on the user input
handleInput :: (MonadScene m, HasGameState ent) => InputState -> ent -> m ent
handleInput input ent' =
  foldlM (flip stepIntent) ent' (Intent.fromInputState input)

stepIntent :: (MonadScene m, HasGameState ent) => Intent -> ent -> m ent
stepIntent (Move dir) ent = pure $ ent & gameState . toad %~ (Toad.jump dir)
stepIntent Exit ent = MonadScene.delayPop >> pure ent

step :: (MonadLogger m, HasGameState ent) => TickSeconds -> ent -> m ent
step ent = do
  stepGameState ent

-- | Step all the GameState specific logic
stepGameState :: (MonadLogger m, HasGameState ent) => TickSeconds -> ent -> m ent
stepGameState seconds ent' = flip execStateT ent' $ do
  gameState.toad %= Toad.step seconds

  spCommands <- zoom (gameState.spawnPoints) (hoistState $ SpawnPoint.stepAll seconds)
  id %= (runCommands spCommands)

  gameState.cars.mapped %= (Car.step seconds)
  gameState.riverLogs.mapped %= (RiverLog.step seconds)

  modifyingM gameState (Collision.toadCollision toad cars)

runCommands :: forall ent. (HasGameState ent) => [Command] -> ent -> ent
runCommands commands ent' = foldl' (flip runCommand) ent' commands
  where runCommand :: Command -> ent -> ent
        runCommand (Spawn Entity.Car pos dir) = gameState.cars %~ (Car.mk pos dir :)
        runCommand (Spawn Entity.RiverLog pos dir) = gameState.riverLogs %~ (RiverLog.mk pos dir :)
        runCommand Kill = id

render :: (MonadRenderer m, HasGameState ent) => ent -> m ()
render ent = do
  MonadRenderer.clearScreen

  renderBackground'
  sequence_ $ MonadRenderer.runRenderCommand <$> Sprite.render <$> (ent ^. gameState . cars)
  sequence_ $ MonadRenderer.runRenderCommand <$> Sprite.render <$> (ent ^. gameState . riverLogs)
  MonadRenderer.runRenderCommand $ Animated.render (ent ^. gameState . toad)

  MonadRenderer.drawScreen

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