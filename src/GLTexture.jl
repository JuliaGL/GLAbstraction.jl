
#Supported texture modes/dimensions
function default_texturetype(ndim::Integer)
    ndim == 1 && return GL_TEXTURE_1D
    ndim == 2 && return GL_TEXTURE_2D
    ndim == 3 && return GL_TEXTURE_3D
    error("Dimensionality: $(ndim), not supported for OpenGL texture")
end

type Texture{T <: GLArrayEltypes, NDIM} <: GPUArray{T, NDIM}
    id              ::GLuint
    texturetype     ::GLenum
    pixeltype       ::GLenum
    internalformat  ::GLenum
    format          ::GLenum
    parameters      ::Vector{Tuple{GLenum, GLenum}}
    size            ::NTuple{NDIM, Int}
    buffer          ::Nullable{GLBuffer{T}} # Textures can be optionally created from a buffer, in which case we need a reference to the buffer
end
function set_parameters(t::Texture, parameters::Vector{Tuple{GLenum, GLenum}})
    parameters==t.parameters && return nothing
    for elem in parameters
        glTexParameteri(t.texturetype, elem...)
    end
    nothing
end

function Texture{T}(
        data::Ptr{T}, dims, ttype::GLenum, internalformat::GLenum, 
        format::GLenum, parameters::Vector{Tuple{GLenum, GLenum}}
    )

    id = glGenTextures()
    glBindTexture(ttype, id)

    #TO DO, get julias alignment
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0)
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0)
    glPixelStorei(GL_UNPACK_SKIP_ROWS, 0)

    for elem in parameters
        glTexParameteri(ttype, elem...)
    end

    pixeltype       = julia2glenum(T)
    NDim            = length(dims)

    glTexImage(ttype, 0, internalformat, dims..., 0, format, pixeltype, data)
    texture = Texture{T, NDim}(
        id, ttype, pixeltype, internalformat, format,
        default_textureparameters(NDim, T),
        tuple(dims...), Nullable{GLBuffer{T}}()
    )
    set_parameters(texture, parameters)
    #finalizer(obj, free)
    texture
end


#=
Main constructor, which shouldn't be used. It will initializes all the missing values and pass it to the inner Texture constructor
=#
function Texture{T <: GLArrayEltypes}(
        data::Vector{Array{T,2}}, 
        texture_properties::Vector{Tuple{Symbol, Any}}
    )
    Base.length{ET <: Real}(::Type{ET}) = 1
    NDim            = 3
    ColorDim        = length(T)
    defaults        = gendefaults(texture_properties, ColorDim, T, NDim)
    Texture(data, GL_TEXTURE_2D_ARRAY, defaults[:internalformat], defaults[:format], defaults[:parameters])
end

function Texture{T <: GLArrayEltypes}(data::Vector{Array{T,2}}, ttype::GLenum, internalformat::GLenum, format::GLenum, parameters::Vector{@compat(Tuple{GLenum, GLenum})})
    id = glGenTextures()
    glBindTexture(ttype, id)

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0)
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0)
    glPixelStorei(GL_UNPACK_SKIP_ROWS, 0)

    for elem in [
    (GL_TEXTURE_MIN_FILTER, GL_LINEAR),
    (GL_TEXTURE_MAG_FILTER, GL_LINEAR),
    (GL_TEXTURE_WRAP_S,  GL_CLAMP_TO_EDGE),
    (GL_TEXTURE_WRAP_T,  GL_CLAMP_TO_EDGE),
  ]
        glTexParameteri(ttype, elem...)
    end

    pixeltype = julia2glenum(T)

    layers  = length(data)
    dims    = map(size, data)
    maxdims = foldl((0,0), dims) do v0, x
        a = max(v0[1], x[1])
        b = max(v0[2], x[2])
        (a,b)
    end
    glTexStorage3D(GL_TEXTURE_2D_ARRAY, 1, internalformat, maxdims..., layers)
    for (layer, texel) in enumerate(data)
        width, height = size(texel)
        glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, layer-1, width, height, 1, format, pixeltype, texel)
    end

    Texture{T, 3}(id, ttype, pixeltype, internalformat, format, tuple(maxdims..., layers))

end
function default_colorformat(colordim::Integer, isinteger::Bool, colororder::String)
    if colordim > 4
        error("no colors with dimension > 4 allowed. Dimension given: ", colordim)
    end
    sym = "GL_"
    # Handle that colordim == 1 => RED instead of R
    color = colordim == 1 ? "RED" : colororder[1:colordim]
    integer = isinteger ? "_INTEGER" : ""
    sym *= color * integer
    return eval(symbol(sym))
end

