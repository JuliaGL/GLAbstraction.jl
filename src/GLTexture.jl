export Texture, texturetype, update!

SupportedEltypes = Union(AbstractArray, ColorValue, AbstractAlphaColorValue)
begin 
    #Supported datatypes
    local const TO_GL_TYPE = [
        GLubyte     => GL_UNSIGNED_BYTE,
        GLbyte      => GL_BYTE,
        GLuint      => GL_UNSIGNED_INT,
        GLushort    => GL_UNSIGNED_SHORT,
        GLshort     => GL_SHORT,
        GLint       => GL_INT,
        GLfloat     => GL_FLOAT
    ]
    glpixelformat{T <: Real}(x::Type{T}) = get(TO_GL_TYPE, x) do
        error("Type: $(x) not supported as pixel datatype")
    end
    glpixelformat{T <: FixedPoint}(x::Type{T})       = glpixelformat(FixedPointNumbers.rawtype(x))
    glpixelformat{T <: SupportedEltypes}(x::Type{T}) = glpixelformat(eltype(x))
    glpixelformat(x::SupportedEltypes)               = glpixelformat(eltype(x))
end
#Supported texture modes/dimensions
begin 
    local const TO_GL_TEXTURE_TYPE = [
        1 => GL_TEXTURE_1D,
        2 => GL_TEXTURE_2D,
        3 => GL_TEXTURE_3D
    ]
    default_texturetype(ndim::Integer) = get(TO_GL_TEXTURE_TYPE, ndim) do
        error("Dimensionality: $(ndim), not supported for OpenGL texture")
    end
end

immutable Texture{T <: Union(SupportedEltypes, Real), ColorDIM, NDIM}
    id::GLuint
    texturetype::GLenum
    pixeltype::GLenum
    internalformat::GLenum
    format::GLenum
    dims::Vector{Int}

    function Texture{T}(data::Ptr{T}, dims, ttype::GLenum, internalformat::GLenum, format::GLenum, parameters::Vector{(GLenum, GLenum)})
        @assert all(x -> x > 0, dims)

        id = glGenTextures()

        glBindTexture(ttype, id)

        glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
        glPixelStorei(GL_UNPACK_ROW_LENGTH, 0)
        glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0)
        glPixelStorei(GL_UNPACK_SKIP_ROWS, 0)

        for elem in parameters
            glTexParameteri(ttype, elem...)
        end

        pixeltype = glpixelformat(T)
        
        glTexImage(ttype, 0, internalformat, dims..., 0, format, pixeltype, data)
        new(id, ttype, pixeltype, internalformat, format, [dims...])
    end
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

default_colorformat{T <: Real}(colordim::Type{T})          = default_colorformat(1, T <: Integer, "RED")
default_colorformat{T <: AbstractArray}(colordim::Type{T}) = default_colorformat(length(T), eltype(T) <: Integer, "RGBA")
function default_colorformat{T <: AbstractAlphaColorValue}(colordim::Type{T}) 
    colororder = string(T.parameters[1].name) * "A"
    return default_colorformat(length(T), eltype(T) <: Integer, colororder)
end
default_colorformat{T <: ColorValue}(colordim::Type{T}) = default_colorformat(length(T), eltype(T) <: Integer, string(T.name))

function default_internalcolorformat(colordim::Int, typ::DataType)
    eltyp = eltype(typ)
    sym = "GL_"
    sym *= colordim == 1 ? "R" : colordim == 2 ? "RG" : colordim == 3 ? "RGB" : colordim == 4 ? "RGBA" : error("$(colordim)-dimensional colors not supported")
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
function gendefaults(texture_properties::Vector{(Symbol, Any)}, ColorDim::Integer, Typ::DataType, NDim::Integer)
    return merge([
        :internalformat  => default_internalcolorformat(ColorDim, T),
        :parameters      => default_textureparameters(NDim, eltype(T)),
        :texturetype     => default_texturetype(NDim),
        :format          => default_colorformat(T)
    ], Dict{Symbol, Any}(texture_properties))
end

#=
As Texture has a lot of variations with the same Keyword arguments, I decided to
map the keywords into one array, which I pass to the actual constructor 
=#
Texture(data... ; texture_properties...) = Texture(data..., convert(Vector{(Symbol, Any)}, texture_properties))

#=
Main constructor, which shouldn't be used. It will initializes all the missing values and pass it to the inner Texture constructor 
=#
function Texture{T <: SupportedEltypes}(data::Ptr{T}, dims::AbstractVector, texture_properties::Vector{(Symbol, Any)})

    NDim            = length(dims)
    ColorDim        = length(T)
    defaults        = gendefaults(texture_properties, ColorDim, T, NDim)
    
    Texture{T, ColorDim, NDim}(data, dims, defaults[:texturetype], defaults[:internalformat], defaults[:format], defaults[:parameters])
end

#= 
Constructor for empty initialization with NULL pointer instead of an array with data.
You just need to pass the wanted color/vector type and the dimensions. 
To which values the texture gets initialized is driver dependent
=#
function Texture{T <: SupportedEltypes}(datatype::Type{T}, dims::AbstractVector, texture_properties::Vector{(Symbol, Any)})
    Texture(convert(Ptr{T}, C_NULL), dims, texture_properties)
end

#=
Constructor for a normal array, with color or Abstract Arrays as elements.
So Array{Real, 2} == Texture2D with 1D Color dimension
Array{Vec1/2/3/4, 2} == Texture2D with 1/2/3/4D Color dimension
Colors from Colors.jl should mostly work as well
=#
function Texture{T <: SupportedEltypes, NDim}(image::Array{T, NDim}, texture_properties::Vector{(Symbol, Any)})
    Texture(pointer(image), [size(image)...], texture_properties)
