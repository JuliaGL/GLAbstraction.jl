using ModernGL
##############################################################################
abstract Shape
immutable Circle{T <: Real} <: Shape
    x::T
    y::T
    r::T
end

immutable Rectangle{T <: Real} <: Shape
    x::T
    y::T
    w::T
    h::T
end
export Circle, Rectangle, Shape
############################################################################

immutable GLProgram
    id::GLuint
    fragShaderPath::ASCIIString
    vertShaderPath::ASCIIString
    function GLProgram(vertex_file_path::String, fragment_file_path::String)
        vertexShaderID::GLuint   = readShader(open(vertex_file_path),   GL_VERTEX_SHADER)
        fragmentShaderID::GLuint = readShader(open(fragment_file_path), GL_FRAGMENT_SHADER)
        p = glCreateProgram()
        @assert p > 0
        glAttachShader(p, vertexShaderID)
        glAttachShader(p, fragmentShaderID)
        glLinkProgram(p)
        printProgramInfoLog(p)
        glDeleteShader(vertexShaderID)
        glDeleteShader(fragmentShaderID)
        return new(p, vertex_file_path, fragment_file_path)
    end
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
    position::Array{Float32, 1}
    direction::Array{Float32, 1}
    right::Array{Float32, 1}
    up::Array{Float32, 1}
    mvp::Matrix{Float32}
    function PerspectiveCamera(
                    nearClip::Float32,
                    farClip::Float32,
                    horizontalAngle::Float32,
                    verticalAngle::Float32,
                    rotationSpeed::Float32,
                    zoomSpeed::Float32,
                    moveSpeed::Float32,
                    FoV::Float32,
                    position::Array{Float32, 1})

        cam = new(500f0, 500f0, nearClip, farClip, horizontalAngle, verticalAngle, 
            rotationSpeed, zoomSpeed, moveSpeed, FoV, position, [0f0, 0f0, 0f0], 
            [0f0, 0f0, 0f0], [0f0,1f0,0f0], eye(Float32,4,4))

        rotate(0f0, 0f0, cam)
        update(cam)
        return cam
    end
end


type OrthogonalCamera  <: Camera
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

import Images.imread
import Images.Image

export Texture

immutable Texture
    id::GLuint
    textureType::GLenum
    pixelDataFormat::GLenum
    dims::Vector{Int}

    function Texture(data::Array, dims::Vector{Int}, textureType::GLenum, pixelDataFormat::GLenum, parameters::Vector{(GLenum, GLenum)})
       
        @assert all(x -> x > 0, dims) && length(data) > 0
        imgType = eltype(data)

        if imgType == Uint8
            glImgType = GL_UNSIGNED_BYTE
        elseif imgType == Float32
            glImgType = GL_FLOAT
        elseif imgType == Int8
            glImgType = GL_BYTE
        else 
            error("Type: $(imgType) not supported")
        end

        id = glGenTextures()

        glBindTexture(textureType, id)

        for elem in parameters
            glTexParameteri(textureType, elem...)
        end

        if textureType == GL_TEXTURE_1D
            texImageFunc = glTexImage1D
        elseif textureType == GL_TEXTURE_2D
            texImageFunc = glTexImage2D
        elseif textureType == GL_TEXTURE_3D
            texImageFunc = glTexImage3D
        else
            error("wrong target texture type. valid are: GL_Texture_1D, GL_Texture_2D, GL_Texture_3D")
        end

        texImageFunc(textureType, 0, pixelDataFormat, dims..., 0, pixelDataFormat, glImgType, data)
        #@assert glGetError() == GL_NO_ERROR
        new(id, textureType, pixelDataFormat, dims)
    end

end


function Texture(data::Array, textureType::GLenum;
                    parameters::Vector{(GLenum, GLenum)} = [(GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE), (GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE), (GL_TEXTURE_MIN_FILTER, GL_LINEAR)])
    dims = [size(data)...]
    glDims = Int[0]
    dimOffset = 0

    if textureType == GL_TEXTURE_1D
        dimOffset = -1
    elseif textureType == GL_TEXTURE_2D
        dimOffset = 0
    elseif textureType == GL_TEXTURE_3D
        dimOffset = 1
    else
        error("wrong target texture type. valid are: GL_Texture_1D, GL_Texture_2D, GL_Texture_3D")
    end

    if length(dims) == 2 + dimOffset
        glDims = dims
        pixelDataFormat = GL_LUMINANCE
    elseif length(dims) == 3 + dimOffset
        if dims[1] == 3
            glDims = dims[2:end]
            pixelDataFormat = GL_RGB
        elseif dims[1] == 4
            glDims = dims[2:end]
            pixelDataFormat = GL_RGBA
        else 
            error("wrong color dimensions. dims: $(dims[1])")
        end
    else
        error("wrong image dimensions. dims: $(dims)")
    end
    Texture(data, glDims, textureType, pixelDataFormat, parameters)
