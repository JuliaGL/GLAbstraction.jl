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

export Texture

immutable Texture
    id::GLuint
    textureType::GLenum
    format::GLenum
    width::Int
    height::Int

    function Texture(path::ASCIIString; targetFormat::GLenum = GL_RGB, textureType::GLenum = GL_TEXTURE_2D)
        #@assert glGetError() == GL_NO_ERROR
        
        img = imread(path)
        @assert length(img.data) > 0
        imgFormat   = img.properties["colorspace"]
        #glTexImage2D needs to know the pixel data format from imread, the type and the targetFormat
        pixelDataFormat::GLenum = 0
        imgType                 = eltype(img.data)
        glImgType::GLenum       = 0
        glImgData1D = imgType[]
        w = 0
        h = 0
        if imgFormat == "ARGB"
            pixelDataFormat = GL_RGBA
            tmp = img.data[1,1:end, 1:end]
            img.data[1,1:end, 1:end] = img.data[2,1:end, 1:end]
            img.data[2,1:end, 1:end] = img.data[3,1:end, 1:end]
            img.data[3,1:end, 1:end] = img.data[4,1:end, 1:end]
            img.data[4,1:end, 1:end] = tmp
            glImgData1D  = img.data
            w = size(img, 2)
            h = size(img, 3)
        elseif imgFormat == "RGB"
            pixelDataFormat = GL_RGB
            w = size(img, 2)
            h = size(img, 3)
            glImgData1D = reshape(img.data, w, h * 3)

        elseif imgFormat == "Gray"
            pixelDataFormat = GL_DEPTH_COMPONENT
            glImgData1D = img.data
            w = size(img, 1)
            h = size(img, 2)            
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
        @assert w > 0 && h > 0 && length(glImgData1D) > 0
        id = glGenTextures()
        glBindTexture(textureType, id)
        glTexParameteri( textureType, GL_TEXTURE_WRAP_S,       GL_CLAMP_TO_EDGE )
        glTexParameteri( textureType, GL_TEXTURE_WRAP_T,       GL_CLAMP_TO_EDGE )
        glTexParameteri( textureType, GL_TEXTURE_MAG_FILTER,   GL_LINEAR )
        glTexParameteri( textureType, GL_TEXTURE_MIN_FILTER,   GL_LINEAR )
        glTexImage2D(textureType, 0, pixelDataFormat, w, h, 0, pixelDataFormat, glImgType, glImgData1D)
        #@assert glGetError() == GL_NO_ERROR
        img = 0
        new(id, textureType, targetFormat, w, h)
    end
end

########################################################################

immutable GLBuffer{T <: Real}
    id::GLuint
    buffer::Array{T, 1} #doesn't have to be here, but could be used together with invalidated, to change the buffer
    usage::GLenum
    bufferType::GLenum
    cardinality::Int
    length::Int
    invalidated::Bool
    function GLBuffer(buffer::Array{T, 1}, cardinality::Int, bufferType::GLenum, usage::GLenum)
        @assert length(buffer) % cardinality == 0     
        _length  = div(length(buffer), cardinality)
        id      = glGenBuffers()
        glBindBuffer(bufferType, id)
        glBufferData(bufferType, sizeof(buffer), convert(Ptr{Void}, pointer(buffer)), usage)
        glBindBuffer(bufferType, 0)
        new(id, buffer, usage, bufferType, cardinality, _length, true)
    end

    # function GLBuffer(buffer::Ptr{T},_length, cardinality::Int, bufferType::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW)
    #     _length  = length(buffer)
    #     cardinality  = length(names(eltype(buffer)))
    #     id      = glGenBuffers()
    #     glBindBuffer(bufferType, id)
    #     glBufferData(bufferType, sizeof(buffer), convert(Ptr{Void}, pointer(buffer)), usage)
    #     glBindBuffer(bufferType, 0)
    #     new(id, buffer, usage, bufferType, cardinality, _length, true)
    # end
end
function GLBuffer(buffer::Array, cardinality::Int, bufferType::GLenum = GL_ARRAY_BUFFER, usage::GLenum = GL_STATIC_DRAW) 
    GLBuffer{eltype(buffer)}(buffer, cardinality, bufferType, usage)
end

immutable GLVertexArray
    program::GLProgram
    id::GLuint
    size::Int
    primitiveMode::GLenum
    #Buffer dict
    function GLVertexArray(bufferDict::Dict{ASCIIString, GLBuffer}, program::GLProgram, primitiveMode::GLenum)
        @assert !isempty(bufferDict)
        #get the size of the first array, to assert later, that all have the same size
        _length = get(bufferDict, collect(keys(bufferDict))[1], 0).length
        id = glGenVertexArrays()
        glBindVertexArray(id)        
        for elem in bufferDict
            attribute   = elem[1]
            buffer      = elem[2]
            @assert _length == buffer.length
            glBindBuffer(buffer.bufferType, buffer.id)
            attribLocation = glGetAttribLocation(program.id, attribute)
            glVertexAttribPointer(attribLocation, buffer.cardinality, GL_FLOAT, GL_FALSE, 0, 0)
            glEnableVertexAttribArray(attribLocation)
        end
        glBindVertexArray(0)        
        new(program, id, _length, primitiveMode)
    end
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

function GLRenderObject(program::GLProgram, data::Dict{ASCIIString, Any}
        ;primitiveMode::GLenum =  GL_POINTS)

    buffers         = Dict{ASCIIString, GLBuffer}(filter((key, value) -> isa(value, GLBuffer), data))
    textures        = Dict{ASCIIString, Texture}(filter((key, value) -> isa(value, Texture), data))

    vertexArray     = GLVertexArray(buffers, program, primitiveMode)

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