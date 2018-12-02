{-# LANGUAGE TemplateHaskell #-}

module CrossyToad.Effect.Renderer.SDL.Fonts where

import           Control.Lens
import           SDL.Font (Font, PointSize)
import qualified SDL.Font as Font

import           CrossyToad.Effect.Renderer.FontAsset (FontAsset)
import qualified CrossyToad.Effect.Renderer.FontAsset as FontAsset

data Fonts = Fonts
  { _titleFont :: !Font
  }

makeClassy ''Fonts

fromFontAsset :: FontAsset -> Fonts -> Font
fromFontAsset FontAsset.Title = view titleFont

loadFonts :: IO Fonts
loadFonts = do
    titleFont' <- loadFont FontAsset.Title 80

    pure $ Fonts
      { _titleFont = titleFont'
      }

loadFont :: FontAsset -> PointSize -> IO Font
loadFont asset size = do
  let filepath = FontAsset.filepath asset
  Font.load filepath size
