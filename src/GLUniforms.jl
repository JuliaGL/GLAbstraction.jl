# Uniforms are OpenGL variables that stay the same for the entirety of a drawcall.
# There are a lot of functions, to upload them, as OpenGL doesn't rely on multiple dispatch.
# here is my approach, to handle all of the uniforms with one function, namely gluniform
# For uniforms, the Vector and Matrix types from ImmutableArrays should be used, as they map the relation almost 1:1

GLSL_COMPATIBLE_NUMBER_TYPES = (GLdouble, GLfloat, GLint, GLuint)

opengl_prefix(T)  = error("Object $T is not a supported uniform element type")
opengl_postfix(T) = error("Object $T is not a supported uniform element type")



opengl_prefix{T <: Union{FixedPoint, Float32}}(x::Type{T})  = ""
opengl_prefix{T <: Float64}(x::Type{T})                     = "d"
opengl_prefix(x::Type{Cint})                                = "i"
opengl_prefix{T <: Union{Cuint, UInt8, UInt16}}(x::Type{T}) = "u"

opengl_postfix(x::Type{Float64}) = "dv"
opengl_postfix(x::Type{Float32}) = "fv"
opengl_postfix(x::Type{Cint})    = "iv"
opengl_postfix(x::Type{Cuint})   = "uiv"


uniformfunc(typ::DataType, dims::Tuple{Int}) =
    symbol(string("glUniform", first(dims), opengl_postfix(typ)))

function uniformfunc(typ::DataType, dims::Tuple{Int, Int})
    M, N = dims
    func = symbol(string("glUniformMatrix", M==N ? "$M":"$(M)x$(N)", opengl_postfix(typ)))
end

function gluniform{FSA <: Union{FixedArray, Colorant}}(location::Integer, x::FSA)
    x = [x]
    gluniform(location, x)
end

Base.size(p::Colorant) = (length(p),)
Base.size{T <: Colorant}(p::Type{T}) = (length(p),)
Base.ndims{T <: Colorant}(p::Type{T}) = 1

@generated function gluniform{FSA <: Union{FixedArray, Colorant}}(location::Integer, x::Vector{FSA})
    func = uniformfunc(eltype(FSA), size(FSA))
    if ndims(FSA) == 2
        :($func(location, length(x), GL_FALSE, pointer(x)))
    else
        :($func(location, length(x), pointer(x)))
    end
end


#Some additional uniform functions, not related to Imutable Arrays
gluniform(location::Integer, target::Integer, t::Texture)   = gluniform(GLint(location), GLint(target), t)
gluniform(location::Integer, target::Integer, t::GPUVector) = gluniform(GLint(location), GLint(target), t.buffer)
gluniform(location::Integer, target::Integer, t::Signal)    = gluniform(GLint(location), GLint(target), t.value)
function gluniform(location::GLint, target::GLint, t::Texture)
    activeTarget = GL_TEXTURE0 + UInt32(target)
    glActiveTexture(activeTarget)
    glBindTexture(t.texturetype, t.id)
    gluniform(location, target)
end
gluniform(location::Integer, x::Signal)                              = gluniform(GLint(location),    value(x))
gluniform(location::Integer, x::Union{GLubyte, GLushort, GLuint}) 	 = glUniform1ui(GLint(location), x)
gluniform(location::Integer, x::Union{GLbyte, GLshort, GLint, Bool}) = glUniform1i(GLint(location),  x)
gluniform(location::Integer, x::GLfloat)                             = glUniform1f(GLint(location),  x)
gluniform(location::Integer, x::Enum) 	 						     = glUniform1f(GLint(location),  GLint(x))


#Uniform upload functions for julia arrays...
gluniform(location::GLint, x::Vector{Float32}) = glUniform1fv(location,  length(x), pointer(x))
gluniform(location::GLint, x::Vector{GLint})   = glUniform1iv(location,  length(x), pointer(x))
gluniform(location::GLint, x::Vector{GLuint})  = glUniform1uiv(location, length(x), pointer(x))



function toglsltype_string{T, D}(t::Texture{T, D})
    if isnull(t.buffer)
        string("uniform ", opengl_prefix(eltype(T)),"sampler", D, "D")
    else
        string("uniform ", opengl_prefix(eltype(T)),"samplerBuffer")
    end
end
toglsltype_string(t::Nothing)                   = "uniform Nothing"
toglsltype_string(t::GLfloat)                   = "uniform float"
toglsltype_string(t::GLuint)                    = "uniform uint"
toglsltype_string(t::GLint)                     = "uniform int"
toglsltype_string(t::Signal)                    = toglsltype_string(t.value)
toglsltype_string(t::StepRange)                 = toglsltype_string(Vec3(first(t), step(t), last(t)))