end



function Texture(img::Union(String, Image);
                    targetFormat::GLenum = GL_RGB, textureType::GLenum = GL_TEXTURE_2D, 
                    parameters = [(GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE), (GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE), (GL_TEXTURE_MIN_FILTER, GL_LINEAR)])
    #@assert glGetError() == GL_NO_ERROR
    if isa(img, String)
        img = imread(img)
    end
    
    @assert length(img.data) > 0
    imgFormat   = img.properties["colorspace"]
    #glTexImage2D needs to know the pixel data format from imread, the type and the targetFormat
    pixelDataFormat::GLenum = 0
    imgType                 = eltype(img.data)
    glImgType::GLenum       = 0
    glImgData1D = imgType[]
    dims = [0]
    if imgFormat == "ARGB"
        pixelDataFormat = GL_RGBA
        tmp = img.data[1,1:end, 1:end]
        img.data[1,1:end, 1:end] = img.data[2,1:end, 1:end]
        img.data[2,1:end, 1:end] = img.data[3,1:end, 1:end]
        img.data[3,1:end, 1:end] = img.data[4,1:end, 1:end]
        img.data[4,1:end, 1:end] = tmp
        glImgData1D  = img.data

        dims = [size(img)[2:end]...]
    elseif imgFormat == "RGB"
        pixelDataFormat = GL_RGB
        dims = [size(img)[2:end]...]
        glImgData1D = reshape(img.data, dims[1], dims[2] * 3)

    elseif imgFormat == "Gray"
        pixelDataFormat = GL_LUMINANCE
        glImgData1D = img.data
        dims = [size(img)[1:end]...]            
    else 
        error("Color Format $(imgFormat) not supported")
    end
    if imgType == Uint8
        glImgType = GL_UNSIGNED_BYTE
    elseif imgType == Float32
        glImgType = GL_FLOAT
    elseif imgType == Int8
        glImgType = GL_BYTE
    else 
        error("Type: $(imgType) not supported")
    end

    Texture(glImgData1D, dims, textureType, pixelDataFormat, parameters)
end

########################################################################

immutable GLBuffer{T <: Real}
    id::GLuint
    length::Int
    cardinality::Int
    bufferType::GLenum
    usage::GLenum

    function GLBuffer(ptr::Ptr{T}, size::Int, cardinality::Int, bufferType::GLenum, usage::GLenum)
        id = glGenBuffers()
        @assert size % sizeof(T) == 0
        _length = div(size, sizeof(T))
        @assert _length % cardinality == 0
        _length = div(_length, cardinality)

        glBindBuffer(bufferType, id)
        glBufferData(bufferType, size, ptr, usage)
        glBindBuffer(bufferType, 0)

        new(id, _length, cardinality, bufferType, usage)
    end

end

function GLBuffer(buffer::Vector; bufferType::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW) 
    ptrType = eltype(buffer)
    @assert isbits(ptrType)
    T = ptrType.types[1]
    println(T)
    @assert T <: Real
    @assert all(x -> x == T , ptrType.types)
    
    cardinality = length(names(ptrType))
    @assert cardinality <= 4
    ptr = convert(Ptr{T}, pointer(buffer))
    GLBuffer(ptr, sizeof(buffer), cardinality, bufferType, usage)
end
function GLBuffer{T}(buffer::Vector{T}, cardinality::Int; bufferType::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW) 
    GLBuffer{T}(convert(Ptr{T}, pointer(buffer)), sizeof(buffer), cardinality, bufferType, usage)
end

