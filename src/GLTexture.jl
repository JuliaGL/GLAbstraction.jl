
export Texture, texturetype, update!

#Supported datatypes
const TO_GL_TYPE = [
    GLubyte     => GL_UNSIGNED_BYTE,
    GLbyte      => GL_BYTE,
    GLuint      => GL_UNSIGNED_INT,
    GLushort    => GL_UNSIGNED_SHORT,
    GLshort     => GL_SHORT,
    GLint       => GL_INT,
    GLfloat     => GL_FLOAT
]
#Supported texture modes/dimensions
const TO_GL_TEXTURE_TYPE = [
    1 => GL_TEXTURE_1D,
    2 => GL_TEXTURE_2D,
    3 => GL_TEXTURE_3D
]
const DEFAULT_GL_COLOR_FORMAT = [
    1 => GL_RED,
    2 => GL_RG,
    3 => GL_RGB,
    4 => GL_RGBA,
]

glpixelformat{T <: FixedPoint}(x::Type{T}) = glpixelformat(FixedPointNumbers.rawtype(x))
glpixelformat(x::DataType) = get(TO_GL_TYPE, x) do
    error("Type: $(x) not supported as pixel datatype")
end
glpixelformat(x::AbstractArray) = glpixelformat(eltype(x))


glcolorformat(colordim::Int) = get(DEFAULT_GL_COLOR_FORMAT, colordim) do
    error("$(colordim)-dimensional colors not supported")
end
function glinternalcolorformat(colordim::Int, typ::DataType)
    sym = "GL_"
    sym *= colordim == 1 ? "R" : colordim == 2 ? "RG" : colordim == 3 ? "RGB" : colordim == 4 ? "RGBA" : error("$(colordim)-dimensional colors not supported")
    sym *= sizeof(typ) * 8 <= 32 ? string(sizeof(typ) * 8) : error("$(typ) has too many bits")
    sym *= typ <: FloatingPoint ? "F" : ""#typ <: Signed ? "I" : typ <: Unsigned ? "UI" : error("$(typ) is neither unsigned, signed nor floatingpoint")
    return eval(symbol(sym))
end
function getDefaultTextureParameters(dim::Int)
    parameters = [
        (GL_TEXTURE_WRAP_S,  GL_CLAMP_TO_EDGE),
        (GL_TEXTURE_MIN_FILTER, GL_LINEAR),
        (GL_TEXTURE_MAG_FILTER, GL_LINEAR)
    ]
    if dim <= 3 && dim > 1
        push!(parameters, (GL_TEXTURE_WRAP_T,  GL_CLAMP_TO_EDGE ))
    end
    if dim == 3
        push!(parameters, (GL_TEXTURE_WRAP_R,  GL_CLAMP_TO_EDGE ))
    end
    parameters
end



immutable Texture{T <: Real, ColorDIM, NDIM}
    id::GLuint
    pixeltype::GLenum
    internalformat::GLenum
    format::GLenum
    dims::Vector{Int}
    function Texture{T}(data::Ptr{T}, dims, internalformat, format, parameters::Vector{(GLenum, GLenum)})

        @assert all(x -> x > 0, dims)
 

        if isempty(parameters)
            parameters = getDefaultTextureParameters(length(dims))
        end

        internalformat  = internalformat == 0 ? glinternalcolorformat(ColorDIM, T) : internalformat
        format          = format == 0 ? glcolorformat(ColorDIM) : format
        ttype           = texturetype(length(dims)) # Dimensionality of texture#

        

        glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
        glPixelStorei(GL_UNPACK_ROW_LENGTH, 0)
        glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0)
        glPixelStorei(GL_UNPACK_SKIP_ROWS, 0)
        
        id = glGenTextures()
        glBindTexture(ttype, id)
        for elem in parameters
            glTexParameteri(ttype, elem...)
        end
        pixeltype = glpixelformat(T)

        glTexImage(0, internalformat, dims..., 0, format, pixeltype, data)
        new(id, pixeltype, internalformat, format, [ColorDIM, dims...])
    end
end

Base.size{T,C,D}(t::Texture{T,C,D}) = D
Base.size{T,C,D}(t::Texture{T,C,D}, I::Integer) = D[I]
function Base.show{T,C,D}(io::IO, t::Texture{T,C,D})
    println(io, "Texture: ")
    println(io, "                  ID: ", t.id)
    println(io, "                Size: ", reduce("[ColorDim: $(t.dims[1])]", t.dims[2:end]) do v0, v1
        v0*"x"*string(v1)
    end)
    println(io, "    Julia pixel type: ", T)
    println(io, "   OpenGL pixel type: ", GLENUM(t.pixeltype).name)
    println(io, "              Format: ", GLENUM(t.format).name)
    println(io, "     Internal format: ", GLENUM(t.internalformat).name)
end

texturetype{T,C,D}(t::Texture{T,C,D}) = texturetype(D)
texturetype(dim::Int) = get(TO_GL_TEXTURE_TYPE, dim) do
    error("$(dim)-dimensional textures not supported")
end

#intended usage: Array(Vector1/2/3/4{Uniont(Float32, Uint8, Int8)}, 1/2/3)
#1-3 dimensional array, with 1-4 dimensional color values
function Texture{T}(
                        data::Array{T};
                        internalformat=0, format=0, parameters::Vector{(GLenum, GLenum)}=(GLenum, GLenum)[]
                    )

    @assert length(data) > 0
    ptrtype, colordim   = opengl_compatible(typeof(data[1]))
    dims                = [size(data)...]
    if ptrtype == Float64
        data    = float32(data)
        ptrtype = Float32
    end
    Texture{ptrtype, colordim, length(dims)}(convert(Ptr{ptrtype}, pointer(data)), dims, internalformat, format, parameters)
