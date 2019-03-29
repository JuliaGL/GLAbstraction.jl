import Base.Iterators.Repeated

mutable struct Buffer{T} <: GPUArray{T, 1}
    id          ::GLuint
    size        ::Tuple{Int}
    buffertype  ::GLenum
    usage       ::GLenum
    context     ::AbstractContext
    function Buffer{T}(ptr::Ptr{T}, buff_length::Int, buffertype::GLenum, usage::GLenum) where T
        id = glGenBuffers()
        glBindBuffer(buffertype, id)
        # size of 0 can segfault it seems
        buff_length = buff_length == 0 ? 1 : buff_length
        glBufferData(buffertype, buff_length * sizeof(T), ptr, usage)
        glBindBuffer(buffertype, 0)

        obj = new{T}(id, (buff_length,), buffertype, usage, current_context())
        finalizer(free!, obj)
        obj
    end
end
#Function to deal with any Immutable type with Real as Subtype
function Buffer(
        buffer::DenseVector{T};
        buffertype::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW
    ) where T <: Real
    Buffer{T}(pointer(buffer), length(buffer), buffertype, usage)
end
function Buffer(
        buffer::DenseVector{T};
        buffertype::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW
    ) where T
    glasserteltype(T)
    Buffer{T}(pointer(buffer), length(buffer), buffertype, usage)
end
function Buffer(
        ::Type{T}, len::Int;
        buffertype::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW
    ) where T
    glasserteltype(T)
    Buffer{T}(Ptr{T}(C_NULL), len, buffertype, usage)
end

function indexbuffer(
        buffer::Vector{T};
        usage::GLenum = GL_STATIC_DRAW
    ) where T
    glasserteltype(T)
    Buffer(buffer, buffertype = GL_ELEMENT_ARRAY_BUFFER, usage=usage)
end
indexbuffer(x::Buffer) = x.buffertype == GL_ELEMENT_ARRAY_BUFFER ? x : @error "Indexbuffer must be of enum GL_ELEMENT_ARRAY_BUFFER!"
#-------------------------------- END CONSTRUCTORS -------------------------------------#

cardinality(::Buffer{T}) where {T} = cardinality(T)

bind(buffer::Buffer) = glBindBuffer(buffer.buffertype, buffer.id)
#used to reset buffer target
bind(buffer::Buffer, other_target) = glBindBuffer(buffer.buffertype, other_target)

Base.convert(::Type{Buffer}, x::Buffer)   = x
Base.convert(::Type{Buffer}, x::Array)    = Buffer(x)
Base.convert(::Type{Buffer}, x::Repeated) = convert(Buffer, x.xs.x)


#TODO: implement iteration
function start(buffer::Buffer{T}) where T
    glBindBuffer(buffer.buffertype, buffer.id)
    ptr = Ptr{T}(glMapBuffer(buffer.buffertype, GL_READ_WRITE))
    (ptr, 1)
end
function next(buffer::Buffer{T}, state::Tuple{Ptr{T}, Int}) where T
    ptr, i = state
    val = unsafe_load(ptr, i)
    (val, (ptr, i+1))
end
function done(buffer::Buffer{T}, state::Tuple{Ptr{T}, Int}) where T
    ptr, i = state
    isdone = length(buffer) < i
    isdone && glUnmapBuffer(buffer.buffertype)
    isdone
end

function Base.similar(x::Buffer{T}, buff_length::Int) where T
    Buffer{T}(Ptr{T}(C_NULL), buff_length, x.buffertype, x.usage)
end

# copy between two buffers
# could be a setindex! operation, with subarrays for buffers
function Base.unsafe_copyto!(a::Buffer{T}, readoffset::Int, b::Buffer{T}, writeoffset::Int, len::Int) where T
    multiplicator = sizeof(T)
    glBindBuffer(GL_COPY_READ_BUFFER, a.id)
    glBindBuffer(GL_COPY_WRITE_BUFFER, b.id)
    glCopyBufferSubData(
        GL_COPY_READ_BUFFER, GL_COPY_WRITE_BUFFER,
        multiplicator*(readoffset-1),
        multiplicator*(writeoffset-1),
        multiplicator*len
    )
    glBindBuffer(GL_COPY_READ_BUFFER, 0)
    glBindBuffer(GL_COPY_WRITE_BUFFER, 0)
    return nothing
