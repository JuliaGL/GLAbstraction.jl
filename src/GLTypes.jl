import Images.imread

immutable Texture
    id::GLuint
    textureType::Uint16
    format::Uint16
    width::Int
    height::Int

    function Texture(path::ASCIIString; targetFormat::Uint16 = GL_RGB, textureType::Uint16 = GL_TEXTURE_2D, alpha::Float32 = 1f0)
        img = imread(path)
        @assert length(img.data) > 0
        imgFormat   = img.properties["colorspace"]
        #glTexImage2D needs to know the pixel data format from imread, the type and the targetFormat
        pixelDataFormat::Uint16 = 0
        imgType                 = eltype(img.data)
        glImgType::Uint16       = 0
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
        @assert glGetError() == GL_NO_ERROR
        img = 0
        new(id, textureType, targetFormat, w, h)
    end
end


immutable GLRenderObject
    vertexArray::GLVertexArray
    uniforms::Dict{GLUint, Any}
    program::GLProgram
    preRenderFunctions::Arrray{(Function, Tuple), 1}
    postRenderFunctions::Arrray{(Function, Tuple), 1}
    function GLRenderObjectC(
            vertexArray::GLVertexArray,
            uniforms::Dict{ASCIIString, Any},
            program::GLProgram,
            preRenderFunctions::Arrray{(Function, Tuple), 1},
            postRenderFunctions::Arrray{(Function, Tuple), 1}
            )
        #do some checks!
        #todo: check if all attributes are available in the program
        for elem in preRenderFunctions
            @assert method_exists(elem[1], (elem[2]..., GLRenderObject))
        end
        for elem in postRenderFunctions
            @assert method_exists(elem...)
        end
        map!(attributes -> (glGetUniformLocation(program.id, attributes), attributes[2]), uniforms)
        @assert glGetError() == GL_NO_ERROR
        new(vertexArray, Dict([uniforms...]), program, preRenderFunctions, postRenderFunctions)
    end
end


function GLRenderObject(program::GLProgram, data::Dict{ASCIIString, Any}
		;primitiveMode::GLuint16 =  GL_POINTS)

    buffers         = filter((key, value) -> isa(value, GLBuffer), data)
    vertexArray 	= GLVertexArray(buffers, program, primitiveMode)

    uniforms        = filter((key, value) -> !isa(value, GLBuffer) && !isa(value, Function), data)
    new(vertexArray, uniforms, program, (Function, Tuple)[], (Function, Tuple)[])
end
 

immutable GLBuffer{T <: Real}
    id::GLuint
	buffer::Array{T, 1} #doesn't have to be here, but could be used together with invalidated, to change the buffer
    usage::Uint16
    bufferType::Uint16
    cardinality::Int
    length::Int
    invalidated::Bool
    function GLBuffer(buffer::Array{T, 1}, format::Int, bufferType::Uint16, usage::Uint16)
    	@assert length(buffer) % format == 0     
        length 	= div(length(buffer), format)
		id 		= glGenBuffers()
		glBindBuffer(bufferType, id)
	    glBufferData(bufferType, sizeof(buffer), convert(Ptr{Void}, pointer(buffer)), usage)
	    glBindBuffer(bufferType, 0)
        new(id, buffer, usage, bufferType, format, length, true)
    end

    function GLBuffer(buffer::Array{ImmutableVector{T}, 1}, bufferType::Uint16, usage::Uint16)
        length = length(buffer)
        format = length(names(eltype(buffer))
        id = glGenBuffers()
        glBindBuffer(bufferType, id)
        glBufferData(bufferType, sizeof(buffer), convert(Ptr{Void}, pointer(buffer)), usage)
        glBindBuffer(bufferType, 0)
        new(id, buffer, usage, bufferType, format, length, true)
    end
end
 
immutable GLVertexArray
    program::GLProgram
    id::GLuint
    size::Int
    primitiveMode::Uint16
    #Buffer dict
    function GLVertexArray(bufferDict::Dict{ASCIIString, GLBuffer}, program::GLProgram, primitiveMode::Uint16)
        @assert !isempty(bufferDict)
        #get the size of the first array, to assert later, that all have the same size
        size = get(bufferDict, collect(keys(bufferDict))[1], 0).size
        id = glGenVertexArrays()
        glBindVertexArray(id)        
        for elem in bufferDict
            attribute   = elem[1]
            buffer      = elem[2]
            @assert size == buffer.size
            glBindBuffer(buffer.bufferType, buffer.id)
            attribLocation = glGetAttribLocation(program.id, attribute)
            glVertexAttribPointer(attribLocation, buffer.format, GL_FLOAT, GL_FALSE, 0, 0)
            glEnableVertexAttribArray(attribLocation)
        end
        glBindVertexArray(0)        
        new(program, id, size, primitiveMode)
    end
end
 



delete!(a) = nothing # silent failure, if delete is called on something, where no delete is defined for
delete!(v::GLVertexArray) 	= glDeleteVertexArrays(1, [v.id])
function delete!(b::GLBuffer)
	glDeleteBuffers(1, [b.id])
	empty!(b.buffer)
end

function delete!(g::GLRenderObject)
	delete!(vertexArray)
	for elem in uniforms
		delete!(elem[2])
	end
	empty!(uniforms)
end