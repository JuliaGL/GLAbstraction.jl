using GLAbstraction, GeometryTypes, ModernGL, GLWindow
using Base.Test

global const window = createwindow("Mesh Display", 1000, 1000, debugging = false)
N = 100



intensity2Df 	= Texture(Float32[0 for i=1:N, j=1:N])
intensity2Di 	= Texture(Cint[0 for i=1:N, j=1:N])
intensity2Dui 	= Texture(Cuint[0 for i=1:N, j=1:N])

rg2Df 	= Texture([Vec2(0) for i=1:N, j=1:N])
rg2Di 	= Texture([iVec2(0) for i=1:N, j=1:N])
rg2Dui 	= Texture([uVec2(0f0) for i=1:N, j=1:N])

rgb2Df 	= Texture([Vec3(0) for i=1:N, j=1:N])
rgb2Di 	= Texture([iVec3(0) for i=1:N, j=1:N])
rgb2Dui = Texture([uVec3(0f0) for i=1:N, j=1:N])

rgba2Df = Texture([Vec4(0) for i=1:N, j=1:N])
rgba2Di = Texture([iVec4(0) for i=1:N, j=1:N])
rgba2Dui = Texture([uVec4(0f0) for i=1:N, j=1:N])


z = Matrix{Vec4}[Vec4[Vec4(0f0) for i=1:N, j=1:N] for i=1:10]
arraytexture = Texture(z)


texparams = [
   (GL_TEXTURE_MIN_FILTER, GL_LINEAR),
  (GL_TEXTURE_MAG_FILTER, GL_LINEAR),
  (GL_TEXTURE_WRAP_S,  GL_CLAMP_TO_EDGE),
  (GL_TEXTURE_WRAP_T,  GL_CLAMP_TO_EDGE)
 ]

@test toglsltype_string(intensity2Df) 	== "uniform sampler2D" 
@test toglsltype_string(rg2Df) 			== "uniform sampler2D" 
@test toglsltype_string(rgb2Df) 		== "uniform sampler2D" 
@test toglsltype_string(rgba2Df) 		== "uniform sampler2D" 


@test typeof(intensity2Df).parameters == (Float32, 2)
@test typeof(rgba2Df).parameters == (Vec4, 2)
