type GLBuffer{T} <: GLMemory{T, 1}
    id          ::GLuint
    size        ::NTuple{1, Int}
    buffertype  ::GLenum
    usage       ::GLenum
    context     ::GLContext

    function GLBuffer{T}(ptr::Ptr{T}, buff_length::Int, buffertype::GLenum, usage::GLenum) where T
        id = glGenBuffers()
        glBindBuffer(buffertype, id)
        glBufferData(buffertype, buff_length * sizeof(T), ptr, usage)
        glBindBuffer(buffertype, 0)

        obj = new{T}(id, (buff_length,), buffertype, usage, current_context())
        #finalizer(obj, free)
        obj
    end
    function GLBuffer{T}(length::Int, sizeof::Int, buffertype::GLenum, usage::GLenum) where T
        id = glGenBuffers()
        glBindBuffer(buffertype, id)
        glBufferData(buffertype, sizeof, C_NULL, usage)
        glBindBuffer(buffertype, 0)
        obj = new{T}(id, (length,), buffertype, usage, current_context())
        finalizer(obj, free)
        obj
    end
end


bind(buffer::GLBuffer) = glBindBuffer(buffer.buffertype, buffer.id)
#used to reset buffer target
bind(buffer::GLBuffer, other_target) = glBindBuffer(buffer.buffertype, other_target)
function bind(f::Function, buffer::GLBuffer)
    bind(buffer)
    try
        f()
    catch e
        rethrow(e)
    finally
        bind(buffer, 0)
    end
end

function similar{T}(::Type{GLBuffer{T}}, buff_length::Int)
    GLBuffer{T}(Ptr{T}(C_NULL), buff_length, x.buffertype, x.usage)
end

cardinality{T}(::GLBuffer{T}) = cardinality(T)

function GLBuffer(
        buffer::DenseVector{T};
        buffertype::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW
    ) where T
    GLBuffer{T}(pointer(buffer), length(buffer), buffertype, usage)
end

function GLBuffer{T <: GLArrayEltypes}(
        ::Type{T}, len::Int;
        buffertype::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW
    )
    GLBuffer{T}(Ptr{T}(C_NULL), len, buffertype, usage)
end

function indexbuffer(
        buffer::Vector{T};
        usage::GLenum = GL_STATIC_DRAW
    ) where T<:GLArrayEltypes
    GLBuffer(buffer, buffertype = GL_ELEMENT_ARRAY_BUFFER, usage=usage)
end
# GPUArray interface
function gpu_data{T}(b::GLBuffer{T})
    data = Vector{T}(length(b))
    bind(b)
    glGetBufferSubData(b.buffertype, 0, sizeof(data), data)
    bind(b, 0)
    data
end


# Resize buffer
function gpu_resize!(buffer::GLBuffer{T}, newdims::NTuple{1, Int}) where T
    #TODO make this safe!
    newlength = newdims[1]
    oldlen    = length(buffer)
    if oldlen > 0
        old_data = gpu_data(buffer)
    end
    bind(buffer)
    glBufferData(buffer.buffertype, newlength*sizeof(T), C_NULL, buffer.usage)
    bind(buffer, 0)
    buffer.size = newdims
    if oldlen > 0
        max_len = min(length(old_data), newlength) #might also shrink
        buffer[1:max_len] = old_data[1:max_len]
    end
    # probably faster, but changes the buffer ID
    # newbuff = similar(buffer, newdims...)
    # unsafe_copy!(buffer, 1, newbuff, 1, length(buffer))
    # buffer.id = newbuff.id
    # buffer.size = newbuff.size
    nothing
end



# Dublicate of below. TODO benchmark and chose better version
# function Base.unsafe_copy!{T}(a::GLBuffer{T}, readoffset::Int, b::Vector{T}, writeoffset::Int, len::Int)
#     bind(a)
#     ptr = Ptr{T}(glMapBuffer(a.buffertype, GL_READ_ONLY))
#     for i=1:len
#         b[i+writeoffset-1] = unsafe_load(ptr, i+readoffset-2) #-2 => -1 to zero offset, -1 gl indexing starts at 0
#     end
#     glUnmapBuffer(a.buffertype)
#     bind(a,0)
# end

