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
function similar{T}(x::GLBuffer{T}, buff_length::Int)
    GLBuffer{T}(Ptr{T}(C_NULL), buff_length, x.buffertype, x.usage)
end

cardinality{T}(::GLBuffer{T}) = length(T)
    
#Function to deal with any Immutable type with Real as Subtype
function GLBuffer{T <: GLArrayEltypes}(
            buffer::DenseVector{T};
            buffertype::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW
        )
    GLBuffer{T}(pointer(buffer), length(buffer), buffertype, usage)
end


indexbuffer{T<:GLArrayEltypes}(buffer::Vector{T}; usage::GLenum = GL_STATIC_DRAW) = 
    GLBuffer(buffer, buffertype = GL_ELEMENT_ARRAY_BUFFER, usage=usage)

# GPUArray interface
function gpu_data{T}(b::GLBuffer{T})
    data = Array(T, length(b))
    glBindBuffer(b.buffertype, b.id)
    glGetBufferSubData(b.buffertype, 0, sizeof(data), data)
    data
end


# Resize buffer
function gpu_resize!{T}(buffer::GLBuffer{T}, newdims::NTuple{1, Int})
    #TODO make this safe!
    newbuff     = similar(buffer, newdims...)
    unsafe_copy!(buffer, 1, newbuff, 1, length(buffer))
    buffer.id   = newbuff.id
    buffer.size = newbuff.size
    nothing
end



function gpu_setindex!{T}(b::GLBuffer{T}, value::Vector{T}, offset::Integer)
    multiplicator = sizeof(T)
    glBindBuffer(b.buffertype, b.id)
    glBufferSubData(b.buffertype, multiplicator*offset-1, sizeof(value), value)
end
function gpu_setindex!{T}(b::GLBuffer{T}, value::Vector{T}, offset::UnitRange{Int})
    multiplicator = sizeof(T)
    glBindBuffer(b.buffertype, b.id)
    glBufferSubData(b.buffertype, multiplicator*(first(offset)-1), sizeof(value), value)
    return nothing 
end

# copy between two buffers
# could be a setindex! operation, with subarrays for buffers
function Base.unsafe_copy!{T}(a::GLBuffer{T}, readoffset::Int, b::GLBuffer{T}, writeoffset::Int, len::Int)
    multiplicator = sizeof(T)
    glBindBuffer(GL_COPY_READ_BUFFER, a.id)
    glBindBuffer(GL_COPY_WRITE_BUFFER, b.id)
    glCopyBufferSubData(GL_COPY_READ_BUFFER, GL_COPY_WRITE_BUFFER, 
        multiplicator*(readoffset-1), 
        multiplicator*(writeoffset-1), 
        multiplicator*len)

    return nothing 
end

function Base.start{T}(buffer::GLBuffer{T})
    glBindBuffer(buffer.buffertype, buffer.id)
    ptr = Ptr{T}(glMapBuffer(buffer.buffertype, GL_READ_WRITE))
    (ptr, 1)
end
function Base.next{T}(buffer::GLBuffer{T}, state::Tuple{Ptr{T}, Int})
    ptr, i = state
    val = unsafe_load(ptr, i)
    (val, (ptr, i+1))
end
function Base.done{T}(buffer::GLBuffer{T}, ptr::Tuple{Ptr{T}, Int})
    ptr, i = state
    isdone = length(buffer) < i 
    isdone && glUnmapBuffer(buffer.buffertype)
    isdone
end

#copy inside one buffer
function Base.unsafe_copy!{T}(buffer::GLBuffer{T}, readoffset::Int, writeoffset::Int, len::Int)
    len <=0 && return nothing 
    glBindBuffer(buffer.buffertype, buffer.id)
    ptr = Ptr{T}(glMapBuffer(buffer.buffertype, GL_READ_WRITE))
    for i=1:len+1
        unsafe_store!(ptr, unsafe_load(ptr, i+readoffset-1), i+writeoffset-1)
    end
    glUnmapBuffer(buffer.buffertype)
    return nothing 
end
function Base.unsafe_copy!{T}(a::Vector{T}, readoffset::Int, b::GLBuffer{T}, writeoffset::Int, len::Int)
    glBindBuffer(b.buffertype, b.id)
    ptr = Ptr{T}(glMapBuffer(b.buffertype, GL_WRITE_ONLY))
    for i=1:len
        unsafe_store!(ptr, a[i+readoffset-1], i+writeoffset-1)
    end
    glUnmapBuffer(b.buffertype)
end
function Base.unsafe_copy!{T}(a::GLBuffer{T}, readoffset::Int, b::Vector{T}, writeoffset::Int, len::Int)
    glBindBuffer(a.buffertype, a.id)
    ptr = Ptr{T}(glMapBuffer(a.buffertype, GL_READ_ONLY))
    for i=1:len
        b[i+writeoffset-1] = unsafe_load(ptr, i+readoffset-2) #-2 => -1 to zero offset, -1 gl indexing starts at 0
    end
    glUnmapBuffer(a.buffertype)
end

function gpu_getindex{T}(b::GLBuffer{T}, range::UnitRange)
    multiplicator = sizeof(T)
    offset        = first(range)-1
    value         = Array(T, length(range))
    glBindBuffer(b.buffertype, b.id)
    glGetBufferSubData(b.buffertype, multiplicator*offset, sizeof(value), value)
    value
end
