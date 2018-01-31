# the instanced ones assume that there is at least one buffer with the vertextype (=has fields, bit whishy washy) and the others are the instanced things 
function attach2vao(buffer::Buffer{T}, attrib_location, instanced=false) where T
    Base.bind(buffer)
    if !is_glsl_primitive(T)
        for i = 1:nfields(T)
            FT = fieldtype(T, i); ET = eltype(FT)
            glVertexAttribPointer(
                attrib_location,
                cardinality(FT), julia2glenum(ET),
                GL_FALSE, sizeof(T), Ptr{Void}(fieldoffset(T, i)) # the fieldoffset is because here we have one buffer having all the attributes
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
    return attrib_location
end
function attach2vao(buffers::Vector{<:Buffer}, attrib_location)
    #again I assume that the first buffer is the vertex buffer, this could be checked by vec3f0 or so but thats also not so robust
    len = length(buffers[1])
    for b in buffers
        if length(b) != len
            attrib_location = attach2vao(b, attrib_location, true)
        else
            attrib_location = attach2vao(b, attrib_location)
        end
    end
    return attrib_location
end

@enum VaoKind simple elements elements_instanced

struct VertexArray{Vertex, Kind}
    id::GLuint
    buffers::Vector{<:Buffer}
    indices::Union{Buffer, Void}
    nverts::Int #might be redundant but whatever
    nprim::Int
    face::GLenum 
    context::AbstractContext
    function (::Type{VertexArray{Vertex, Kind}})(id, buffers, indices, nverts, nprim, face) where {Vertex, Kind}
        new{Vertex, Kind}(id, buffers, indices, nverts, nprim, face, current_context())
    end
end
function VertexArray(buffers::Vector{<:Buffer} where N, indices::Union{Buffer, Void}; facelength=1, attrib_location=0)
    # either integer with specified length or staticarrays
    id = glGenVertexArrays()
    glBindVertexArray(id)
    T = indices == nothing ? Int32 : eltype(indices)
    face = if T <: Integer
        gl_face_enum(facelength)
    else
        bind(indices)
        gl_face_enum(T)
    end
    len1 = length(buffers[1])
    len2 = 1
    if indices == nothing
        kind = simple
    else
        kind = elements
        for b in buffers
            if len2 == 1
                if length(b) == len1
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
        vert_type = Tuple{eltype.((buffers...,))...}
    end
    #i assume that the first buffer has the length of vertices
    obj = VertexArray{vert_type, kind}(id, buffers, indices, len1, len2, face)
    obj
end
VertexArray(buffer::Buffer; args...) = VertexArray((buffer), nothing; args...)
VertexArray(buffer::Buffer, indices; args...) = VertexArray((buffer), indices; args...)
VertexArray(buffers::Vector{<:Buffer} ; args...) = VertexArray(buffers, nothing; args...)

function VertexArray(data::Tuple, indices::Vector; args...)
    if all(x-> isa(x, Vector), data)
        gpu_data = [Buffer.(data)...]
        gpu_inds = indexbuffer(indices)
        VertexArray(gpu_data, gpu_inds; args...)
    else
        VertexArray([Buffer([data...])], indexbuffer(indices); args...)
    end
end
function VertexArray(data::Tuple; args...)
    if all(x-> isa(x, Vector), data)
        gpu_data = [Buffer.(data)...]
        VertexArray(gpu_data, nothing; args...)
    else
        VertexArray([Buffer([data...])], nothing; args...)
    end
end
VertexArray(data... ; args...) = VertexArray(data; args...)

# TODO
Base.convert(::Type{VertexArray}, x) = VertexArray(x)
Base.convert(::Type{VertexArray}, x::VertexArray) = x

function gl_face_enum(face)
    facelength = typeof(face) <: Integer ? face : length(face)
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
# is_glsl_primitive{T <: StaticVector}(::Type{T}) = true
is_glsl_primitive{T <: Union{Float32, Int32}}(::Type{T}) = true
function is_glsl_primitive(T)
    glasserteltype(T)
    true
end

_typeof{T}(::Type{T}) = Type{T}
_typeof{T}(::T) = T

function free!(x::VertexArray)
    if !is_current_context(x.context)
        return # don't free from other context
    end
    id = [x.id]
    for buffer in x.buffers
        free!(buffer)
    end
    if x.indices != nothing
        free!(x.indices)
    end
    try
        glDeleteVertexArrays(1, id)
    catch e
        free_handle_error(e)
    end
    return
end

glitype(vao::VertexArray) = julia2glenum(eltype(vao.indices))
totverts(vao::VertexArray) = vao.nverts 

Base.bind(vao::VertexArray) = glBindVertexArray(vao.id)
unbind(vao::VertexArray) = glBindVertexArray(0)

#does this ever work with anything aside from an unsigned int??
draw(vao::VertexArray{V, elements} where V) = glDrawElements(vao.face, totverts(vao), GL_UNSIGNED_INT, C_NULL)

draw(vao::VertexArray{V, elements_instanced} where V) = glDrawElementsInstanced(vao.face, totverts(vao), glitype(vao), C_NULL, vao.nprim)

draw(vao::VertexArray{V, simple} where V) = glDrawArrays(vao.face, 0, totverts(vao))

function Base.show(io::IO, vao::VertexArray)
    fields = filter(x->x != :buffers && x!=:indices, fieldnames(vao))
    for field in fields
        show(io, getfield(vao, field))
        println(io,"")
    end
end