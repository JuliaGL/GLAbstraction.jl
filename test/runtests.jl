using Test
using GLAbstraction, GeometryBasics, ModernGL, GLFW, StaticArrays
using ColorTypes

window = GLFW.Window()
GLAbstraction.set_context!(window)

include("accessors.jl")
include("uniforms.jl")
include("texture.jl")

# Test for creating a Buffer with a 1D Julia Array
# You need to supply the cardinality, as it can't be inferred
# indexbuffer is a shortcut for Buffer(GLUInt[0,1,2,2,3,0], 1, buffertype = GL_ELEMENT_ARRAY_BUFFER)
# Test for creating a Buffer with a 1D Julia Array of Vectors
#v = Vec2f[Vec2f(0.0, 0.5), Vec2f(0.5, -0.5), Vec2f(-0.5,-0.5)]

# v = Vec2f0[Vec2f0(0.0, 0.5), Vec2f0(0.5, -0.5), Vec2f0(-0.5,-0.5)]

# verts = Buffer(v)
# @test size(verts, 1) == 3
# @test size(verts, 2) == 1

# # lets define some uniforms
# # uniforms are shader variables, which are supposed to stay the same for an entire draw call
# cd(dirname(@__FILE__))
# const triangle = std_renderobject(
#     Dict(
#         :vertex => verts,
#         :name_doesnt_matter_for_indexes => indexes
#     ),
#     LazyShader("test.vert", "test.frag")
# )

# glClearColor(0,0,0,1)
# i = 1
# while isopen(window) && i < 20
#     glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
#     GLAbstraction.render(triangle)
#     swapbuffers(window)
#     poll_glfw()
#     sleep(0.01)
#     i += 1
# end
# GLFW.DestroyWindow(window)

