type GLBuffer{T} <: GPUArray{T, 1}
    id          ::GLuint
    size        ::NTuple{1, Int}
    buffertype  ::GLenum
    usage       ::GLenum

    function GLBuffer(ptr::Ptr{T}, buff_length::Int, buffertype::GLenum, usage::GLenum)
        id = glGenBuffers()
        glBindBuffer(buffertype, id)
        glBufferData(buffertype, buff_length*sizeof(T), ptr, usage)
        glBindBuffer(buffertype, 0)

        obj = new(id, (buff_length,), buffertype, usage)
        #finalizer(obj, free)
        obj
    end
end


cardinality{T}(::GLBuffer{T}) = length(T)
    
#Function to deal with any Immutable type with Real as Subtype
function GLBuffer{T <: GLArrayEltypes}(
            buffer::DenseVector{T};
            buffertype::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW
        )
    GLBuffer{T}(pointer(buffer), length(buffer), buffertype, usage)
end


function indexbuffer{T<:GLArrayEltypes}(buffer::Vector{T}; usage::GLenum = GL_STATIC_DRAW)
    GLBuffer(buffer, buffertype = GL_ELEMENT_ARRAY_BUFFER, usage=usage)
end

# GPUArray interface
function gpu_data{T}(b::GLBuffer{T})
    data = Array(T, length(b))
    glBindBuffer(b.buffertype, b.id)
    glGetBufferSubData(b.buffertype, 0, sizeof(data), data)
    data
end


# Resize buffer
function gpu_resize!{T, I <: Integer}(b::GLBuffer{T}, newdims::NTuple{1, I})
    glBindBuffer(b.buffertype, b.id)
    oldata = data(b)
    len = first(newdims)
    resize!(oldata, len)
    glBufferData(b.buffertype, len, oldata, b.usage)
    b.length = len
    nothing
end



function gpu_setindex!{T}(b::GLBuffer{T}, value::Vector{T}, offset::Integer)
    multiplicator = sizeof(T)
    glBindBuffer(b.buffertype, b.id)
    glBufferSubData(b.buffertype, multiplicator*offset-1, sizeof(value), value)
end

function gpu_getindex{T}(b::GLBuffer{T}, range::UnitRange)
    multiplicator = sizeof(T)
    offset        = first(range)
    value         = Array(T, length(range))
    glBindBuffer(b.buffertype, b.id)
    glGetBufferSubData(b.buffertype, multiplicator*offset-1, sizeof(value), value)
    value
end