end

function Texture{T <: Real}(
                    data::Array{T}, colordim::Integer;
                    internalformat = 0, format = 0, parameters::Vector{(GLenum, GLenum)} = (GLenum, GLenum)[]
                )
    if colordim == 1
        dims = [size(data)...]
    elseif colordim >= 2 && colordim <= 4
        dims = [size(data)[2:end]...]
    else
        error("wrong color dimension. Dimension: $(colordim)")
    end
    Texture{T, colordim, length(dims)}(convert(Ptr{T}, pointer(data)), dims, internalformat, format, parameters)
end

function Texture(
                    T::DataType, colordim, dims;
                    internalformat = 0, format = 0, parameters::Vector{(GLenum, GLenum)} = (GLenum, GLenum)[]
                )
    Texture{T, colordim, length(dims)}(convert(Ptr{T}, C_NULL), dims, internalformat, format, parameters)
end

function Texture(
                    img::Union(Image, String);
                    internalformat = 0, format = 0, parameters::Vector{(GLenum, GLenum)} = (GLenum, GLenum)[]
                )
    global IMAGES
    if isa(img, String)
        img = imread(img)
    end
    @assert length(img.data) > 0
    imgFormat   = colorspace(img)
    if imgFormat == "ARGB"
        tmp = img.data[1,1:end, 1:end]
        img.data[1,1:end, 1:end] = img.data[2,1:end, 1:end]
        img.data[2,1:end, 1:end] = img.data[3,1:end, 1:end]
        img.data[3,1:end, 1:end] = img.data[4,1:end, 1:end]
        img.data[4,1:end, 1:end] = tmp
        imgdata  = img.data
    elseif imgFormat == "Gray" || imgFormat == "RGB" || imgFormat == "BGRA" || imgFormat == "RGB4"
        imgdata = img.data
    else
        error("Color Format $(imgFormat) not supported")
    end
    if ndims(imgdata) == 2
        reversedim = 2
    else
        reversedim = 3
    end
    imgdata = mapslices(reverse, imgdata, reversedim)

    Texture(imgdata, internalformat=internalformat, format=format, parameters=parameters)
end


# Instead of having so many methods, this should rather be solved by a macro or with better fixed size arrays
function update!{T <: Real, ColorDim}(t::Texture{T, ColorDim, 2}, newvalue::Array{T, 3})
    @assert ColorDim == size(newvalue, 1)
    glBindTexture(texturetype(t), t.id)
    glTexSubImage2D(texturetype(t), 0, 0, 0, size(newvalue)[2:3]...,t.format, t.pixeltype, newvalue)
end
function update!{T <: Real}(t::Texture{T, 1, 2}, newvalue::Array{Vector1{T}, 2})
    glBindTexture(texturetype(t), t.id)
    glTexSubImage2D(texturetype(t), 0, 0, 0, size(newvalue)...,t.format, t.pixeltype, newvalue)
end
function update!{T <: Real}(t::Texture{T, 2, 2}, newvalue::Array{Vector2{T}, 2})
    glBindTexture(texturetype(t), t.id)
    glTexSubImage2D(texturetype(t), 0, 0, 0, size(newvalue)..., t.format, t.pixeltype, newvalue)
end
function update!{T <: Real}(t::Texture{T, 3, 2}, newvalue::Array{Vector3{T}, 2})
    glBindTexture(texturetype(t), t.id)
    glTexSubImage2D(texturetype(t), 0, 0, 0, size(newvalue)...,t.format, t.pixeltype, newvalue)
end
function update!{T <: Real}(t::Texture{T, 4, 2}, newvalue::Array{Vector4{T}, 2})
    glBindTexture(texturetype(t), t.id)
    glTexSubImage2D(texturetype(t), 0, 0, 0, size(newvalue)...,t.format, t.pixeltype, newvalue)
end


function update!{T <: Real, ColorDim}(t::Texture{T, ColorDim, 1}, newvalue::Array{T, 2})
    @assert ColorDim == size(newvalue, 1)
    glBindTexture(texturetype(t), t.id)
    glTexSubImage1D(texturetype(t), 0, 0, size(newvalue, 2), t.format, t.pixeltype, newvalue)
end
function update!{T <: Real}(t::Texture{T, 1, 1}, newvalue::Array{Vector1{T}, 1})
    glBindTexture(texturetype(t), t.id)
    glTexSubImage1D(texturetype(t), 0, 0, size(newvalue,1), t.format, t.pixeltype, newvalue)
end
function update!{T <: Real}(t::Texture{T, 2, 1}, newvalue::Array{Vector2{T}, 1})
    glBindTexture(texturetype(t), t.id)
    glTexSubImage1D(texturetype(t), 0, 0, size(newvalue,1),t.format, t.pixeltype, newvalue)
end
function update!{T <: Real}(t::Texture{T, 3, 1}, newvalue::Array{Vector3{T}, 1})
    glBindTexture(texturetype(t), t.id)
    glTexSubImage1D(texturetype(t), 0, 0, size(newvalue,1),t.format, t.pixeltype, newvalue)
end
function update!{T <: Real}(t::Texture{T, 4, 1}, newvalue::Array{Vector4{T}, 1})
    glBindTexture(texturetype(t), t.id)
    glTexSubImage1D(texturetype(t), 0, 0, size(newvalue,1),t.format, t.pixeltype, newvalue)
end