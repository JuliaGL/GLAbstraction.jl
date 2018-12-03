# the instanced ones assume that there is at least one buffer with the vertextype (=has fields, bit whishy washy) and the others are the instanced things

function attach2vao(buffer::Buffer{T}, attrib_location, instanced=false) where T
    bind(buffer)
    if !is_glsl_primitive(T)
        # This is for a buffer that holds all the attributes in a OpenGL defined way.
        # This requires us to find the fieldoffset
        for i = 1:nfields(T)
            FT = fieldtype(T, i); ET = eltype(FT)
            glVertexAttribPointer(attrib_location,
                                  cardinality(FT), julia2glenum(ET),
                                  GL_FALSE, sizeof(T), Ptr{Void}(fieldoffset(T, i)))
            glEnableVertexAttribArray(attrib_location)
        end
    else
        # This is for when the buffer holds a single attribute, no need to
        # calculate fieldoffsets and stuff like that.
        FT = T; ET = eltype(FT)
        glVertexAttribPointer(attrib_location,
                              cardinality(FT), julia2glenum(ET),
                              GL_FALSE, 0, C_NULL)
        glEnableVertexAttribArray(attrib_location)
        if instanced
            glVertexAttribDivisor(attrib_location, 1)
        end
    end
end

function attach2vao(buffers::Vector{<:Buffer}, attrib_location::Vector{Int}, kind)
    for (b, loc) in zip(buffers, attrib_location)
        if kind == elements_instanced
            attach2vao(b, loc, true)
        else
            attach2vao(b, loc)
        end
    end
end

@enum VaoKind simple elements elements_instanced

mutable struct VertexArray{Vertex, Kind}
    id::GLuint
    buffers::Vector{<:Buffer}
    indices::Union{Buffer, Nothing}
    nverts::Int32 #total vertices to be drawn in drawcall
    ninst::Int32
    face::GLenum
    context::AbstractContext
    function (::Type{VertexArray{Vertex, Kind}})(id, buffers, indices, nverts, ninst, face) where {Vertex, Kind}
        obj = new{Vertex, Kind}(id, buffers, indices, Int32(nverts), Int32(ninst), face, current_context())
        finalizer(free!, obj)
        obj
    end
end


#TODO just improve this, basically only rely on facelength being defined...
#     then you can still define different Vao constructors for point indices etc...
function VertexArray(buffers::Vector{<:Buffer}, attriblocs::Vector{<:Integer}, indices::Union{Nothing, Vector, Buffer}; facelength = 1, instances=1)
    id = glGenVertexArrays()
    glBindVertexArray(id)

    if indices != nothing
        ind_buf = indexbuffer(indices)
        bind(ind_buf)
        kind = elements
    else
        kind = simple
        ind_buf = nothing
    end

    if facelength == 1
        face = eltype(indices) <: Integer ? face2glenum(eltype(indices)) : face2glenum(facelength)
    else
        face = face2glenum(facelength)
    end
    if instances != 1
        kind = elements_instanced
    end
    #check such that all buffers have the same amount of vertices
    nverts = 0
    for b in buffers
        nverts_ = length(b)
        if nverts != 0 && nverts != nverts_
            error("Amount of vertices is not equal.")
        end
        nverts = nverts_
    end
    if ind_buf != nothing
        nverts = length(ind_buf)*cardinality(ind_buf)
    end
    if kind == elements_instanced #TODO we definitely need to fix this mess
        attach2vao(buffers, attriblocs, elements)
    else
        attach2vao(buffers, attriblocs, kind)
    end

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
    return VertexArray{vert_type, kind}(id, buffers, ind_buf, nverts, instances, face)
end

VertexArray(buffers::Vector{Pair{Buffer, Int64}}, args...;kwargs...) =
    VertexArray(first.(buffers), last.(buffers), args... ; kwargs...)
VertexArray(buffers::Buffer...; args...) = VertexArray(buffers, nothing; args...)
VertexArray(buffers::NTuple{N, Buffer} where N; args...) = VertexArray(buffers, nothing; args...)
# TODO
Base.convert(::Type{VertexArray}, x) = VertexArray(x)
Base.convert(::Type{VertexArray}, x::VertexArray) = x

function face2glenum(face)
    facelength = typeof(face) <: Integer ? face : (face <: Integer ? 1 : length(face))
    facelength == 1 && return GL_POINTS
    facelength == 2 && return GL_LINES
    facelength == 3 && return GL_TRIANGLES
    facelength == 4 && return GL_QUADS
    facelength == 11 && return GL_LINE_STRIP_ADJACENCY
    return GL_TRIANGLES
end

function glenum2face(glenum)
    glenum == GL_POINTS    && return 1
    glenum == GL_LINES     && return 2
    glenum == GL_TRIANGLES && return 3
    glenum == GL_QUADS     && return 4
    glenum == GL_LINE_STRIP_ADJACENCY && return 11
    return 1
end

is_struct(::Type{T}) where T = !(sizeof(T) != 0 && nfields(T) == 0)
# is_glsl_primitive{T <: StaticVector}(::Type{T}) = true
is_glsl_primitive(::Type{T}) where {T <: Union{Float32, Int32}}= true
function is_glsl_primitive(T)
    glasserteltype(T)
    true
end

_typeof(::Type{T}) where T = Type{T}
_typeof(::T) where T = T

function free!(x::VertexArray)
    if !is_current_context(x.context)
        return x
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
totverts(vao::VertexArray) = vao.indices == nothing ? vao.nverts : length(vao.indices) * cardinality(vao.indices)

Base.length(vao::VertexArray) = vao.nverts

bind(vao::VertexArray) = glBindVertexArray(vao.id)
unbind(vao::VertexArray) = glBindVertexArray(0)

#does this ever work with anything aside from an unsigned int??
draw(vao::VertexArray{V, elements} where V) = glDrawElements(vao.face, vao.nverts, GL_UNSIGNED_INT, C_NULL)

draw(vao::VertexArray{V, elements_instanced} where V) = glDrawElementsInstanced(vao.face, totverts(vao), glitype(vao), C_NULL, vao.ninst)

draw(vao::VertexArray{V, simple} where V) = glDrawArrays(vao.face, 0, totverts(vao))

function Base.show(io::IO, vao::VertexArray)
    fields = filter(x->x != :buffers && x!=:indices, fieldnames(vao))
    for field in fields
        show(io, getfield(vao, field))
        println(io,"")
    end
end

Base.eltype(::Type{VertexArray{ElTypes, Kind}}) where {ElTypes, Kind} = (ElTypes, Kind)