default_colorformat{T <: Real}(colordim::Type{T})              = default_colorformat(1, T <: Integer, "RED")
default_colorformat{T <: AbstractArray}(colordim::Type{T})     = default_colorformat(length(T), eltype(T) <: Integer, "RGBA")
default_colorformat{T <: FixedVector}(colordim::Type{T})       = default_colorformat(length(T), eltype(T) <: Integer, "RGBA")
function default_colorformat{T <: AbstractAlphaColor}(colordim::Type{T})
    colororder = string(T.name.name)
    return default_colorformat(length(T), eltype(T) <: Integer, colororder)
end
default_colorformat{T <: Color}(colordim::Type{T}) = default_colorformat(length(T), eltype(T) <: Integer, string(T.name.name))

function default_internalcolorformat(colordim::Int, typ::DataType)
    if colordim > 4 || colordim < 1
        error("$(colordim)-dimensional colors not supported")
    end
    eltyp = eltype(typ)
    sym = "GL_"
    sym *= "RGBA"[1:colordim]
    bits = sizeof(eltyp) * 8
    sym *= bits <= 32 ? string(bits) : error("$(typ) has too many bits")
    if eltyp <: FloatingPoint
        sym *= "F"
    elseif eltyp <: FixedPoint
        sym *= eltyp <: Ufixed ? "" : "_SNORM"
    elseif eltyp <: Signed
        sym *= "I"
    elseif eltyp <: Unsigned
        sym *= "UI"
    end
    return eval(symbol(sym))
end

function default_textureparameters(dim::Int, typ::DataType)
    interpolation = typ <: Integer ? GL_NEAREST : GL_LINEAR # Integer texture are not allowed to interpolate!
    parameters = [
        (GL_TEXTURE_WRAP_S,  GL_CLAMP_TO_EDGE),
        (GL_TEXTURE_MIN_FILTER, interpolation),
        (GL_TEXTURE_MAG_FILTER, interpolation)
    ]
    if dim <= 3 && dim > 1
        push!(parameters, (GL_TEXTURE_WRAP_T,  GL_CLAMP_TO_EDGE ))
    end
    if dim == 3
        push!(parameters, (GL_TEXTURE_WRAP_R,  GL_CLAMP_TO_EDGE ))
    end
    parameters
end

# As the default parameters of a texture are dependent on the texture, this is done by a function.
# The function overwrites the defaults with values from texture_properties, so that one can customize the defaults
# Here is a good place for parameter checking, yet not implemented though...
function gendefaults(texture_properties::Vector{@compat(Tuple{Symbol, Any})}, ColorDim::Integer, Typ::DataType, NDim::Integer)
    return merge(@compat(Dict(
        :internalformat  => default_internalcolorformat(ColorDim, Typ),
        :parameters      => default_textureparameters(NDim, eltype(Typ)),
        :texturetype     => default_texturetype(NDim),
        :format          => default_colorformat(Typ)
    )), Dict{Symbol, Any}(texture_properties))
end

#=
As Texture has a lot of variations with the same Keyword arguments, I decided to
map the keywords into one array, which I pass to the actual constructor
=#
Texture(data... ; texture_properties...) = _Texture(data..., convert(Vector{@compat(Tuple{Symbol, Any})}, texture_properties))

#=
Main constructor, which shouldn't be used. It will initializes all the missing values and pass it to the inner Texture constructor
=#
function _Texture{T <: GLArrayEltypes}(data::Ptr{T}, dims::Union(AbstractVector, Tuple), texture_properties::Vector{@compat(Tuple{Symbol, Any})})
    Base.length{ET <: Real}(::Type{ET}) = 1
    NDim            = length(dims)
    ColorDim        = length(T)
    defaults        = gendefaults(texture_properties, ColorDim, T, NDim)
    Texture(data, dims, defaults[:texturetype], defaults[:internalformat], defaults[:format], defaults[:parameters])
end

#=
Constructor for empty initialization with NULL pointer instead of an array with data.
You just need to pass the wanted color/vector type and the dimensions.
To which values the texture gets initialized is driver dependent
=#
function _Texture{T <: GLArrayEltypes}(datatype::Type{T}, dims::Union(AbstractVector, Tuple), texture_properties::Vector{@compat(Tuple{Symbol, Any})})
    _Texture(convert(Ptr{T}, C_NULL), dims, texture_properties)
end

#=
Constructor for a normal array, with color or Abstract Arrays as elements.
So Array{Real, 2} == Texture2D with 1D Color dimension
Array{Vec1/2/3/4, 2} == Texture2D with 1/2/3/4D Color dimension
Colors from Colors.jl should mostly work as well
=#
function _Texture{T <: GLArrayEltypes, NDim}(image::Array{T, NDim}, texture_properties::Vector{@compat(Tuple{Symbol, Any})})
    _Texture(pointer(image), [size(image)...], texture_properties)
end


