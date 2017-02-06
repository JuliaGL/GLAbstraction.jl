using GLAbstraction, GeometryTypes, ModernGL, Compat, FileIO, GLWindow
using FixedSizeArrays, ColorTypes
using Base.Test
import GLAbstraction: N0f8

function is_ci()
    get(ENV, "TRAVIS", "") == "true" ||
    get(ENV, "APPVEYOR", "") == "true" ||
    get(ENV, "CI", "") == "true"
end

include("macro_test.jl")

if true # only do test if not CI... this is for automated testing environments which fail for OpenGL stuff, but I'd like to test if at least including works

window = create_glcontext("test", resolution = (500,500), major = 3, minor = 0)

include("accessors.jl")
include("uniforms.jl")
include("texture.jl")
include("macro_test.jl")

# Test for creating a GLBuffer with a 1D Julia Array
# You need to supply the cardinality, as it can't be inferred
# indexbuffer is a shortcut for GLBuffer(GLUInt[0,1,2,2,3,0], 1, buffertype = GL_ELEMENT_ARRAY_BUFFER)
indexes = indexbuffer(GLuint[0,1,2])
# Test for creating a GLBuffer with a 1D Julia Array of Vectors
#v = Vec2f[Vec2f(0.0, 0.5), Vec2f(0.5, -0.5), Vec2f(-0.5,-0.5)]

v = Vec2f0[Vec2f0(0.0, 0.5), Vec2f0(0.5, -0.5), Vec2f0(-0.5,-0.5)]

verts = GLBuffer(v)
@test size(verts, 1) == 3
@test size(verts, 2) == 1

# lets define some uniforms
# uniforms are shader variables, which are supposed to stay the same for an entire draw call
cd(dirname(@__FILE__))
const triangle = std_renderobject(
    Dict(
        :vertex => verts,
        :name_doesnt_matter_for_indexes => indexes
    ),
    LazyShader("test.vert", "test.frag")
)

glClearColor(0,0,0,1)
for i=1:100
  	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    GLAbstraction.render(triangle)
    swapbuffers(window)
    poll_glfw()
    sleep(0.01)
end
GLFW.DestroyWindow(window)

end