toglsltype_string(t::FixedVector)               = "uniform " * string(opengl_prefix(eltype(t)), "vec", length(t))
toglsltype_string(t::Colorant)                  = "uniform " * string(opengl_prefix(eltype(t)), "vec", length(t))
function toglsltype_string(t::FixedMatrix)
    M,N = size(t)
    string(opengl_prefix(eltype(t)),"mat", M==N ? "$M" : "$(M)x$(N)")
end

function toglsltype_string(t::GLBuffer)
    typ = cardinality(t) > 1 ? "vec$(cardinality(t))" : "float"
    "in $typ"
end
# Gets used to access a
function glsl_variable_access{T,D}(keystring, t::Texture{T, D})
    t.texturetype == GL_TEXTURE_BUFFER && return "texelFetch($(keystring), index)."*"rgba"[1:length(T)]*";"
    return "getindex($(keystring), index)."*"rgba"[1:length(T)]*";"
end

glsl_variable_access(keystring, ::Union{Real, GLBuffer, FixedArray, Colorant}) = keystring*";"

glsl_variable_access(keystring, s::Signal) = glsl_variable_access(keystring, s.value)
glsl_variable_access(keystring, t::Any)    = error("no glsl variable calculation available for : ", keystring, " of type ", typeof(t))


UNIFORM_TYPES = FixedArray

# This is needed to varify, that the correct uniform is uploaded to a shader
# Should partly be integrated into the genuniformfunctions macro
iscorrect(a, b) = false

is_unsigned_uniform_type{T}(::Type{T}) = eltype(T) <: Unsigned
is_integer_uniform_type{T}(::Type{T}) = eltype(T) <: Integer
is_float_uniform_type{T}(::Type{T}) = eltype(T) <: AbstractFloat || eltype(T) <: FixedPoint
is_bool_uniform_type{T}(::Type{T}) = eltype(T) <: Bool || is_integer_uniform_type(T)


iscorrect{AnySym}(x::Signal, glenum::GLENUM{AnySym, GLenum}) = iscorrect(x.value, glenum)

iscorrect(x::Real, ::GLENUM{:GL_BOOL, GLenum})                              = is_bool_uniform_type(typeof(x))
iscorrect(x::Real, ::GLENUM{:GL_UNSIGNED_INT, GLenum})                      = is_unsigned_uniform_type(typeof(x))
iscorrect(x::Real, ::GLENUM{:GL_INT, GLenum})                               = is_integer_uniform_type(typeof(x))
iscorrect(x::Real, ::GLENUM{:GL_FLOAT, GLenum})                             = is_float_uniform_type(typeof(x))

iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_BOOL, GLenum})              = is_bool_uniform_type(T) && length(T) == 1
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_BOOL_VEC2, GLenum})         = is_bool_uniform_type(T) && length(T) == 2
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_BOOL_VEC3, GLenum})         = is_bool_uniform_type(T) && length(T) == 3
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_BOOL_VEC4, GLenum})         = is_bool_uniform_type(T) && length(T) == 4


iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_UNSIGNED_INT, GLenum})      = is_unsigned_uniform_type(T) && length(T) == 1
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_UNSIGNED_INT_VEC2, GLenum}) = is_unsigned_uniform_type(T) && length(T) == 2
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_UNSIGNED_INT_VEC3, GLenum}) = is_unsigned_uniform_type(T) && length(T) == 3
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_UNSIGNED_INT_VEC4, GLenum}) = is_unsigned_uniform_type(T) && length(T) == 4

iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_INT, GLenum})               = is_integer_uniform_type(T) && length(T) == 1
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_INT_VEC2, GLenum})          = is_integer_uniform_type(T) && length(T) == 2
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_INT_VEC3, GLenum}) = is_integer_uniform_type(T) && length(T) == 3
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_INT_VEC4, GLenum}) = is_integer_uniform_type(T) && length(T) == 4

iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT, GLenum})      = is_float_uniform_type(T) && length(T) == 1
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_VEC2, GLenum}) = is_float_uniform_type(T) && length(T) == 2
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_VEC3, GLenum}) = is_float_uniform_type(T) && length(T) == 3
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_VEC4, GLenum}) = is_float_uniform_type(T) && length(T) == 4

iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT2, GLenum}) = is_float_uniform_type(T) && size(T) == (2,2)
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT3, GLenum}) = is_float_uniform_type(T) && size(T) == (3,3)
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT4, GLenum}) = is_float_uniform_type(T) && size(T) == (4,4)

iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT3x2, GLenum}) = is_float_uniform_type(T) && size(T) == (3,2)
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT4x2, GLenum}) = is_float_uniform_type(T) && size(T) == (4,2)

iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT2x3, GLenum}) = is_float_uniform_type(T) && size(T) == (2,3)
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT4x3, GLenum}) = is_float_uniform_type(T) && size(T) == (4,3)

iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT2x3, GLenum}) = is_float_uniform_type(T) && size(T) == (2,3)
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT4x3, GLenum}) = is_float_uniform_type(T) && size(T) == (4,3)

iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT2x4, GLenum}) = is_float_uniform_type(T) && size(T) == (2,4)
iscorrect{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT3x4, GLenum}) = is_float_uniform_type(T) && size(T) == (3,4)

iscorrect{T}(::Texture{T, 1}, ::GLENUM{:GL_SAMPLER_1D, GLenum}) = is_float_uniform_type(T)
iscorrect{T}(::Texture{T, 2}, ::GLENUM{:GL_SAMPLER_2D, GLenum}) = is_float_uniform_type(T)
iscorrect{T}(::Texture{T, 3}, ::GLENUM{:GL_SAMPLER_3D, GLenum}) = is_float_uniform_type(T)

iscorrect{T}(::Texture{T, 1}, ::GLENUM{:GL_UNSIGNED_INT_SAMPLER_1D, GLenum}) = is_unsigned_uniform_type(T)
iscorrect{T}(::Texture{T, 2}, ::GLENUM{:GL_UNSIGNED_INT_SAMPLER_2D, GLenum}) = is_unsigned_uniform_type(T)
iscorrect{T}(::Texture{T, 3}, ::GLENUM{:GL_UNSIGNED_INT_SAMPLER_3D, GLenum}) = is_unsigned_uniform_type(T)

iscorrect{T}(::Texture{T, 1}, ::GLENUM{:GL_INT_SAMPLER_1D, GLenum}) = is_integer_uniform_type(T)
iscorrect{T}(::Texture{T, 2}, ::GLENUM{:GL_INT_SAMPLER_2D, GLenum}) = is_integer_uniform_type(T)
iscorrect{T}(::Texture{T, 3}, ::GLENUM{:GL_INT_SAMPLER_3D, GLenum}) = is_integer_uniform_type(T)




function uniform_type(targetuniform::GLenum)
    if haskey(UNIFORM_TYPE_ENUM_DICT, targetuniform)
        return UNIFORM_TYPE_ENUM_DICT[targetuniform]
    else
        error("Unrecognized Uniform Enum. Enum found: ", GLENUM(targetuniform).name)
    end
end

function uniform_name_type(program::GLuint)
    uniformLength = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)
    if uniformLength == 0
        return Dict{Symbol, GLenum}()
    else
        nametypelist = ntuple(i -> glGetActiveUniform(program, i-1)[1:2], uniformLength) # take size and name
        return Dict{Symbol, GLenum}(nametypelist)
    end
end
function attribute_name_type(program::GLuint)
    uniformLength = glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES)
    if uniformLength == 0
        return ()
    else
        nametypelist = [begin
        	name, typ = glGetActiveAttrib(program, i-1)
        	name => typ
        	end for i=0:uniformLength-1] # take size and name
        return Dict{Symbol, GLenum}(nametypelist)
    end
end
function istexturesampler(typ::GLenum)
    return (
        typ == GL_SAMPLER_BUFFER || typ == GL_INT_SAMPLER_BUFFER || typ == GL_UNSIGNED_INT_SAMPLER_BUFFER ||
    	typ == GL_IMAGE_2D ||
        typ == GL_SAMPLER_1D || typ == GL_SAMPLER_2D || typ == GL_SAMPLER_3D ||
        typ == GL_UNSIGNED_INT_SAMPLER_1D || typ == GL_UNSIGNED_INT_SAMPLER_2D || typ == GL_UNSIGNED_INT_SAMPLER_3D ||
        typ == GL_INT_SAMPLER_1D || typ == GL_INT_SAMPLER_2D || typ == GL_INT_SAMPLER_3D ||
        typ == GL_SAMPLER_1D_ARRAY || typ == GL_SAMPLER_2D_ARRAY ||
        typ == GL_UNSIGNED_INT_SAMPLER_1D_ARRAY || typ == GL_UNSIGNED_INT_SAMPLER_2D_ARRAY ||
        typ == GL_INT_SAMPLER_1D_ARRAY || typ == GL_INT_SAMPLER_2D_ARRAY
    )
end



const NATIVE_TYPES = Union{FixedArray, GLSL_COMPATIBLE_NUMBER_TYPES..., GLBuffer, Texture}



gl_promote{T <: Integer}(x::Type{T})       = Cint
gl_promote(x::Type{Union{Int16, Int8}})    = x

