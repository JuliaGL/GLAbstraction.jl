##############################################################################
abstract Shape
immutable Circle{T <: Real} <: Shape
    x::T
    y::T
    r::T
end

type Rectangle{T <: Real} <: Shape
    x::T
    y::T
    w::T
    h::T
end
export Circle, Rectangle, Shape
############################################################################
type GLShader
    id::GLuint
    state::String
    source::String
    shaderType::GLenum
    uniforms::Dict{Symbol, DataType}
    outs::Dict{Symbol, DataType}
    ins::Dict{Symbol, DataType}
end

immutable GLProgram
    id::GLuint
    vertpath::String
    fragpath::String
    #uniformFunc::Function # For performance reasons, all uniforms are set with one function
    #uniforms::(Symbol...)
end


function GLProgram(vertex::ASCIIString, fragment::ASCIIString, vertpath::String, fragpath::String)
    vertexShaderID::GLuint   = readshader(vertex, GL_VERTEX_SHADER, vertpath)
    fragmentShaderID::GLuint = readshader(fragment, GL_FRAGMENT_SHADER, fragpath)
    p = glCreateProgram()
    @assert p > 0
    glAttachShader(p, vertexShaderID)
    glAttachShader(p, fragmentShaderID)
    glLinkProgram(p)

    glDeleteShader(vertexShaderID)
    glDeleteShader(fragmentShaderID)
    return GLProgram(p, vertpath, fragpath)
end
function GLProgram(vertex_file_path::ASCIIString, fragment_file_path::ASCIIString)
    
    vertsource  = readall(open(vertex_file_path))
    fragsource  = readall(open(fragment_file_path))
    vertname    = basename(vertex_file_path)
    fragname    = basename(fragment_file_path)
    GLProgram(vertsource, fragsource, vertex_file_path, fragment_file_path)
end
export GLProgram
##########################################################################

abstract Camera

type PerspectiveCamera <: Camera
    #width and height in pixel
    w::Float32
    h::Float32
    nearClip::Float32
    farClip::Float32
    horizontalAngle::Float32
    verticalAngle::Float32
    rotationSpeed::Float32
    zoomSpeed::Float32
    moveSpeed::Float32
    FoV::Float32
    position::Vector{Float32}
    direction::Vector{Float32}
    right::Vector{Float32}
    up::Vector{Float32}
    view::Matrix{Float32}
    projection::Matrix{Float32}
    lookAt::Vector{Float32}
    function PerspectiveCamera(
                    nearClip::Float32,
                    farClip::Float32,
                    horizontalAngle::Float32,
                    verticalAngle::Float32,
                    rotationSpeed::Float32,
                    zoomSpeed::Float32,
                    moveSpeed::Float32,
                    FoV::Float32,
                    position::Vector{Float32},
                    lookAt::Vector{Float32})

        cam = new(500f0, 500f0, nearClip, farClip, horizontalAngle, verticalAngle,
            rotationSpeed, zoomSpeed, moveSpeed, FoV, position, [0f0, 0f0, 0f0],
            [0f0, 0f0, 0f0], [0f0,1f0,0f0], eye(Float32,4,4), eye(Float32,4,4), lookAt)

        rotate(0f0, 0f0, cam)
        update(cam)
        return cam
    end
end


type OrthogonalCamera <: Camera
    #width and height in pixel
    w::Float32
    h::Float32
    angle::Float32
    nearClip::Float32
    farClip::Float32
    rotationSpeed::Float32
    zoomSpeed::Float32
    moveSpeed::Float32
    position::Array{Float32, 1}
    mvp::Matrix{Float32}
    function OrthogonalCamera(
                    nearClip::Float32,
                    farClip::Float32,
                    angle::Float32,
                    rotationSpeed::Float32,
                    zoomSpeed::Float32,
                    moveSpeed::Float32,
                    position::Array{Float32, 1})

        cam = new(500f0, 500f0, angle, nearClip, farClip,
            rotationSpeed, zoomSpeed, moveSpeed, position, eye(Float32,4,4))
        update(cam)
        return cam
    end
end

export Camera, OrthogonalCamera, PerspectiveCamera


########################################################################################
#12 seconds loading are wasted here

import Images.imread
import Images.Image
export Texture, texturetype

