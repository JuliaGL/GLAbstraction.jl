module GLAbstraction

using Quaternions
import Quaternions.normalize

using AbstractGPUArray
using FixedSizeArrays
using GeometryTypes
using ModernGL
using Reactive
using FixedPointNumbers
using ColorTypes
using Compat
#import Images: imread, colorspace, Image, AbstractGray, RGB4, ARGB, Images
#import Lumberjack
import Mustache



include("GLUtils.jl")
export @gputime
export @file_str
export File


include("GLInit.jl")
export init_after_context_creation
export init_glutils
export get_glsl_version_string
export get_glsl_in_qualifier_string
export get_glsl_out_qualifier_string


include("GLTypes.jl")
export GLProgram                # Shader/program object
export Texture                  # Texture object, basically a 1/2/3D OpenGL data array
export update!                  # gets the data of texture as a Julia Array
export data
export AbstractFixedVector      # First step into the direction of integrating FixedSizeArrays
export RenderObject             # An object which holds all GPU handles and datastructes to ready for rendering by calling render(obj)
export prerender!               # adds a function to a RenderObject, which gets executed befor setting the OpenGL render state
export postrender!              # adds a function to a RenderObject, which gets executed after setting the OpenGL render states
export instancedobject          # simplification for creating a RenderObject which renders instances
export GLVertexArray            # VertexArray wrapper object
export GLBuffer                 # OpenGL Buffer object wrapper
export indexbuffer              # Shortcut to create an OpenGL Buffer object for indexes (1D, cardinality of one and GL_ELEMENT_ARRAY_BUFFER set)
export opengl_compatible        # infers if a type is opengl compatible and returns stats like cardinality and eltype (will be deprecated)
export cardinality              # returns the cardinality of the elements of a buffer
export Circle                   # Simple circle object
export Rectangle                # Simple rectangle object
export AABB                		# bounding slab
export Shape                    # Abstract shape type
export setindex1D!              # Sets the index of an Array{FixedSizeVector, x}, making the FixedSizeVector accessible via an index
export Style                    # Style Type, which is used to choose different visualization/editing styles via multiple dispatch
export mergedefault!            # merges a style dict via a given style



#Methods which got overloaded by GLExtendedFunctions.jl:
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
import ModernGL.glViewport
import ModernGL.glGenRenderbuffers
import ModernGL.glDeleteTextures
import ModernGL.glDeleteVertexArrays
import ModernGL.glDeleteBuffers


include("GLExtendedFunctions.jl")
export glTexImage

include("GLUniforms.jl")
export gluniform                # wrapper of all the OpenGL gluniform functions, which call the correct gluniform function via multiple dispatch. Example: gluniform(location, x::Matrix4x4) = gluniformMatrix4fv(location, x)
export toglsltype_string        # infers a glsl type string from a julia type. Example: Matrix4x4 -> uniform mat4
# Also exports Macro generated GLSL alike aliases for Float32 Matrices and Vectors
# only difference to GLSL: first character is uppercase uppercase

include("GLMatrixMath.jl")
export scalematrix 
export lookat
export perspectiveprojection
export orthographicprojection
export translationmatrix, translatematrix_y, translatematrix_z
export rotationmatrix_x, rotationmatrix_y, rotationmatrix_z
export rotation
export qrotation    # quaternion rotation
export transformationmatrix
export Pivot # Pivot object, putting axis, scale position into one object
export rotationmatrix4 # returns a 4x4 rotation matrix
export perspective


include("GLRender.jl")
export render 
export enabletransparency
export renderinstanced

include("GLShader.jl")
export readshader
export glsl_variable_access
export createview
export TemplateProgram # Creates a shader from a Mustache view and and a shader file, which uses mustache syntax to replace values.
export @comp_str
export @frag_str
export @vert_str
export @geom_str


include("GLCamera.jl")
export OrthographicCamera
export PerspectiveCamera
export OrthographicPixelCamera

include("GLShapes.jl")
export gencircle
export genquadstrip
export isinside
export gencube
export genquad
export gencubenormals
export mergemesh


include("GLInfo.jl")
export getUniformsInfo
export getProgramInfo
export getAttributesInfo
end # module
