GLProgram(name::String) = GLProgram("$(name).vert", "$(name).frag")



function getinfolog(obj::GLuint)
    # Return the info log for obj, whether it be a shader or a program.
    isShader = glIsShader(obj)
    getiv = isShader == GL_TRUE ? glGetShaderiv : glGetProgramiv
    getInfo = isShader == GL_TRUE ? glGetShaderInfoLog : glGetProgramInfoLog
     
    # Get the maximum possible length for the descriptive error message
    int::Array{GLint, 1} = [0]
    getiv(obj, GL_INFO_LOG_LENGTH, int)
    maxlength = int[1]
    # Return the text of the message if there is any
    if maxlength > 0
        buffer = zeros(GLchar, maxlength)
        sizei::Array{GLsizei, 1} = [0]
        getInfo(obj, maxlength, sizei, buffer)
        length = sizei[1]
        bytestring(pointer(buffer), length)
    else
        "success"
    end
end
function validateshader(shader)
    success::Array{GLint, 1} = [0]
    glGetShaderiv(shader, GL_COMPILE_STATUS, success)
    success[1] == GL_TRUE
end

function readshader(shadercode::ASCIIString, shaderType, path::String)

    const source = bytestring(shadercode)
    const sourcePTR::Ptr{GLchar} = convert(Ptr{GLchar}, pointer(source))

    shaderID::GLuint = glCreateShader(shaderType)
    @assert shaderID > 0
    glShaderSource(shaderID, 1, convert(Ptr{Uint8}, pointer([sourcePTR])), 0)
    glCompileShader(shaderID)
    if !validateshader(shaderID)
        log = getinfolog(shaderID)
        error(path * "\n" * log)
    end

    return shaderID
end
function readshader(fileStream::IOStream, shaderType, name)
    @assert isopen(fileStream)
    return readShader(readall(fileStream), shaderType, name)
end

function update(vertcode::ASCIIString, fragcode::ASCIIString, path::String, program)
    try
        vertid = readshader(vertcode, GL_VERTEX_SHADER, path)
        fragid = readshader(fragcode, GL_FRAGMENT_SHADER, path)
        glUseProgram(0)
        oldid = glGetAttachedShaders(program)
        glDetachShader(program, oldid[1])
        glDetachShader(program, oldid[2])
        
        glAttachShader(program, vertid)
        glAttachShader(program, fragid)

        glLinkProgram(program)
        glDeleteShader(vertid)
        glDeleteShader(fragid)
    catch theerror
        println(theerror)
    end
end



function GLProgram(vertex::ASCIIString, fragment::ASCIIString, vertpath::String, fragpath::String)
    vertexShaderID::GLuint   = readshader(vertex, GL_VERTEX_SHADER, vertpath)
    fragmentShaderID::GLuint = readshader(fragment, GL_FRAGMENT_SHADER, fragpath)
    p = glCreateProgram()
    @assert p > 0
    glAttachShader(p, vertexShaderID)
    glAttachShader(p, fragmentShaderID)
    glLinkProgram(p)

    glDeleteShader(vertexShaderID) # Can be deleted, as they will still be linked to Program and released after program gets released
    glDeleteShader(fragmentShaderID)

    nametypedict = Dict{Symbol, GLenum}(uniform_name_type(p))
    attriblist = attribute_name_type(p)

    texturetarget = -1
    uniformlocationdict = map( elem -> begin
        name = elem[1]
        typ = elem[2]
        loc = get_uniform_location(p, name)
        if istexturesampler(typ)
            texturetarget += 1
            return (name, (loc, texturetarget))
        else
            return (name, (loc,))
        end
    end, nametypedict) 

    return GLProgram(p, vertpath, fragpath, nametypedict, Dict{Symbol,Tuple}(uniformlocationdict))
end
function GLProgram(vertex_file_path::ASCIIString, fragment_file_path::ASCIIString)
    
    vertsource  = readall(open(vertex_file_path))
    fragsource  = readall(open(fragment_file_path))
    vertname    = basename(vertex_file_path)
    fragname    = basename(fragment_file_path)
    GLProgram(vertsource, fragsource, vertex_file_path, fragment_file_path)
end

export readshader


#=

    This functions creates a uniform upload function for a Program
    which can be used to upload uniforms in the most efficient wayt
    the function will look like:
    function upload(uniform1, uniform2, uniform3)
        gluniform(1, uniform1) # inlined uniform location
        gluniform(2, uniform2)
        gluniform(3, 0, uniform3) #if a uniform is a texture, texture targets are inlined as well
        #this is supposed to be a lot faster than iterating through an array and caling the right functions
        #with the right locations and texture targets
    end

function createuniformfunction(id, uniformlist::Tuple, typelist::Tuple)
    uploadfunc          = {}
    texturetarget       = 0

    for i=1:length(uniformlist)

        variablename    = uniformlist[i]
        uniformtype     = typelist[i]
        uniformlocation = get_uniform_location(id,string(variablename))

        if uniformtype == GL_SAMPLER_1D || uniformtype == GL_SAMPLER_2D || uniformtype == GL_SAMPLER_3D
            push!(uploadfunc, :(gluniform($uniformlocation, $(convert(GLint,texturetarget)), $variablename)))
            texturetarget += 1
        else
            push!(uploadfunc, :(gluniform($uniformlocation, $variablename)))
        end

    end
    return eval(quote
        function uniformuploadfunction($(uniformlist...))
            $(uploadfunc...)
        end
    end)
end

=#