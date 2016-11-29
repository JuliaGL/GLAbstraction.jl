# Uniforms are OpenGL variables that stay the same for the entirety of a drawcall.
# There are a lot of functions, to upload them, as OpenGL doesn't rely on multiple dispatch.
# here is my approach, to handle all of the uniforms with one function, namely gluniform
# For uniforms, the Vector and Matrix types from ImmutableArrays should be used, as they map the relation almost 1:1

GLSL_COMPATIBLE_NUMBER_TYPES = (GLfloat, GLint, GLuint, GLdouble)
const NATIVE_TYPES = Union{
    StaticArray, GLSL_COMPATIBLE_NUMBER_TYPES...,
    GLBuffer, GPUArray, Shader, GLProgram, NativeMesh
}

opengl_prefix(T)  = error("Object $T is not a supported uniform element type")
opengl_postfix(T) = error("Object $T is not a supported uniform element type")


opengl_prefix{T <: Union{FixedPoint, Float32, Float16}}(x::Type{T})  = ""
opengl_prefix{T <: Float64}(x::Type{T})                     = "d"
opengl_prefix(x::Type{Cint})                                = "i"
opengl_prefix{T <: Union{Cuint, UInt8, UInt16}}(x::Type{T}) = "u"

opengl_postfix(x::Type{Float64}) = "dv"
opengl_postfix(x::Type{Float32}) = "fv"
opengl_postfix(x::Type{Cint})    = "iv"
opengl_postfix(x::Type{Cuint})   = "uiv"


function uniformfunc(typ::DataType, dims::Tuple{Int})
    Symbol(string("glUniform", first(dims), opengl_postfix(typ)))
end
function uniformfunc(typ::DataType, dims::Tuple{Int, Int})
    M, N = dims
    Symbol(string("glUniformMatrix", M==N ? "$M":"$(M)x$(N)", opengl_postfix(typ)))
end

function gluniform{FSA <: Union{StaticArray, Colorant}}(location::Integer, x::FSA)
    x = [x]
    gluniform(location, x)
end

Base.size(p::Colorant) = (length(p),)
Base.size{T <: Colorant}(p::Type{T}) = (length(p),)
Base.ndims{T <: Colorant}(p::Type{T}) = 1

@generated function gluniform{FSA <: Union{StaticArray, Colorant}}(location::Integer, x::Vector{FSA})
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
gluniform(location::Integer, target::Integer, t::TextureBuffer) = gluniform(GLint(location), GLint(target), t.texture)
function gluniform(location::GLint, target::GLint, t::Texture)
    activeTarget = GL_TEXTURE0 + UInt32(target)
    glActiveTexture(activeTarget)
    glBindTexture(t.texturetype, t.id)
    gluniform(location, target)
end
gluniform(location::Integer, x::Enum) 	 						     = gluniform(GLint(location), GLint(x))
gluniform(location::Integer, x::Signal)                              = gluniform(GLint(location), value(x))
gluniform(location::Integer, x::Union{GLubyte, GLushort, GLuint}) 	 = glUniform1ui(GLint(location), x)
gluniform(location::Integer, x::Union{GLbyte, GLshort, GLint, Bool}) = glUniform1i(GLint(location),  x)
gluniform(location::Integer, x::GLfloat)                             = glUniform1f(GLint(location),  x)
gluniform(location::Integer, x::GLdouble)                            = glUniform1d(GLint(location),  x)

#Uniform upload functions for julia arrays...
gluniform(location::GLint, x::Vector{Float32}) = glUniform1fv(location,  length(x), pointer(x))
gluniform(location::GLint, x::Vector{GLdouble}) = glUniform1dv(location,  length(x), pointer(x))
gluniform(location::GLint, x::Vector{GLint})   = glUniform1iv(location,  length(x), pointer(x))
gluniform(location::GLint, x::Vector{GLuint})  = glUniform1uiv(location, length(x), pointer(x))


glsl_typename{T}(x::T)           = glsl_typename(T)
glsl_typename(t::Type{Void})     = "Nothing"
glsl_typename(t::Type{GLfloat})  = "float"
glsl_typename(t::Type{GLdouble}) = "double"
glsl_typename(t::Type{GLuint})   = "uint"
glsl_typename(t::Type{GLint})    = "int"
glsl_typename{T<:Union{StaticVector, Colorant}}(t::Type{T}) = string(opengl_prefix(eltype(t)), "vec", length(t))
glsl_typename{T}(t::Type{TextureBuffer{T}}) = string(opengl_prefix(eltype(T)), "samplerBuffer")

function glsl_typename{T, D}(t::Texture{T, D})
    str = string(opengl_prefix(eltype(T)), "sampler", D, "D")
    t.texturetype == GL_TEXTURE_2D_ARRAY && (str *= "Array")
    str
end
function glsl_typename{T <: SMatrix}(t::Type{T})
    M, N = size(t)
    string(opengl_prefix(eltype(t)), "mat", M==N ? M : string(M, "x", N))
