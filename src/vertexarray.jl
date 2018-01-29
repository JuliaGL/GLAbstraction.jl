using GeometryTypes: Face

function attach2vao(buffer::Buffer{T}, attrib_location, instanced=false) where T
    bind(buffer)
    if !is_glsl_primitive(T)
        for i = 1:nfields(T)
            FT = fieldtype(T, i); ET = eltype(FT)
            glVertexAttribPointer(
                attrib_location,
                cardinality(FT), julia2glenum(ET),
                GL_FALSE, sizeof(T), Ptr{Void}(fieldoffset(T, i))
            )
            glEnableVertexAttribArray(attrib_location)
            attrib_location += 1
        end
    else
        FT = T; ET = eltype(FT)
        glVertexAttribPointer(
            attrib_location,
            cardinality(FT), julia2glenum(ET),
            GL_FALSE, 0, C_NULL
        )
        glEnableVertexAttribArray(attrib_location)
        if instanced
            glVertexAttribDivisor(attrib_location, 1)
        end
        attrib_location += 1
    end
end
function attach2vao(buffers::Vector{<:Buffer}, attrib_location)
#again I assume that the first buffer is the vertex buffer, this could be checked by vec3f0 or so but thats also not so robust
    len = length(buffers[1])
    for b in buffers
        if length(b) != len
            attach2vao(b, attrib_location, true)
        else
            attach2vao(b, attrib_location)
        end
    end
end

@enum VaoKind simple elements elements_instanced

struct VertexArray{Vertex, Kind <: VaoKind}
    id::GLuint
    nverts::Int
    nprim::Int
    face::GLenum 
    indices::Union{Buffer, Void}
    context::AbstractContext
    function (::Type{VertexArray{Vertex, Kind}})(id, vertlength, nprim, face, indices)
        new{Vertex, Kind}(id, vertlength, nprim, face, indices, current_context())
    end
end
function VertexArray(buffers::Vector{<:Buffer}, indices::Union{Buffer{T}, Void}, face_length=1, attrib_location=0) where T
    # either integer with specified length or staticarrays
    face = if T <: Integer
        gl_face_emum(face_length)
    else
        gl_face_enum(T)
    end
    id = glGenVertexArrays()
    glBindVertexArray(id)
    len1 = length(buffers[1])
    len2 = 1
    if indices == nothing
        kind = simple
    else
        for b in buffers
            if len2 == 1
                if length(b) == len
                    continue
                else
                    len2 = length(b)
                    kind = elements_instanced
                end
            else
                if length(b) == len2
                    continue
                else
                    error("Wrong size of buffer $b inside instanced vao of length(instances) = $len2")
                end
            end
        end
    end
    attach2vao(buffers, attrib_location) 
    glBindVertexArray(0)

    if length(buffers) == 1
        if !is_glsl_primitive(eltype(buffers[1]))
            vert_type = eltype(buffers[1])
        else
            vert_type = Tuple{eltype(buffers[1])}
        end
    else
        vert_type = Tuple{eltype.((arrays...,))...}
    end
    #i assume that the first buffer has the length of vertices
    obj = VertexArray{vert_type, kind}(id, len1, len2, face, indices, kind)
    obj
end
VertexArray(buffer::Buffer, args...) = VertexArray([buffer], args...)

function VertexArray(data::Vector{AbstractArray{T}}, indices::Vector{I}, args...)
    buffers = Buffer.(data)
    ind_buffer= Buffer(indices)
    return VertexArray(buffers, ind_buffer, args...)
end

VertexArray(data::Vector{AbstractArray{T}}, args...) = VertexArray(Buffer.(data), nothing, args...)

# TODO
Base.convert(::Type{VertexArray}, x) = VertexArray(x)
Base.convert(::Type{VertexArray}, x::VertexArray) = x

function gl_face_enum(face)
    face_length = typeof(face) <: Integer ? face : length(face)
    if facelength == 1
        return GL_POINTS
    elseif facelength == 2
        return GL_LINES
    elseif facelength == 3
        return GL_TRIANGLES
    elseif facelength == 4
        return GL_QUADS
    end
end

is_struct{T}(::Type{T}) = !(sizeof(T) != 0 && nfields(T) == 0)
is_glsl_primitive{T <: StaticVector}(::Type{T}) = true
is_glsl_primitive{T <: Union{Float32, Int32}}(::Type{T}) = true
is_glsl_primitive(T) = false

_typeof{T}(::Type{T}) = Type{T}
_typeof{T}(::T) = T

function free(x::VertexArray)
    if !is_current_context(x.context)
        return # don't free from other context
    end
    id = [x.id]
    try
        glDeleteVertexArrays(1, id)
    catch e
        free_handle_error(e)
    end
    return
end

glitype(vao::VertexArray) = julia2glenum(eltype(vao.indices))
totverts(vao::VertexArray) = vao.nverts * cardinality(vao.indices)

draw(vao::VertexArray{V, elements}) = glDrawElements(vao.face, totverts(vao), glitype(vao), C_NULL)
draw(vao::VertexArray{V, elements_instanced}) = glDrawElementsInstanced(vao.face, totverts(vao), glitype(vao), C_NULL, vao.nprim)

draw(vao::VertexArray{V, simple}) = glDrawArrays(vao.face, 0, totverts(vao))