function check_copy_bounds(
        dest, d_offset::Integer,
        src, s_offset::Integer,
        amount::Integer
    )
    amount > 0 || throw(ArgumentError(string("tried to copy n=", amount, " elements, but amount should be nonnegative")))
    if s_offset < 1 || d_offset < 1 ||
            s_offset + amount - 1 > length(src) ||
            d_offset + amount - 1 > length(dest)
        throw(BoundsError())
    end
    nothing
end




function copy!{T, N}(
        dest::GLBuffer{T}, d_offset::Integer,
        src::Array{T, N}, s_offset::Integer, amount::Integer
    )
    amount == 0 && return dest
    check_copy_bounds(dest, d_offset, src, s_offset, amount)
    multiplicator = sizeof(T)
    nsz = multiplicator * amount
    bind(dest)
    glBufferSubData(dest.buffertype, multiplicator * (d_offset - 1), nsz, Ref(src, s_offset))
    bind(dest, 0)
end

function copy!{T, N}(
        dest::Array{T, N}, d_offset::Integer,
        src::GLBuffer{T}, s_offset::Integer, amount::Integer
    )
    amount == 0 && return dest
    check_copy_bounds(dest, d_offset, src, s_offset, amount)
    multiplicator = sizeof(T)
    nsz = multiplicator * amount
    bind(src)
    glGetBufferSubData(
        src.buffertype, multiplicator * (s_offset - 1), nsz,
        Ref(dest, d_offset)
    )
    bind(src, 0)
    dest
end


# copy between two buffers
function copy!{T}(
        dest::GLBuffer{T}, d_offset::Integer,
        src::GLBuffer{T}, s_offset::Integer, amount::Integer
    )
    amount == 0 && return dest
    check_copy_bounds(dest, d_offset, src, s_offset, amount)
    multiplicator = sizeof(T)
    nsz = multiplicator * amount
    glBindBuffer(GL_COPY_READ_BUFFER, src.id)
    glBindBuffer(GL_COPY_WRITE_BUFFER, dest.id)
    glCopyBufferSubData(
        GL_COPY_READ_BUFFER, GL_COPY_WRITE_BUFFER,
        multiplicator * (s_offset - 1),
        multiplicator * (d_offset - 1),
        multiplicator * amount
    )
    glBindBuffer(GL_COPY_READ_BUFFER, 0)
    glBindBuffer(GL_COPY_WRITE_BUFFER, 0)
    return nothing
end

function Base.start(buffer::GLBuffer{T}) where T
    glBindBuffer(buffer.buffertype, buffer.id)
    ptr = Ptr{T}(glMapBuffer(buffer.buffertype, GL_READ_WRITE))
    (ptr, 1)
end
function Base.next(buffer::GLBuffer{T}, state::Tuple{Ptr{T}, Int}) where T
    ptr, i = state
    val = unsafe_load(ptr, i)
    (val, (ptr, i+1))
end
function Base.done(buffer::GLBuffer{T}, state::Tuple{Ptr{T}, Int}) where T
    ptr, i = state
    isdone = length(buffer) < i
    isdone && glUnmapBuffer(buffer.buffertype)
    isdone
end

#copy inside one buffer
function copy!{T}(buffer::GLBuffer{T}, readoffset::Int, writeoffset::Int, len::Int)
    len <= 0 && return nothing
    bind(buffer)
    ptr = Ptr{T}(glMapBuffer(buffer.buffertype, GL_READ_WRITE))
    for i=1:len+1
        unsafe_store!(ptr, unsafe_load(ptr, i+readoffset-1), i+writeoffset-1)
    end
    glUnmapBuffer(buffer.buffertype)
    bind(buffer, 0)
    buffer
end
