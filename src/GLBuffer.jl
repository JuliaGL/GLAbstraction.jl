const GLBufferEltypes = Union(AbstractFixedVector, Real, Vector3, Vector2, Vector4)


cardinality{T, C}(::GLBuffer{T, C})     = C
Base.length(b::GLBuffer)                = b.length
Base.eltype{T, C}(b::GLBuffer{T, C})    = T

Base.endof(b::GLBuffer)                 = length(A)
Base.ndims(b::GLBuffer)                 = 1
Base.size(b::GLBuffer)                  = (length(b))
# Iterator 
Base.start(b::GLBuffer)                 = 1
Base.next(b::GLBuffer, state::Integer)  = (A[state], state+1)
Base.done(b::GLBuffer, state::Integer)  = length(A) < state

function Base.delete!(x::GLBuffer)
    glDeleteBuffers(1, [x.id])
end
#Function to deal with any Immutable type with Real as Subtype
function GLBuffer{T <: GLBufferEltypes}(
            buffer::DenseArray{T};
            buffertype::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW
        )
    elemtype    = eltype(buffer)
    cardinality = length(T)
    ptr         = pointer(buffer)
    GLBuffer{elemtype, cardinality}(ptr, sizeof(buffer), buffertype, usage)
end


function indexbuffer{T<:GLBufferEltypes}(buffer::Vector{T}; usage::GLenum = GL_STATIC_DRAW)
    GLBuffer(buffer, buffertype = GL_ELEMENT_ARRAY_BUFFER, usage=usage)
end

#Array interface
function gpu_data{T, C}(b::GLBuffer{T, C})
    data = Array(T, length(b))
    glBindBuffer(b.buffertype, b.id)
    glGetBufferSubData(b.buffertype, 0, sizeof(data), data)
    data
end


# Resize buffer
function gpu_resize!{T , C, I <: Integer}(b::GLBuffer{T,C}, newdims::NTuple{1, I})
    glBindBuffer(b.buffertype, b.id)
    oldata = data(b)
    len = first(newdims)
    resize!(oldata, len)
    glBufferData(b.buffertype, len, oldata, b.usage)
    b.length = len
    nothing
end



function unsafe_setindex!{T, Cardinality}(b::GLBuffer{T, Cardinality}, value::Vector{T}, offset::Integer)
    multiplicator = sizeof(T)
    glBindBuffer(b.buffertype, b.id)
    glBufferSubData(b.buffertype, multiplicator*offset-1, sizeof(value), value)
end

function unsafe_getindex{T, Cardinality}(b::GLBuffer{T, Cardinality}, range::UnitRange)
    multiplicator = sizeof(T)
    offset        = first(range)
    value         = Array(T, length(range))
    glBindBuffer(b.buffertype, b.id)
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