end

#=
Some special treatmend for types, with alpha in the First place
=#
function Texture{T <: Real, NDim}(image::Array{ARGB{T}, NDim}, texture_properties::Vector{(Symbol, Any)})
    data = map(image) do colorvalue
        AlphaColorValue(colorvalue.c, colorvalue.alpha)
    end
    Texture(pointer(data), [size(data)...], texture_properties)
end

#= 
Creates a texture from an image, which lays on path
=#
Texture(path::String, texture_properties::Vector{(Symbol, Any)}) = Texture(imread(path), texture_properties)
#=
Creates a texture from an Image
=#
function Texture(image::Image, texture_properties::Vector{(Symbol, Any)})
    data = image.data
    Texture(mapslices(reverse, data, ndims(data)), texture_properties)
end


width(t::Texture)   = size(t,1) 
height(t::Texture)  = size(t,2) 
depth(t::Texture)   = size(t,3) 

Base.length(t::Texture) = prod(t.dims)

function Base.show{T,C,D}(io::IO, t::Texture{T,C,D})
    println(io, "Texture$(D)D: ")
    println(io, "                  ID: ", t.id)
    println(io, "                Size: ", reduce("[ColorDim: $(C)]", t.dims) do v0, v1
        v0*"x"*string(v1)
    end)
    println(io, "    Julia pixel type: ", T)
    println(io, "   OpenGL pixel type: ", GLENUM(t.pixeltype).name)
    println(io, "              Format: ", GLENUM(t.format).name)
    println(io, "     Internal format: ", GLENUM(t.internalformat).name)
end



Base.eltype{T,C,D}(t::Texture{T, C, D})         = T
Base.size{T,C,D}(t::Texture{T,C,D})             = t.dims
Base.size{T,C,D}(t::Texture{T,C,D}, I::Integer) = t.dims[I]
Base.endof(t::Texture)                          = prod(t.dims)
Base.ndims{T, C, D}(t::Texture{T, C, D})        = NDim

# Resize Texture
function Base.resize!{T, CD, ND}(t::Texture{T,CD,ND}, newdims)
  glBindTexture(t.texturetype, t.id)
  glTexImage(t.texturetype, 0, t.internalformat, newdims..., 0, t.format, t.pixeltype, C_NULL)
  t.dims[1:end] = newdims
  glBindTexture(t.texturetype, 0)
end


function Base.setindex!{T <: SupportedEltypes, ColorDim}(t::Texture{T, ColorDim, 1}, value, i::Integer)
    update!(t, value, i)
end
function Base.setindex!{T <: SupportedEltypes, ColorDim, IT1 <: Integer}(t::Texture{T, ColorDim, 1}, value, i::UnitRange{IT1})
    update!(t, value, first(i))
end
function Base.setindex!{T <: SupportedEltypes, ColorDim}(t::Texture{T, ColorDim, 2}, value, i::Integer, j::Integer)
    update!(t, value, i, j)
end
function Base.setindex!{T <: SupportedEltypes, ColorDim, IT1 <: Integer, IT2 <: Integer}(t::Texture{T, ColorDim, 2}, value, i::UnitRange{IT1}, j::UnitRange{IT2})
    update!(t, value, first(i), first(j))
end


# Instead of having so many methods, this should rather be solved by a macro or with better fixed size arrays

function update!{T <: SupportedEltypes, ColorDim}(t::Texture{T, ColorDim, 1}, newvalue::Array{T, 1}, xoffset = 0)
    update!(t, newvalue, xoffset, length(newvalue))
end
function update!{T <: SupportedEltypes, ColorDim}(t::Texture{T, ColorDim, 1}, newvalue::T, xoffset = 0)
    update!(t, newvalue, xoffset, 1)
end

function update!{T <: SupportedEltypes, ColorDim}(t::Texture{T, ColorDim, 1}, newvalue::Array, xoffset, _width)
    if (xoffset-1 + _width) > width(t)
        error("Out of bounds in texture, index ", xoffset, " width: ", _width, " texture:\n", t)
    end
    glBindTexture(t.texturetype, t.id)
    glTexSubImage1D(t.texturetype, 0, xoffset-1, _width, t.format, t.pixeltype, newvalue)
end


function update!{T <: SupportedEltypes, ColorDim}(t::Texture{T, ColorDim, 2}, newvalue::Array{T, 2}, xoffset = 0, yoffset = 0)
    update!(t, newvalue, xoffset, yoffset, size(newvalue)...)
end

function update!{T <: SupportedEltypes, ColorDim}(t::Texture{T, ColorDim, 2}, newvalue::T, xoffset = 0, yoffset = 0)
    update!(t, [newvalue], xoffset, yoffset, 1, 1)
end


function update!{T <: SupportedEltypes, ColorDim}(t::Texture{T, ColorDim, 2}, newvalue::Array, xoffset, yoffset, _width, _height) 
    if (xoffset-1 + _width) > width(t) && (yoffset-1 + _height) > height(t)
        error("Out of bounds in texture, xindex ", xoffset, " width: ", _width, " yindex: ", yoffset, " height: ", _height, " in texture:\n", t)
    end
    glBindTexture(t.texturetype, t.id)
    glTexSubImage2D(t.texturetype, 0, xoffset-1, yoffset-1, _width, _height, t.format, t.pixeltype, newvalue)
end