immutable GLVertexArray
    program::GLProgram
    id::GLuint
    size::Int
    #Buffer dict
    function GLVertexArray(bufferDict::Dict{Symbol, GLBuffer}, program::GLProgram)
        @assert !isempty(bufferDict)
        #get the size of the first array, to assert later, that all have the same size
        _size = get(bufferDict, collect(keys(bufferDict))[1], 0).length
        id = glGenVertexArrays()
        glBindVertexArray(id)       
        for elem in bufferDict
            buffer      = elem[2]
            if buffer.bufferType == GL_ELEMENT_ARRAY_BUFFER
                glBindBuffer(buffer.bufferType, buffer.id)
            else 
                attribute   = string(elem[1])
                @assert _size == buffer.length
                glBindBuffer(buffer.bufferType, buffer.id)
                attribLocation = glGetAttribLocation(program.id, attribute)
                glVertexAttribPointer(attribLocation, buffer.cardinality, GL_FLOAT, GL_FALSE, 0, 0)
                glEnableVertexAttribArray(attribLocation)
            end
        end
        glBindVertexArray(0)        
        new(program, id, _size)
    end
end
function GLVertexArray(bufferDict::Dict{ASCIIString, GLBuffer}, program::GLProgram)
    GLVertexArray(Dict{Symbol, GLBuffer}(map(elem -> (symbol(elem[1]), elem[2]), bufferDict)), program)
end
export GLVertexArray, GLBuffer

##################################################################################
abstract Renderable

immutable GLRenderObject <: Renderable
    vertexArray::GLVertexArray
    uniforms::Dict{GLint, Any}
    textures::Array{(GLint, Texture, Int), 1}
    program::GLProgram
    preRenderFunctions::Array{(Function, Tuple), 1}
    postRenderFunctions::Array{(Function, Tuple), 1}
    function GLRenderObject(
            vertexArray::GLVertexArray,
            uniforms::Dict{ASCIIString, Any},
            textures::Dict{ASCIIString, Texture},
            program::GLProgram,
            preRenderFunctions::Array{(Function, Tuple), 1},
            postRenderFunctions::Array{(Function, Tuple), 1}
            )
        #do some checks!
        #todo: check if all attributes are available in the program
        for elem in preRenderFunctions
            @assert method_exists(elem[1], [elem[2]..., GLRenderObject]...)
        end
        for elem in postRenderFunctions
            @assert method_exists(elem..., [elem[2]..., GLRenderObject]...)
        end
        uniforms = map(attributes -> begin 
                loc = glGetUniformLocation(program.id, attributes[1])
                @assert loc >= 0
                setProgramDefault(loc, attributes[2], program.id)
                (loc, attributes[2])
            end, uniforms)
        uniforms = Dict{GLint, Any}([uniforms...])

        textureTarget = 0
        textures = map(attributes -> begin 
                loc = glGetUniformLocation(program.id, attributes[1])
                @assert loc >= 0
                setProgramDefault(loc, attributes[2], program.id, textureTarget)
                textureTarget += 1
                (loc, attributes[2], textureTarget-1)
            end, textures)

        #@assert glGetError() == GL_NO_ERROR
        new(vertexArray, uniforms, textures, program, preRenderFunctions, postRenderFunctions)
    end
end

function GLRenderObject(program::GLProgram, data::Dict{ASCIIString, Any})

    buffers         = Dict{ASCIIString, GLBuffer}(filter((key, value) -> isa(value, GLBuffer), data))
    textures        = Dict{ASCIIString, Texture}(filter((key, value) -> isa(value, Texture), data))

    vertexArray     = GLVertexArray(buffers, program)

    uniforms        = filter((key, value) -> !isa(value, GLBuffer) && !isa(value, Texture), data)

    GLRenderObject(vertexArray, uniforms, textures, program, (Function, Tuple)[], (Function, Tuple)[])
end

type FuncWithArgs{T} <: Renderable
    f::Function
    args::T
end
export GLRenderObject, Renderable, FuncWithArgs
####################################################################################



###############################################################

delete!(a) = println("warning: delete! called with wrong argument: args: $(a)") # silent failure, if delete is called on something, where no delete is defined for
delete!(v::GLVertexArray) = glDeleteVertexArrays(1, [v.id])
function delete!(b::GLBuffer)
    glDeleteBuffers(1, [b.id])
    empty!(b.buffer)
end
delete!(t::Texture) = glDeleteTextures(1, [t.id])
delete!(t::FuncWithArgs) = nothing

function delete!(g::GLRenderObject)
    delete!(g.vertexArray)
    for elem in g.uniforms
        delete!(elem[2])
    end
    empty!(g.uniforms)
    for elem in g.textures
        delete!(elem[2])
    end
    empty!(g.textures)
    empty!(g.preRenderFunctions)
    empty!(g.postRenderFunctions)
end

export delete!