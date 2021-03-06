module CrossyToad.Renderer.RGBAColour where

import Data.Word (Word8)
import Linear.V4

type RGBAColour = V4 Word8

white :: RGBAColour
white = V4 0xff 0xff 0xff 0xff

red :: RGBAColour
red = V4 0xff 0x00 0x00 0xff