#Supported datatypes
const TO_GL_TYPE = [
    GLubyte     => GL_UNSIGNED_BYTE,
    GLbyte      => GL_BYTE,
    GLuint      => GL_UNSIGNED_INT,
    GLshort     => GL_UNSIGNED_SHORT,
    GLushort    => GL_SHORT,
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

const TEXTURE_COMPATIBLE_NUMBER_TYPES = Union(collect(keys(TO_GL_TYPE))...)

glpixelformat(x::DataType) = get(TO_GL_TYPE, x) do
    error("Type: $(x) not supported as pixel datatype")
end
glpixelformat(x::AbstractArray) = glpixelformat(eltype(x))


texturetype(dim::Int) = get(TO_GL_TEXTURE_TYPE, dim) do
    error("$(dim)-dimensional textures not supported")
end
glcolorformat(colordim::Int) = get(DEFAULT_GL_COLOR_FORMAT, colordim) do
    error("$(colordim)-dimensional colors not supported")
end

function getDefaultTextureParameters(dim::Int)
    parameters = [
        (GL_TEXTURE_WRAP_S,  GL_CLAMP_TO_EDGE ),
        (GL_TEXTURE_MIN_FILTER, GL_NEAREST),
        (GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    ]
    if dim <= 3 && dim > 1
        push!(parameters, (GL_TEXTURE_WRAP_T,  GL_CLAMP_TO_EDGE ))
    end
    if dim == 3
        push!(parameters, (GL_TEXTURE_WRAP_R,  GL_CLAMP_TO_EDGE ))
    end
    parameters
end


immutable Texture{T <: TEXTURE_COMPATIBLE_NUMBER_TYPES, ColorDIM, NDIM}
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

        internalformat  = internalformat==0? glcolorformat(ColorDIM) : internalformat
        format          = format==0? glcolorformat(ColorDIM) : format

        ttype     = texturetype(length(dims)) # Dimensionality of texture

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

texturetype{T,C,D}(t::Texture{T,C,D}) = texturetype(D)


#intended usage: Array(Vector1/2/3/4{Uniont(Float32, Uint8, Int8)}, 1/2/3)
#1-3 dimensional array, with 1-4 dimensional color values
function Texture{T}(
                        data::Array{T};
                        internalformat=0, format=0, parameters::Vector{(GLenum, GLenum)}=(GLenum, GLenum)[]
                    )

    @assert length(data) > 0
    ptrtype, colordim   = opengl_compatible(typeof(data[1]))
    dims                = [size(data)...]

    Texture{ptrtype, colordim, length(dims)}(convert(Ptr{ptrtype}, pointer(data)), dims, internalformat, format, parameters)
end

function Texture{T <: Real}(
                    data::Array{T}, colordim;
                    internalformat = 0, format = 0, parameters::Vector{(GLenum, GLenum)} = (GLenum, GLenum)[]
                )
    if colordim == 1
        dims = [size(data)...]
    elseif colordim >= 2 && colordim <= 4
        dims = [size(data)[2:end]...]
    else
        error("wrong color dimension. Dimension: $(colordim)")
    end
    Texture{T, colordim, length(dims)}(convert(Ptr{T}, pointer(data)), colordim, dims, internalformat, format, parameters)
end


function Texture(
                    img::Union(Image, String);
                    internalformat = 0, format = 0, parameters::Vector{(GLenum, GLenum)} = (GLenum, GLenum)[]
                )
    if isa(img, String)
        img = imread(img)
    end
    @assert length(img.data) > 0
    colordim    = length(img.properties["colorspace"])
    imgFormat   = img.properties["colorspace"]

    if imgFormat == "ARGB"
        tmp = img.data[1,1:end, 1:end]
        img.data[1,1:end, 1:end] = img.data[2,1:end, 1:end]
        img.data[2,1:end, 1:end] = img.data[3,1:end, 1:end]
        img.data[3,1:end, 1:end] = img.data[4,1:end, 1:end]
        img.data[4,1:end, 1:end] = tmp
        imgdata  = img.data
        colordim = 4
    elseif imgFormat == "RGB"
        imgdata = img.data
        colordim = 3
    elseif imgFormat == "Gray"
        imgdata = img.data
    else
        error("Color Format $(imgFormat) not supported")
    end
    
    Texture(mapslices(reverse,imgdata, [2]), colordim, internalformat=internalformat, format=format, parameters=parameters)
end

########################################################################

function opengl_compatible(T::DataType)
    if !isbits(T)
        error("only pointer free, immutable types are supported for upload to OpenGL. Found type: $(T)")
    end
    elemtype = T.types[1]
    if !(elemtype <: Real)
        error("only real numbers are allowed as element types for upload to OpenGL. Found type: $(T) with $(ptrtype)")
    end
    if !all(x -> x == elemtype , T.types)
        error("all values in $(T) need to have the same type to create a GLBuffer")
    end
    cardinality = length(names(T))
    if cardinality > 4
        error("there should be at most 4 values in $(T) to create a GLBuffer")
    end
    elemtype, cardinality
end
immutable GLBuffer{T <: Real}
    id::GLuint
    length::Int
    cardinality::Int
    buffertype::GLenum
    usage::GLenum

    function GLBuffer(ptr::Ptr{T}, size::Int, cardinality::Int, buffertype::GLenum, usage::GLenum)
        @assert size % sizeof(T) == 0
        _length = div(size, sizeof(T))
        @assert _length % cardinality == 0
        _length = div(_length, cardinality)

        id = glGenBuffers()
        glBindBuffer(buffertype, id)
        glBufferData(buffertype, size, ptr, usage)
        glBindBuffer(buffertype, 0)

        new(id, _length, cardinality, buffertype, usage)
    end
end


#Function to deal with any Immutable type with Real as Subtype
function GLBuffer{T <: AbstractArray}(
            buffer::Vector{T};
            buffertype::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW
        )
    #This is a workaround, to deal with all kinds of immutable vector types
    ptrtype, cardinality = opengl_compatible(T)
    ptr = convert(Ptr{ptrtype}, pointer(buffer))
    GLBuffer{ptrtype}(ptr, sizeof(buffer), cardinality, buffertype, usage)
end

function GLBuffer{T <: Real}(
            buffer::Vector{T}, cardinality::Int;
            buffertype::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW
        )
    GLBuffer{T}(convert(Ptr{T}, pointer(buffer)), sizeof(buffer), cardinality, buffertype, usage)
end
function indexbuffer(buffer; usage::GLenum = GL_STATIC_DRAW)
    GLBuffer(buffer, 1, buffertype = GL_ELEMENT_ARRAY_BUFFER, usage=usage)
end

immutable GLVertexArray
  program::GLProgram
  id::GLuint
  length::Int
  indexlength::Int # is negative if not indexed

  function GLVertexArray(bufferDict::Dict{Symbol, GLBuffer}, program::GLProgram)
    @assert !isempty(bufferDict)
    #get the size of the first array, to assert later, that all have the same size
    indexSize = -1
    _length = get(bufferDict, collect(keys(bufferDict))[1], 0).length
    id = glGenVertexArrays()
    glBindVertexArray(id)
    for elem in bufferDict
      buffer      = elem[2]
      if buffer.buffertype == GL_ELEMENT_ARRAY_BUFFER
        glBindBuffer(buffer.buffertype, buffer.id)
        indexSize = buffer.length
      else
        attribute   = string(elem[1])
        @assert _length == buffer.length
        glBindBuffer(buffer.buffertype, buffer.id)
        attribLocation = get_attribute_location(program.id, attribute)

        glVertexAttribPointer(attribLocation, buffer.cardinality, GL_FLOAT, GL_FALSE, 0, 0)
        glEnableVertexAttribArray(attribLocation)
      end
    end
    glBindVertexArray(0)
    new(program, id, _length, indexSize)
  end
end
function GLVertexArray(bufferDict::Dict{ASCIIString, GLBuffer}, program::GLProgram)
    GLVertexArray(Dict{Symbol, GLBuffer}(map(elem -> (symbol(elem[1]), elem[2]), bufferDict)), program)
end
export GLVertexArray, GLBuffer, indexbuffer, opengl_compatible

##################################################################################


immutable RenderObject
    uniforms::Vector{Any}
    vertexarray::GLVertexArray
    preRenderFunctions::Array{(Function, Tuple), 1}
    postRenderFunctions::Array{(Function, Tuple), 1}

    function RenderObject(data::Dict{Symbol, Any}, program::GLProgram)

        buffers     = filter((key, value) -> isa(value, GLBuffer), data)
        uniforms    = filter((key, value) -> !isa(value, GLBuffer), data)
        if length(buffers) > 0
            vertexArray = GLVertexArray(Dict{Symbol, GLBuffer}(buffers), program)
        end
        textureTarget::GLint = -1
        uniforms = map(attributes -> begin
                loc = get_uniform_location(program.id, attributes[1])

                if isa(attributes[2], Texture)
                    textureTarget += 1
                    return (loc, textureTarget, attributes[2])
                else
                    return (loc, attributes[2])
                end
            end, uniforms)

        new(uniforms, vertexArray, (Function, Tuple)[], (Function, Tuple)[])
    end
end
RenderObject{T}(data::Dict{Symbol, T}, program::GLProgram) = RenderObject(Dict{Symbol, Any}(data), program)

function pushfunction!(target::Vector{(Function, Tuple)}, fs...)
    func = fs[1]
    args = {}
    for i=2:length(fs)
        elem = fs[i]
        if isa(elem, Function)
            push!(target, (func, tuple(args...)))
            func = elem
            args = {}
        else
            push!(args, elem)
        end
    end
    push!(target, (func, tuple(args...)))
end
prerender!(x::RenderObject, fs...)   = pushfunction!(x.preRenderFunctions, fs...)
postrender!(x::RenderObject, fs...)  = pushfunction!(x.postRenderFunctions, fs...)



export RenderObject, prerender!, postrender!
####################################################################################