end
#copy inside one buffer
function Base.unsafe_copyto!(buffer::Buffer{T}, readoffset::Int, writeoffset::Int, len::Int) where T
    len <= 0 && return nothing
    bind(buffer)
    ptr = Ptr{T}(glMapBuffer(buffer.buffertype, GL_READ_WRITE))
    for i=1:len+1
        unsafe_store!(ptr, unsafe_load(ptr, i+readoffset-1), i+writeoffset-1)
    end
    glUnmapBuffer(buffer.buffertype)
    bind(buffer,0)
    return nothing
end
function Base.unsafe_copyto!(a::Vector{T}, readoffset::Int, b::Buffer{T}, writeoffset::Int, len::Int) where T
    bind(b)
    ptr = Ptr{T}(glMapBuffer(b.buffertype, GL_WRITE_ONLY))
    for i=1:len
        unsafe_store!(ptr, a[i+readoffset-1], i+writeoffset-1)
    end
    glUnmapBuffer(b.buffertype)
    bind(b,0)
end
function Base.unsafe_copyto!(a::Buffer{T}, readoffset::Int, b::Vector{T}, writeoffset::Int, len::Int) where T
    bind(a)
    ptr = Ptr{T}(glMapBuffer(a.buffertype, GL_READ_ONLY))
    for i=1:len
        b[i+writeoffset-1] = unsafe_load(ptr, i+readoffset-2) #-2 => -1 to zero offset, -1 gl indexing starts at 0
    end
    glUnmapBuffer(a.buffertype)
    bind(a,0)
end

#--------------------------------- END BASEOVERLOADS-----------------------------------#

# GPUArray interface
function gpu_data(b::Buffer{T}) where T
    data = Vector{T}(length(b))
    bind(b)
    glGetBufferSubData(b.buffertype, 0, sizeof(data), data)
    bind(b, 0)
    data
end

# Resize buffer
function gpu_resize!(buffer::Buffer{T}, newdims::NTuple{1, Int}) where T
    #TODO make this safe!
    newlength = newdims[1]
    oldlen    = length(buffer)
    if oldlen > 0
        old_data = gpu_data(buffer)
    end
    bind(buffer)
    glBufferData(buffer.buffertype, newlength*sizeof(T), C_NULL, buffer.usage)
    bind(buffer, 0)
    buffer.length = newdims
    if oldlen>0
        max_len = min(length(old_data), newlength) #might also shrink
        buffer[1:max_len] = old_data[1:max_len]
    end
    #probably faster, but changes the buffer ID
    # newbuff     = similar(buffer, newdims...)
    # unsafe_copy!(buffer, 1, newbuff, 1, length(buffer))
    # buffer.id   = newbuff.id
    # buffer.length = newbuff.length
    nothing
end

function gpu_setindex!(b::Buffer{T}, value::Vector{T}, offset::Integer) where T
    multiplicator = sizeof(T)
    bind(b)
    glBufferSubData(b.buffertype, multiplicator*offset-1, sizeof(value), value)
    bind(b, 0)
end
function gpu_setindex!(b::Buffer{T}, value::Vector{T}, offset::UnitRange{Int}) where T
    multiplicator = sizeof(T)
    bind(b)
    glBufferSubData(b.buffertype, multiplicator*(first(offset)-1), sizeof(value), value)
    bind(b, 0)
    return nothing
end


function gpu_getindex(b::Buffer{T}, range::UnitRange) where T
    multiplicator = sizeof(T)
    offset        = first(range)-1
    value         = Vector{T}(undef, length(range))
    bind(b)
    glGetBufferSubData(b.buffertype, multiplicator*offset, sizeof(value), value)
    bind(b, 0)
    value
end

#--------------------------------- END GPU INTERFACE -----------------------------------------#

####################################################################################
# freeing

# OpenGL has the annoying habit of reusing id's when creating a new context
# We need to make sure to only free the current one

function free!(x::Buffer)
    if !is_current_context(x.context)
        return x
    end
    id = [x.id]
    try
        glDeleteBuffers(1, id)
    catch e
        free_handle_error(e)
    end
    return
end