texture_buffer{T <: GLArrayEltypes}(buffer::Vector{T}) =
    _Texture(GLBuffer(buffer, buffertype=GL_TEXTURE_BUFFER, usage=GL_DYNAMIC_DRAW), Tuple{Symbol, Any}[])

function _Texture{T <: GLArrayEltypes}(buffer::GLBuffer{T}, texture_properties::Vector{Tuple{Symbol, Any}})
    texture_type = GL_TEXTURE_BUFFER
    id = glGenTextures()
    glBindTexture(texture_type, id)
    internalformat = default_internalcolorformat(length(T), T)
    glTexBuffer(texture_type, internalformat, buffer.id)
    Texture{T, 1}(
        id, texture_type, julia2glenum(T), internalformat, 
        default_colorformat(T), Tuple{GLenum, GLenum}[], 
        size(buffer), Nullable(buffer), 
    )
end

#=
Some special treatmend for types, with alpha in the First place

function Texture{T <: Real, NDim}(image::Array{ARGB{T}, NDim}, texture_properties::Vector{(Symbol, Any)})
    data = map(image) do colorvalue
        AlphaColorValue(colorvalue.c, colorvalue.alpha)
    end
    Texture(pointer(data), [size(data)...], texture_properties)
end
=#

#=
Creates a texture from an Image
=#
##function Texture(image::Image, texture_properties::Vector{(Symbol, Any)})
#    data = image.data
#    Texture(mapslices(reverse, data, ndims(data)), texture_properties)
#end


width(t::Texture)                          = size(t, 1)
height(t::Texture)                         = size(t, 2)
depth(t::Texture)                          = size(t, 3)


function Base.show{T,D}(io::IO, t::Texture{T,D})
    println(io, "Texture$(D)D: ")
    println(io, "                  ID: ", t.id)
    println(io, "                Size: ", reduce("[ColorDim: $(length(T))]", size(t)) do v0, v1
        v0*"x"*string(v1)
    end)
    println(io, "    Julia pixel type: ", T)
    println(io, "   OpenGL pixel type: ", GLENUM(t.pixeltype).name)
    println(io, "              Format: ", GLENUM(t.format).name)
    println(io, "     Internal format: ", GLENUM(t.internalformat).name)
end


# GPUArray interface:
function Base.unsafe_copy!{T}(a::Vector{T}, readoffset::Int, b::Texture{T, 1}, writeoffset::Int, len::Int)
    isnull(b.buffer) && error("copy! is only implemented for texture buffers for now")
    buffer = get(b.buffer)
    copy!(a, readoffset, buffer, writeoffset, len)
    glBindTexture(b.texturetype, b.id)
    glTexBuffer(b.texturetype, b.internalformat, buffer.id) # update texture
end
function Base.unsafe_copy!{T}(a::Texture{T, 1}, readoffset::Int, b::Vector{T}, writeoffset::Int, len::Int)
    isnull(a.buffer) && error("copy! is only implemented for texture buffers for now")
    buffer = get(a.buffer)
    copy!(buffer, readoffset, b, writeoffset, len)
    glBindTexture(a.texturetype, a.id)
    glTexBuffer(a.texturetype, a.internalformat, buffer.id) # update texture
end
function Base.unsafe_copy!{T}(a::Texture{T, 1}, readoffset::Int, b::Texture{T,1}, writeoffset::Int, len::Int)
    (isnull(a.buffer) || isnull(b.buffer)) && error("copy! is only implemented for texture buffers for now")
    abuffer, bbuffer = get(a.buffer), get(b.buffer)
    unsafe_copy!(abuffer, readoffset, bbuffer, writeoffset, len)

    glBindTexture(a.texturetype, a.id)
    glTexBuffer(a.texturetype, a.internalformat, abuffer.id) # update texture

    glBindTexture(b.texturetype, b.id)
    glTexBuffer(b.texturetype, b.internalformat, bbuffer.id) # update texture
end
function gpu_setindex!{T, I <: Integer}(t::Texture{T, 1}, newvalue::Array{T, 1}, indexes::UnitRange{I})
    if isnull(t.buffer)
        glBindTexture(t.texturetype, t.id)
        texsubimage(t, newvalue, indexes)
    else
        b = get(t.buffer)
        glBindTexture(t.texturetype, t.id)
        b[indexes] = newvalue # set buffer indexes
        glTexBuffer(t.texturetype, t.internalformat, b.id) # update texture
    end
end

function gpu_setindex!{T, N}(t::Texture{T, N}, newvalue::Array{T, N}, indexes::Union(UnitRange,Integer)...)
    glBindTexture(t.texturetype, t.id)
    texsubimage(t, newvalue, indexes...)
end


