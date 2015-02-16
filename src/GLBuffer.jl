cardinality{T, C}(::GLBuffer{T, C})     = C
Base.length(b::GLBuffer)                = b.length
Base.eltype{T, C}(b::GLBuffer{T, C})    = T

Base.endof(b::GLBuffer)                 = length(A)
Base.ndims(b::GLBuffer)                 = 1
Base.size(b::GLBuffer)                  = (length(b))
# Iterator 
Base.start(b::GLBuffer)                 = 1
Base.next (b::GLBuffer, state::Integer) = (A[state], state+1)
Base.done (b::GLBuffer, state::Integer) = length(A) < state



opengl_compatible{C <: AbstractAlphaColorValue}(T::Type{C}) = eltype(T), 4
opengl_compatible{C <: RGB4}(T::Type{C})                    = eltype(T), 4
opengl_compatible{C <: ColorValue}(T::Type{C})              = eltype(T), 3
opengl_compatible{C <: AbstractGray}(T::Type{C})            = eltype(T), 1
function opengl_compatible(T::DataType)
    (T <: Number)       && return (T, 1)
    !isbits(T)          && error("only pointer free, immutable types are supported for upload to OpenGL. Found type: $(T)")
    elemtype = T.types[1]
    !(elemtype <: Real)                && error("only real numbers are allowed as element types for upload to OpenGL. Found type: $(T) with $(ptrtype)")
    !all(x -> x == elemtype , T.types) && error("all values in $(T) need to have the same type to create a GLBuffer")
        
    cardinality = length(names(T))
    (cardinality > 4) && error("there should be at most 4 values in $(T) to create a GLBuffer")

    elemtype, cardinality
end

#Function to deal with any Immutable type with Real as Subtype
function GLBuffer{T <: AbstractFixedVector}(
            buffer::Vector{T};
            buffertype::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW
        )
    #This is a workaround, to deal with all kinds of immutable vector types
    elemtype, cardinality = opengl_compatible(T)
    ptr = convert(Ptr{elemtype}, pointer(buffer))
    GLBuffer{elemtype, cardinality}(ptr, sizeof(buffer), buffertype, usage)
end

function GLBuffer{T <: Real}(
            buffer::Vector{T}, cardinality::Int;
            buffertype::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW
        )
    GLBuffer{T, cardinality}(convert(Ptr{T}, pointer(buffer)), sizeof(buffer), buffertype, usage)
end

function indexbuffer{T<:Integer}(buffer::Vector{T}; usage::GLenum = GL_STATIC_DRAW)
    GLBuffer(buffer, 1, buffertype = GL_ELEMENT_ARRAY_BUFFER, usage=usage)
end

function indexbuffer{T<:Union(AbstractArray, AbstractFixedVector)}(buffer::Vector{T}; usage::GLenum = GL_STATIC_DRAW)
    GLBuffer(buffer, buffertype = GL_ELEMENT_ARRAY_BUFFER, usage=usage)
end

function unsafe_setindex!{T, Cardinality}(b::GLBuffer{T, Cardinality}, value::Vector{T}, offset::Integer)
    multiplicator = sizeof(T)
    glBindBuffer(b.buffertype, b.id)
    glBufferSubData(b.buffertype, multiplicator*offset-1, sizeof(value), value)
end
function unsafe_getindex{T, Cardinality}(b::GLBuffer{T, Cardinality}, range::UnitRange)
    multiplicator = sizeof(T)
    offset  = first(range)
    glBindBuffer(b.buffertype, b.id)
    value   = zeros(T, length(range))
    glGetBufferSubData(b.buffertype, multiplicator*offset-1, sizeof(value), value)
    value
end

function Base.setindex!{T, Cardinality}(b::GLBuffer{T, Cardinality}, value::Vector{T}, range::UnitRange)
    checkbounds(b, range)
    checkdimensions(value, range)
    unsafe_setindex!(b, value, first(range))
end
function Base.setindex!{T, Cardinality}(b::GLBuffer{T, Cardinality}, value::T, i::Integer)
    checkbounds(b, i)
    unsafe_setindex!(b, value, i)
end

Base.getindex{T, Cardinality}(b::GLBuffer{T, Cardinality}, i::Integer) = getindex(b, i:i)
function Base.getindex{T, Cardinality}(b::GLBuffer{T, Cardinality}, range::UnitRange)
    checkbounds(b, range)
    unsafe_getindex(b, range)
end