--------------------------------------------------------------------------------
-- |
-- Module      :  Graphics.Rendering.OpenGL.GL.Texturing.Objects
-- Copyright   :  (c) Sven Panne 2002-2004
-- License     :  BSD-style (see the file libraries/OpenGL/LICENSE)
-- 
-- Maintainer  :  sven.panne@aedion.de
-- Stability   :  provisional
-- Portability :  portable
--
-- This module corresponds to section 3.8.12 (Texture Objects) of the OpenGL 1.5
-- specs.
--
--------------------------------------------------------------------------------

module Graphics.Rendering.OpenGL.GL.Texturing.Objects (
   TextureObject, defaultTextureObject, textureBinding,
   areTexturesResident, prioritizeTextures
) where

import Control.Monad ( liftM )
import Data.List ( partition, genericLength )
import Foreign.Marshal.Array ( withArray, peekArray, allocaArray )
import Foreign.Ptr ( Ptr )
import Graphics.Rendering.OpenGL.GL.BasicTypes (
   GLuint, GLsizei, GLenum, GLclampf )
import Graphics.Rendering.OpenGL.GL.BufferObjects ( ObjectName(..) )
import Graphics.Rendering.OpenGL.GL.GLboolean (
   GLboolean, unmarshalGLboolean )
import Graphics.Rendering.OpenGL.GL.QueryUtils (
   GetPName(GetTextureBinding1D,GetTextureBinding2D,GetTextureBinding3D,
            GetTextureBindingCubeMap,GetTextureBindingRectangle),
   getEnum1)
import Graphics.Rendering.OpenGL.GL.StateVar ( StateVar, makeStateVar )
import Graphics.Rendering.OpenGL.GL.Texturing.TextureTarget (
   TextureTarget(..), marshalTextureTarget )

--------------------------------------------------------------------------------

newtype TextureObject = TextureObject { textureID :: GLuint }
   deriving ( Eq, Ord, Show )

defaultTextureObject :: TextureObject
defaultTextureObject = TextureObject 0

--------------------------------------------------------------------------------

instance ObjectName TextureObject where
   genObjectNames n =
      allocaArray n $ \buf -> do
        glGenTextures (fromIntegral n) buf
        liftM (map TextureObject) $ peekArray n buf

   deleteObjectNames textureObjects = do
      withArray (map textureID textureObjects) $
         glDeleteTextures (genericLength textureObjects)

   isObjectName = liftM unmarshalGLboolean . glIsTexture . textureID

foreign import CALLCONV unsafe "glGenTextures"
   glGenTextures :: GLsizei -> Ptr GLuint -> IO ()

foreign import CALLCONV unsafe "glDeleteTextures"
   glDeleteTextures :: GLsizei -> Ptr GLuint -> IO ()

foreign import CALLCONV unsafe "glIsTexture"
   glIsTexture :: GLuint -> IO GLboolean

--------------------------------------------------------------------------------

textureBinding :: TextureTarget -> StateVar TextureObject
textureBinding t =
   makeStateVar
      (getEnum1 TextureObject (textureTargetToGetPName t))
      (glBindTexture (marshalTextureTarget t) . textureID)

textureTargetToGetPName :: TextureTarget -> GetPName
textureTargetToGetPName x = case x of
    Texture1D -> GetTextureBinding1D
    Texture2D -> GetTextureBinding2D
    Texture3D -> GetTextureBinding3D
    TextureCubeMap -> GetTextureBindingCubeMap
    TextureRectangle -> GetTextureBindingRectangle

foreign import CALLCONV unsafe "glBindTexture"
   glBindTexture :: GLenum -> GLuint -> IO ()

--------------------------------------------------------------------------------

areTexturesResident :: [TextureObject] -> IO ([TextureObject],[TextureObject])
areTexturesResident texObjs = do
   let len = length texObjs
   withArray (map textureID texObjs) $ \texObjsBuf ->
      allocaArray len $ \residentBuf -> do
         allResident <-
            glAreTexturesResident (fromIntegral len) texObjsBuf residentBuf
         if unmarshalGLboolean allResident
            then return (texObjs, [])
            else do
               tr <- liftM (zip texObjs) $ peekArray len residentBuf
               let (resident, nonResident) = partition (unmarshalGLboolean . snd) tr
               return (map fst resident, map fst nonResident)

foreign import CALLCONV unsafe "glAreTexturesResident"
   glAreTexturesResident :: GLsizei -> Ptr GLuint -> Ptr GLboolean -> IO GLboolean

--------------------------------------------------------------------------------

prioritizeTextures :: [(TextureObject,GLclampf)] -> IO ()
prioritizeTextures tps =
   withArray (map (textureID . fst) tps) $ \texObjsBuf ->
      withArray (map snd tps) $
         glPrioritizeTextures (genericLength tps) texObjsBuf

foreign import CALLCONV unsafe "glPrioritizeTextures"
   glPrioritizeTextures :: GLsizei -> Ptr GLuint -> Ptr GLclampf -> IO ()