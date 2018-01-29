VERSION >= v"0.4.0-dev+6521" && __precompile__()
module GLAbstraction

using StaticArrays
using ModernGL
using FixedPointNumbers
using ColorTypes

import FileIO: load, save

import FixedPointNumbers: N0f8, N0f16, N0f8, Normed

import Base: merge, resize!, unsafe_copy!, similar, length, getindex, setindex!

include("context.jl")

include("AbstractGPUArray.jl")

#Methods which get overloaded by GLExtendedFunctions.jl:
import ModernGL.glShaderSource
import ModernGL.glGetAttachedShaders
import ModernGL.glGetActiveUniform
import ModernGL.glGetActiveAttrib
import ModernGL.glGetProgramiv
import ModernGL.glGetIntegerv
import ModernGL.glGenBuffers
import ModernGL.glGetProgramiv
import ModernGL.glGenVertexArrays
import ModernGL.glGenTextures
import ModernGL.glGenFramebuffers
import ModernGL.glGetTexLevelParameteriv
import ModernGL.glGenRenderbuffers
import ModernGL.glDeleteTextures
import ModernGL.glDeleteVertexArrays
import ModernGL.glDeleteBuffers
import ModernGL.glGetShaderiv
import ModernGL.glViewport
import ModernGL.glScissor

include("utils.jl")
export @gputime # measures the time an OpenGL call takes on the GPU (usually OpenGL calls return immidiately)
include("buffer.jl")
include("texture.jl")
include("framebuffer.jl")
include("vertexarray.jl")
include("uniformbuffer.jl")

include("shader/uniforms.jl")
include("shader/shader.jl")
include("shader/program.jl")
include("shader/glsl_typenames.jl")
include("renderpass.jl")
include("conversions.jl")
export gluniform                # wrapper of all the OpenGL gluniform functions, which call the correct gluniform function via multiple dispatch. Example: gluniform(location, x::Matrix4x4) = gluniformMatrix4fv(location, x)
export toglsltype_string        # infers a glsl type string from a julia type. Example: Matrix4x4 -> uniform mat4
# Also exports Macro generated GLSL alike aliases for Float32 Matrices and Vectors
# only difference to GLSL: first character is uppercase uppercase
export gl_convert


export Texture                  # Texture object, basically a 1/2/3D OpenGL data array
export TextureParameters
export TextureBuffer            # OpenGL texture buffer
export update!                  # updates a gpu array with a Julia array
export gpu_data                 # gets the data of a gpu array as a Julia Array

export RenderObject             # An object which holds all GPU handles and datastructes to ready for rendering by calling render(obj)
export prerender!               # adds a function to a RenderObject, which gets executed befor setting the OpenGL render state
export postrender!              # adds a function to a RenderObject, which gets executed after setting the OpenGL render states
export std_renderobject            # creates a renderobject with standard parameters
export instanced_renderobject    # simplification for creating a RenderObject which renders instances
export set_arg!
export GLVertexArray            # VertexArray wrapper object
export Buffer                 # OpenGL Buffer object wrapper
export indexbuffer              # Shortcut to create an OpenGL Buffer object for indexes (1D, cardinality of one and GL_ELEMENT_ARRAY_BUFFER set)
export opengl_compatible        # infers if a type is opengl compatible and returns stats like cardinality and eltype (will be deprecated)
export cardinality              # returns the cardinality of the elements of a buffer

include("for_moderngl.jl")
export Shader                 #Shader Type
export @comp_str #string macro for the different shader types.
export @frag_str # with them you can write frag""" ..... """, returning shader object
export @vert_str
export @geom_str

dir(dirs...) = joinpath(dirname(@__FILE__), "..", dirs...)

end # module
