
@enum VaoKind simple elements elements_instanced

mutable struct VertexArray{Vertex, Kind}
    id::GLuint
    buffers::Vector{<:Buffer}
    indices::Union{Buffer, Nothing}
    nverts::GLint #total vertices to be drawn in drawcall
    ninst::GLint
    face::GLenum
    context::AbstractContext
    function VertexArray(kind::VaoKind, attriblocs::Vector{GLint}, buffers::Vector{<:Buffer}, indices, ninst, face)
        id = glGenVertexArrays()
        glBindVertexArray(id)

        nverts = 0
        for b in buffers
            nverts_ = length(b)
            if nverts != 0 && nverts != nverts_
                error("Amount of vertices is not equal.")
            end
            nverts = nverts_
        end

        if indices != nothing
            bind(indices)
            nverts = length(indices)*cardinality(indices)
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

        obj = new{vert_type, kind}(id, buffers, indices, nverts, ninst, face, current_context())
        finalizer(free!, obj)
        obj
    end
end

VertexArray(attriblocs::Vector{GLint}, buffers::Vector{<:Buffer}, facelength::Int) =
    VertexArray(simple, attriblocs, buffers, nothing, 1, face2glenum(facelength))

VertexArray(attriblocs::Vector{GLint}, buffers::Vector{<:Buffer}, indices::Vector{Int}, facelength::Int) =
    VertexArray(elements, attriblocs, buffers, indexbuffer(indices), 1, face2glenum(facelength))

VertexArray(attriblocs::Vector{GLint}, buffers::Vector{<:Buffer}, indices::Vector{F}) where F =
    VertexArray(elements, attriblocs, buffers, indexbuffer(indices), 1, face2glenum(F))

VertexArray(buffers::Vector{Pair{GLint, Buffer}}, args...) =
    VertexArray(first.(buffers), last.(buffers), args...)
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

function attach2vao(buffers::Vector{<:Buffer}, attrib_location::Vector{GLint}, kind)
    for (b, location) in zip(buffers, attrib_location)
        if kind == elements_instanced
            attach2vao(b, location, true)
        else
            attach2vao(b, location)
        end
    end
end

# TODO
Base.convert(::Type{VertexArray}, x) = VertexArray(x)
Base.convert(::Type{VertexArray}, x::VertexArray) = x

function face2glenum(face)
    facelength = typeof(face) <: Integer ? face : (face <: Integer ? 1 : length(face))
    facelength == 1  && return GL_POINTS
    facelength == 2  && return GL_LINES
    facelength == 3  && return GL_TRIANGLES
    facelength == 4  && return GL_QUADS
    facelength == 5  && return GL_TRIANGLE_STRIP
    facelength == 11 && return GL_LINE_STRIP_ADJACENCY
    return GL_TRIANGLES
end

function glenum2face(glenum)
    glenum == GL_POINTS               && return 1
    glenum == GL_LINES                && return 2
    glenum == GL_TRIANGLES            && return 3
    glenum == GL_QUADS                && return 4
    glenum == GL_TRIANGLE_STRIP       && return 5
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

function Base.show(io::IO, vao::T) where T<:VertexArray
    fields = filter(x->x != :buffers && x!=:indices, [fieldnames(T)...])
    for field in fields
        show(io, getfield(vao, field))
        println(io,"")
    end
end

Base.eltype(::Type{VertexArray{ElTypes, Kind}}) where {ElTypes, Kind} = (ElTypes, Kind)