function gpu_setindex!{T}(target::Texture{T, 2}, source::Texture{T, 2}, fbo=glGenFramebuffers())
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_READ_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, 
                           GL_TEXTURE_2D, source.id, 0);
    glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, 
                           GL_TEXTURE_2D, target.id, 0);
    glDrawBuffer(GL_COLOR_ATTACHMENT1);
    w, h = map(minimum, zip(size(target), size(source)))
    glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, 
                      GL_COLOR_BUFFER_BIT, GL_NEAREST);
end



#=
function gpu_setindex!{T}(target::Texture{T, 2}, source::Texture{T, 2}, fbo=glGenFramebuffers())
    w, h = map(minimum, zip(size(target), size(source)))
    glCopyImageSubData( source.id, source.texturetype,
    0,0,0,0,
    target.id, target.texturetype,
    0,0,0,0, w,h,0);
end
=#
# Implementing the GPUArray interface
function gpu_data{T, ND}(t::Texture{T, ND})
    if isnull(t.buffer)
        result = Array(T, size(t))
        glBindTexture(t.texturetype, t.id)
        glGetTexImage(t.texturetype, 0, t.format, t.pixeltype, result)
        return result
    end
    return gpu_data(get(t.buffer))
end

function gpu_getindex{T}(t::GLAbstraction.Texture{T,1}, i::UnitRange{Int64})
    isnull(t.buffer) && error("getindex operation only defined for texture buffers")
    return get(t.buffer)[i]
end
export resize_nocopy!
function resize_nocopy!{T, ND}(t::Texture{T, ND}, newdims::Tuple{Vararg{Int}})
    glBindTexture(t.texturetype, t.id)
    glTexImage(t.texturetype, 0, t.internalformat, newdims..., 0, t.format, t.pixeltype, C_NULL)
    t.size = newdims
    t
end

similar{T, NDim}(t::Texture{T, NDim}, newdims::Int...) = similar(t, newdims)
function similar{T, NDim}(t::Texture{T, NDim}, newdims::NTuple{NDim, Int})
    if isnull(t.buffer)
        return Texture(
            Ptr{T}(C_NULL), 
            newdims, t.texturetype,
            t.pixeltype,
            t.internalformat,
            t.format,
            t.parameters
        )
    else
        buff = similar(get(t.buffer), newdims...)
        tex = _Texture(buff, Tuple{Symbol, Any}[])
        return tex
    end
end
# Resize Texture
function gpu_resize!{T, ND}(t::Texture{T, ND}, newdims::NTuple{ND, Int})
    if isnull(t.buffer) 
        # dangerous code right here...Better write a few tests for this
        newtex   = similar(t, newdims)
        old_size = size(t)
        gpu_setindex!(newtex, t)
        t.size   = newdims
        free(t)
        t.id     = newtex.id
        return t
    end
    # MUST. HANDLE. BUFFERTEXTURE. DIFFERENTLY ... Did I mention that this is ugly?
    buffer = get(t.buffer)
    resize!(buffer, newdims) 
    glBindTexture(t.texturetype, t.id)
    glTexBuffer(t.texturetype, t.internalformat, buffer.id) #update data in texture
    t.size   = newdims
    t
end

texsubimage{T}(t::Texture{T, 1}, newvalue::Array{T, 1}, xrange::UnitRange, level=0) = glTexSubImage1D(
    t.texturetype, level, first(xrange)-1, length(xrange), t.format, t.pixeltype, newvalue
)
texsubimage{T}(t::Texture{T, 2}, newvalue::Array{T, 2}, xrange::UnitRange, yrange::UnitRange, level=0) = glTexSubImage2D(
    t.texturetype, level, 
    first(xrange)-1, first(yrange)-1, length(xrange), length(yrange), 
    t.format, t.pixeltype, newvalue
)
texsubimage{T}(t::Texture{T, 3}, newvalue::Array{T, 3}, xrange::UnitRange, yrange::UnitRange, zrange::UnitRange, level=0) = glTexSubImage3D(
    t.texturetype, level, 
    first(xrange)-1, first(yrange)-1, first(zrange)-1, length(xrange), length(yrange), length(zrange), 
    t.format, t.pixeltype, newvalue
)


function Base.start{T}(t::Texture{T, 1})
    isnull(t.buffer) && error("start operation only defined for texture buffers")
    start(get(t.buffer))
end
function Base.next{T}(t::Texture{T, 1}, state::Tuple{Ptr{T}, Int})
    isnull(t.buffer) && error("next operation only defined for texture buffers")
    next(get(t.buffer), state)
end
function Base.done{T}(t::Texture{T, 1}, state::Tuple{Ptr{T}, Int})
    isnull(t.buffer) && error("done operation only defined for texture buffers")
    isdone = done(get(t.buffer), state)
    if isdone
        glBindTexture(t.texturetype, t.id)
        glTexBuffer(t.texturetype, t.internalformat, get(t.buffer).id)
    end
    isdone
end