end
toglsltype_string(t::Signal) = toglsltype_string(t.value)
toglsltype_string{T<:Union{Real, StaticArray, Texture, Colorant, TextureBuffer, Void}}(x::T) = "uniform $(glsl_typename(x))"
#Handle GLSL structs, which need to be addressed via single fields
function toglsltype_string{T}(x::T)
    if isa_gl_struct(x)
        string("uniform ", T.name.name)
    else
        error("can't splice $T into an OpenGL shader. Make sure all fields are of a concrete type and isbits(FieldType)-->true")
    end
end
toglsltype_string{T}(t::Union{GLBuffer{T}, GPUVector{T}}) = string("in ", glsl_typename(T))
# Gets used to access a
function glsl_variable_access{T,D}(keystring, t::Texture{T, D})
    fields = SubString("rgba", 1, length(T))
    if t.texturetype == GL_TEXTURE_BUFFER
        return string("texelFetch(", keystring, "index).", fields, ";")
    end
    return string("getindex(", keystring, "index).", fields, ";")
end
function glsl_variable_access(keystring, ::Union{Real, GLBuffer, GPUVector, StaticArray, Colorant})
    string(keystring, ";")
end
function glsl_variable_access(keystring, s::Signal)
    glsl_variable_access(keystring, s.value)
end
function glsl_variable_access(keystring, t::Any)
    error("no glsl variable calculation available for : ", keystring, " of type ", typeof(t))
end

function uniform_name_type(program::GLuint)
    uniformLength = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)
    Dict{Symbol, GLenum}(ntuple(uniformLength) do i # take size and name
        name, typ = glGetActiveUniform(program, i-1)
    end)
end
function attribute_name_type(program::GLuint)
    uniformLength = glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES)
    Dict{Symbol, GLenum}(ntuple(uniformLength) do i
    	name, typ = glGetActiveAttrib(program, i-1)
    end)
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


gl_promote{T <: StaticVector}(x::Type{T}) = similar_type(T, gl_promote(eltype(T)))

gl_promote{T <: HomogenousMesh}(x::Type{T}) = NativeMesh{T}


gl_convert{T <: Number}(x::T) = gl_promote(T)(x)
gl_convert{T <: Colorant}(x::T) = gl_promote(T)(x)
gl_convert{T <: AbstractMesh}(x::T) = gl_convert(convert(GLNormalMesh, x))
gl_convert{T <: HomogenousMesh}(x::T) = gl_promote(T)(x)
gl_convert{T <: HomogenousMesh}(x::Signal{T}) = gl_promote(T)(x)

gl_convert{T<:Colorant}(s::Vector{Matrix{T}}) = Texture(s)
gl_convert(s::AABB) = s
gl_convert(s::Void) = s

isa_gl_struct(x::Array) = false
isa_gl_struct(x::NATIVE_TYPES) = false
isa_gl_struct(x::Colorant) = false
function isa_gl_struct{T}(x::T)
    !isleaftype(T) && return false
    if T <: Tuple
        return false
    end
    fnames = fieldnames(T)
    !isempty(fnames) && all(name -> isleaftype(fieldtype(T, name)) && isbits(getfield(x, name)), fnames)
end
function gl_convert_struct{T}(x::T, uniform_name::Symbol)
    if isa_gl_struct(x)
        return Dict{Symbol, Any}(map(fieldnames(x)) do name
            (Symbol("$uniform_name.$name") => gl_convert(getfield(x, name)))
        end)
    else
        error("can't convert $x to a OpenGL type. Make sure all fields are of a concrete type and isbits(FieldType)-->true")
    end
end


# native types don't need convert!
gl_convert{T <: NATIVE_TYPES}(a::T) = a

gl_convert{T <: NATIVE_TYPES}(s::Signal{T}) = s
gl_convert{T}(s::Signal{T}) = const_lift(gl_convert, s)

gl_convert{T}(x::StaticVector{T}) = map(gl_promote(T), x)
gl_convert{N, M, T}(x::SMatrix{N, M, T}) = map(gl_promote(T), x)


gl_convert{T <: Face}(a::Vector{T}) = indexbuffer(s)
gl_convert{T <: NATIVE_TYPES}(::Type{T}, a::NATIVE_TYPES; kw_args...) = a
function gl_convert{T <: GPUArray, X, N}(::Type{T}, a::Array{X, N}; kw_args...)
    T(map(gl_promote(X), a); kw_args...)
end
function gl_convert{T <: Texture, X}(::Type{T}, a::Vector{Array{X, 2}}; kw_args...)
    T(a; kw_args...)
end

function gl_convert{T <: GPUArray, X, N}(::Type{T}, a::Signal{Array{X, N}}; kw_args...)
    TGL = gl_promote(X)
    s = (X == TGL) ? a : const_lift(map, TGL, a)
    T(s; kw_args...)
end

gl_convert(f::Function, a) = f(a)
