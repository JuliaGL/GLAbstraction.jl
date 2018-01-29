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

struct VertexArray{Vertex, Face, IT}
    id::GLuint
    nverts::Int
    nprim::Int 
    indices::IT
    kind::Symbol 
    context::AbstractContext
    function (::Type{VertexArray{Vertex, Face}}){Vertex, Face, IT}(id, bufferlength, indices::IT, kind)
        new{Vertex, Face, IT}(id, bufferlength, indices, kind, current_context())
    end
end
function VertexArray(buffers::Vector{<:Buffer}, indices, attrib_location=0)
    id = glGenVertexArrays()
    glBindVertexArray(id)
    face_type = if isa(indices, Buffer)
        bind(indices)
        eltype(indices)
    elseif isa(indices, DataType) && indices <: Face
        indices
    # elseif isa(indices, Integer) #what is the idea behind this
    #     Face{1, OffsetInteger{1, GLint}}
    else
        error("indices must be Int, Buffer or Face type")
    end

    #pretty convoluted and ugly but should work. Also I think this is robust?
    kind = :elements
    len1 = length(buffers[1])
    len2 = 1
    for b in buffers
        if len2 == 1
            if length(b) == len
                continue
            else
                len2 = length(b)
                kind = :elements_instanced
            end
        else
            if length(b) == len2
                continue
            else
                error("Wrong size of buffer $b inside instanced vao of length(instances) = $len2")
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
    obj = VertexArray{vert_type, face_type}(id, len1, len2, indices, kind)
    obj
end
VertexArray(buffer::Buffer, args...) = VertexArray([buffer], args)
function VertexArray{T}(buffer::AbstractArray{T}, attrib_location = 0; face_type = gl_face_type(T))
    VertexArray([Buffer(buffer)], face_type, attrib_location)
end

function VertexArray{T, AT <: AbstractArray, IT <: AbstractArray}(
        view::SubArray{T, 1, AT, Tuple{IT}, false}, attrib_location = 0; face_type = nothing # TODO figure out better ways then ignoring face type
    )
    indexes = view.indexes[1]
    buffer = view.parent
    VertexArray(Buffer(buffer), indexbuffer(indexes), attrib_location)
end

# TODO
Base.convert(::Type{VertexArray}, x) = VertexArray(x)
Base.convert(::Type{VertexArray}, x::VertexArray) = x

gl_face_enum{V, IT, T <: Integer}(::VertexArray{V, T, IT}) = GL_POINTS
gl_face_enum{V, IT, I}(::VertexArray{V, Face{1, I}, IT}) = GL_POINTS
gl_face_enum{V, IT, I}(::VertexArray{V, Face{2, I}, IT}) = GL_LINES
gl_face_enum{V, IT, I}(::VertexArray{V, Face{3, I}, IT}) = GL_TRIANGLES

# gl_face_type(::Type{<: NTuple{2, <: AbstractVertex}}) = Face{2, Int}
gl_face_type(::Type) = Face{1, Int} # Default to Point
gl_face_type(::Type{T}) where T <: Face = T

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

function draw{V, T, IT <: Buffer}(vao::VertexArray{V, T, IT})
    fenum    = gl_face_enum(vao)
    totverts = vao.nverts * cardinality(vao.indices)
    itype    = julia2glenum(eltype(IT))
    if vao.kind == :elements_instanced
        glDrawElementsInstanced(fenum, totverts, itype, C_NULL, vao.nprim)
    else
        glDrawElements(fenum, totverts, itype, C_NULL)
    end
end
function draw{V, T}(vbo::VertexArray{V, T, DataType})
    glDrawArrays(gl_face_enum(vbo), 0, length(vbo))
end