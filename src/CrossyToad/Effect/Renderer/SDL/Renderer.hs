module CrossyToad.Effect.Renderer.SDL.Renderer
  ( clearScreen
  , drawScreen
  , draw
  , drawAt
  , drawText
  ) where

import           Control.Lens
import           Control.Monad.Reader (MonadReader)
import           Control.Monad.IO.Class (MonadIO)
import           Data.Degrees (Degrees)
import           Data.Maybe (fromMaybe)
import           Data.Text (Text)
import           Foreign.C.Types (CInt)
import           Linear.V2
import qualified SDL
import qualified SDL.Font as Font

import           CrossyToad.Effect.Renderer.FontAsset
import           CrossyToad.Effect.Renderer.ImageAsset
import           CrossyToad.Effect.Renderer.PixelClip
import           CrossyToad.Effect.Renderer.PixelPosition
import           CrossyToad.Effect.Renderer.RGBAColour
import           CrossyToad.Effect.Renderer.SDL.Env
import           CrossyToad.Effect.Renderer.SDL.Fonts (HasFonts(..))
import qualified CrossyToad.Effect.Renderer.SDL.Fonts as Fonts
import           CrossyToad.Effect.Renderer.SDL.Texture (Texture, HasTexture(..))
import qualified CrossyToad.Effect.Renderer.SDL.Texture as Texture
import           CrossyToad.Effect.Renderer.SDL.Textures (HasTextures(..))
import qualified CrossyToad.Effect.Renderer.SDL.Textures as Textures

clearScreen :: (MonadReader r m, HasEnv r, MonadIO m) => m ()
clearScreen = view renderer >>= SDL.clear

drawScreen :: (MonadReader r m, HasEnv r, MonadIO m) => m ()
drawScreen = view renderer >>= SDL.present

draw ::
  ( MonadReader r m
  , HasEnv r
  , MonadIO m)
  => ImageAsset
  -> (Maybe Degrees)
  -> (Maybe TextureClip)
  -> (Maybe ScreenClip)
  -> m ()
draw asset' degrees textureClip screenClip = do
    textures' <- view (env.textures)
    let texture' = Textures.fromImageAsset asset' textures'
    drawTexture texture' degrees textureClip screenClip

drawAt ::
  ( MonadReader r m
  , HasEnv r
  , MonadIO m)
  => ImageAsset
  -> PixelPosition
  -> m ()
drawAt asset' pos = do
  textures' <- view (env.textures)
  let texture' = Textures.fromImageAsset asset' textures'
  let wh = V2 (texture' ^. Texture.width) (texture' ^. Texture.height)
  let screenClip = PixelClip pos (pos + wh)
  drawTexture texture' Nothing Nothing (Just screenClip)

drawText ::
  ( MonadReader r m
  , HasEnv r
  , MonadIO m)
  => FontAsset
  -> (Maybe Degrees)
  -> (Maybe TextureClip)
  -> (Maybe ScreenClip)
  -> RGBAColour
  -> Text
  -> m ()
drawText asset' degrees textureClip screenClip colour message = do
  fonts' <- view (env.fonts)
  let font' = Fonts.fromFontAsset asset' fonts'
  surface <- Font.blended font' colour message

  renderer' <- view (env.renderer)
  sdlTexture' <- SDL.createTextureFromSurface renderer' surface
  texture' <- Texture.fromSDL sdlTexture'
  drawTexture texture' degrees textureClip screenClip

drawTexture ::
  ( MonadReader r m
  , HasEnv r
  , MonadIO m)
  => Texture
  -> (Maybe Double)
  -> (Maybe TextureClip)
  -> (Maybe ScreenClip)
  -> m ()
drawTexture texture' degrees textureClip targetClip = do
    renderer' <- view (env.renderer)
    SDL.copyEx
      renderer'
      (texture' ^. sdlTexture)
      (fromPixelClip <$> textureClip)
      (fromPixelClip <$> targetClip)
      (realToFrac $ fromMaybe 0 degrees)
      Nothing
      (V2 False False)
  where
    fromPixelClip :: PixelClip -> SDL.Rectangle CInt
    fromPixelClip clip =
      let xy = fromIntegral <$> clip ^. topLeft
          wh = fromIntegral <$> clip ^. dimensions
      in SDL.Rectangle (SDL.P xy) wh