gl_promote{T <: Unsigned}(x::Type{T})      = Cuint
gl_promote(x::Type{Union{UInt16, UInt8}})  = x

gl_promote{T <: AbstractFloat}(x::Type{T}) = Float32
gl_promote(x::Type{Float16})               = x

gl_promote{T <: UFixed}(x::Type{T})        = UFixed32
gl_promote(x::Type{UFixed16})              = x
gl_promote(x::Type{UFixed8})               = x

typealias Color3{T} Colorant{T, 3}
typealias Color4{T} Colorant{T, 4}

gl_promote(x::Type{Bool})                  = GLboolean
gl_promote{T <: Gray}(x::Type{T})          = Gray{gl_promote(eltype(T))}
gl_promote{T <: Color3}(x::Type{T})        = RGB{gl_promote(eltype(T))}
gl_promote{T <: Color4}(x::Type{T})        = RGBA{gl_promote(eltype(T))}
gl_promote{T <: BGRA}(x::Type{T})          = BGRA{gl_promote(eltype(T))}
gl_promote{T <: BGR}(x::Type{T})           = BGR{gl_promote(eltype(T))}


#native types need no convert
gl_convert(s::Tuple) = map(gl_convert, s)
gl_convert{T <: NATIVE_TYPES}(s::Signal{T}) = s
gl_convert{T}(s::Signal{T}) = const_lift(convert, gl_promote(T), s)

for N=1:4
    @eval gl_convert{T}(x::FixedVector{$N, T}) = map(gl_promote(T), x)
end
for N=1:4, M=1:4
    @eval gl_convert{T}(x::Mat{$N, $M, T}) = map(gl_promote(T), x)
end

gl_convert{T, N}(x::Array{T, N}; kw_args...) = Texture(map(gl_promote(T), x); kw_args...)
gl_convert{T <: Face}(a::Vector{T}) = indexbuffer(s)

gl_convert{T}(::Type{GLBuffer}, a::Vector{T}; kw_args...) = GLBuffer(map(gl_promote(T), x); kw_args...)
gl_convert{T}(::Type{TextureBuffer}, a::Vector{T}; kw_args...) = TextureBuffer(map(gl_promote(T), x); kw_args...)

# native types don't need convert!
gl_convert{T <: NATIVE_TYPES}(a::T) = a


abstract GLEnumArray{T, SZ}
abstract GLEnumUniformArray{T, SZ}  <: GLEnumArray{T, SZ}
abstract GLEnumMatrix{T, M, N}      <: GLEnumUniformArray{T, Tuple{M,N}}
abstract GLEnumVector{T, M}         <: GLEnumUniformArray{T, Tuple{M}}


abstract GLEnumGlobalArray{T, SZ}   <: GLEnumArray{T,   SZ}
abstract GLEnumTexture{T, SZ}       <: GLEnumGlobalArray{T,   SZ}
abstract GLEnumTextureBuffer{T, SZ} <: GLEnumTexture{T, SZ}

abstract GLEnumBuffer{T, SZ}        <: GLEnumGlobalArray{T,   SZ}

for numtype in [("BOOL", GLint), ("INT", GLint), ("UNSIGNED_INT", GLuint), ("FLOAT", GLfloat)], typ in ["MATRIX", "VEC", "SAMPLER", "SAMPLER_BUFFER"]


end
#=
update_convert{T, T2, ND}(globj::GPUArray{T, ND}, value::Array{T2, ND}) = update!(globj, convert(Array{T, ND}, value))
function gl_convert{T, T2, ND}(should_be::GLEnumGlobalArray{T, ND}, is::Signal{Array{T2, ND}})
    globject = gl_convert(should_be, is.value)
    preserve(const_lift(update_convert, globject, is))
    globj
end

gl_convert{T, ND, SZ}(should_be::GLEnumUniformArray{T, SZ},     is::FixedArray{T, ND, SZ})  = is
gl_convert{T, T2, ND, SZ}(should_be::GLEnumUniformArray{T, SZ}, is::FixedArray{T2, ND, SZ}) = convert_elems(T, is)


gl_convert{T, T2, ND, SZ}(should_be::GLEnumTextureBuffer{T, ND}, is::Array{T2, ND}) =
    texture_buffer(convert(Array{T, ND}, is))

gl_convert{T, T2, ND, SZ}(should_be::GLEnumTexture{T, ND}, is::Array{T2, ND}) =
    Texture(convert(Array{T, ND}, is))


gl_convert{T, T2, ND, SZ}(should_be::GLEnumGlobalArray{T, ND}, is::GPUArray{T, ND}) = is

=#
