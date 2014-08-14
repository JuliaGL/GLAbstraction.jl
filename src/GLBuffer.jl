cardinality{T, C}(::GLBuffer{T, C}) = C

#Function to deal with any Immutable type with Real as Subtype
function GLBuffer{T <: AbstractArray}(
            buffer::Vector{T};
            buffertype::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW
        )
    #This is a workaround, to deal with all kinds of immutable vector types
    ptrtype, cardinality = opengl_compatible(T)
    ptr = convert(Ptr{ptrtype}, pointer(buffer))
    GLBuffer{ptrtype, cardinality}(ptr, sizeof(buffer), buffertype, usage)
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
function indexbuffer{T<:AbstractArray}(buffer::Vector{T}; usage::GLenum = GL_STATIC_DRAW)
    GLBuffer(buffer, buffertype = GL_ELEMENT_ARRAY_BUFFER, usage=usage)
end

function update!{T}(b::GLBuffer{T,1}, data::Vector{Vector1{T}})
    glBindBuffer(b.buffertype, b.id)
    glBufferSubData(b.buffertype, 0, sizeof(data), data)
end
function update!{T}(b::GLBuffer{T,2}, data::Vector{Vector2{T}})
    glBindBuffer(b.buffertype, b.id)
    glBufferSubData(b.buffertype, 0, sizeof(data), data)
end
function update!{T}(b::GLBuffer{T,3}, data::Vector{Vector3{T}})
    glBindBuffer(b.buffertype, b.id)
    glBufferSubData(b.buffertype, 0, sizeof(data), data)
end
function update!{T}(b::GLBuffer{T,4}, data::Vector{Vector4{T}})
    glBindBuffer(b.buffertype, b.id)
    glBufferSubData(b.buffertype, 0, sizeof(data), data)
end
