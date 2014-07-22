using GLAbstraction, ImmutableArrays, ModernGL, GLWindow, Images, Color
using Base.Test

global const window = createwindow("Mesh Display", 1000, 1000, debugging = false)
N = 100


intensity2Df = Texture([vec1(0) for i=1:N, j=1:N])
intensity2Di = Texture([ivec1(0) for i=1:N, j=1:N])
intensity2Dui = Texture([uivec1(0f0) for i=1:N, j=1:N])

rg2Df = Texture([vec2(0) for i=1:N, j=1:N])
rg2Di = Texture([ivec2(0) for i=1:N, j=1:N])
rg2Dui = Texture([uivec2(0f0) for i=1:N, j=1:N])

rgb2Df = Texture([vec3(0) for i=1:N, j=1:N])
rgb2Di = Texture([ivec3(0) for i=1:N, j=1:N])
rgb2Dui = Texture([uivec3(0f0) for i=1:N, j=1:N])

rgba2Df = Texture([vec4(0) for i=1:N, j=1:N])
rgba2Di = Texture([ivec4(0) for i=1:N, j=1:N])
rgba2Dui = Texture([uivec4(0f0) for i=1:N, j=1:N])





texparams = [
   (GL_TEXTURE_MIN_FILTER, GL_LINEAR),
  (GL_TEXTURE_MAG_FILTER, GL_LINEAR),
  (GL_TEXTURE_WRAP_S,  GL_CLAMP_TO_EDGE),
  (GL_TEXTURE_WRAP_T,  GL_CLAMP_TO_EDGE)
 ]


@test toglsl(intensity2Df) == "sampler2D" 
@test toglsl(rg2Df) == "sampler2D" 
@test toglsl(rgb2Df) == "sampler2D" 
@test toglsl(rgba2Df) == "sampler2D" 


@test typeof(intensity2Df).parameters == (Float32, 1,2)
@test typeof(rgba2Df).parameters == (Float32, 4,2)
