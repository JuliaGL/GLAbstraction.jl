

########################################################################################
# OpenGL Arrays
"""
Transform julia datatypes to opengl enum type
"""
julia2glenum(x::Type{T}) where {T <: FixedPoint} = julia2glenum(FixedPointNumbers.rawtype(x))
# julia2glenum(x::Type{OffsetInteger{O, T}}) where {O, T} = julia2glenum(T)
julia2glenum(x::Union{Type{T}, T}) where {T <: Union{StaticVector, Colorant}} = julia2glenum(eltype(x))
julia2glenum(x::Type{GLubyte})  = GL_UNSIGNED_BYTE
julia2glenum(x::Type{GLbyte})   = GL_BYTE
julia2glenum(x::Type{GLuint})   = GL_UNSIGNED_INT
julia2glenum(x::Type{GLushort}) = GL_UNSIGNED_SHORT
julia2glenum(x::Type{GLshort})  = GL_SHORT
julia2glenum(x::Type{GLint})    = GL_INT
julia2glenum(x::Type{GLfloat})  = GL_FLOAT
julia2glenum(x::Type{GLdouble}) = GL_DOUBLE
julia2glenum(x::Type{Float16})  = GL_HALF_FLOAT
function julia2glenum(::Type{T}) where T
    error("Type: $T not supported as opengl number datatype")
end

gl_convert(a::T) where {T <: NATIVE_TYPES} = a
gl_convert(::Type{T}, a::NATIVE_TYPES; kw_args...) where {T <: NATIVE_TYPES} = a


gl_promote(x::Type{T}) where {T <: Integer} = Cint
gl_promote(x::Type{Union{Int16, Int8}}) = x

gl_promote(x::Type{T}) where {T <: Unsigned} = Cuint
gl_promote(x::Type{Union{UInt16, UInt8}}) = x

gl_promote(x::Type{T}) where {T <: AbstractFloat} = Float32
gl_promote(x::Type{Float16}) = x

gl_promote(x::Type{T}) where {T <: Normed} = N0f32
gl_promote(x::Type{N0f16}) = x
gl_promote(x::Type{N0f8}) = x

const Color3{T} = Colorant{T, 3}
const Color4{T} = Colorant{T, 4}

gl_promote(x::Type{Bool}) = GLboolean

# This should possibly go in another package:
# gl_promote(x::Type{T}) where {T <: Gray} = Gray{gl_promote(eltype(T))}
# gl_promote(x::Type{T}) where {T <: Color3} = RGB{gl_promote(eltype(T))}
# gl_promote(x::Type{T}) where {T <: Color4} = RGBA{gl_promote(eltype(T))}
# gl_promote(x::Type{T}) where {T <: BGRA} = BGRA{gl_promote(eltype(T))}
# gl_promote(x::Type{T}) where {T <: BGR} = BGR{gl_promote(eltype(T))}


gl_promote(x::Type{T}) where {T <: StaticVector} = similar_type(T, gl_promote(eltype(T)))

gl_convert(x::T) where {T <: Number} = gl_promote(T)(x)
gl_convert(x::T) where {T <: Colorant} = gl_promote(T)(x)
gl_convert(s::Vector{Matrix{T}}) where {T<:Colorant} = Texture(s)
gl_convert(s::Void) = s

isa_gl_struct(x::Array) = false
isa_gl_struct(x::Colorant) = false
function isa_gl_struct(x::T) where T
    !isleaftype(T) && return false
    if T <: Tuple
        return false
    end
    fnames = fieldnames(T)
    !isempty(fnames) && all(name -> isleaftype(fieldtype(T, name)) && isbits(getfield(x, name)), fnames)
end
function gl_convert_struct(x::T, uniform_name::Symbol) where T
    if isa_gl_struct(x)
        return Dict{Symbol, Any}(map(fieldnames(x)) do name
            (Symbol("$uniform_name.$name") => gl_convert(getfield(x, name)))
        end)
    else
        error("can't convert $x to a OpenGL type. Make sure all fields are of a concrete type and isbits(FieldType)-->true")
    end
end


#i get a warning redefinition because of the NativeTypes inclusion of StaticArrays, whats that about?
gl_convert(x::StaticVector{N, T}) where {N, T} = map(gl_promote(T), x)
gl_convert(x::SMatrix{N, M, T}) where {N, M, T} = map(gl_promote(T), x)


gl_convert(a::Vector{T}) where {T <: Face} = indexbuffer(s)
# gl_convert(a::Vector{T}) where T = convert(Vector{gl_promote(T)}, a)

gl_convert(::Type{T}, a::NATIVE_TYPES; kw_args...) where {T <: NATIVE_TYPES} = a
function gl_convert(::Type{T}, a::Array{X, N}; kw_args...) where {T <: GPUArray, X, N}
    T(map(gl_promote(X), a); kw_args...)
end
function gl_convert(::Type{T}, a::Vector{Array{X, 2}}; kw_args...) where {T <: Texture, X}
    T(a; kw_args...)
end


gl_convert(f::Function, a) = f(a)
