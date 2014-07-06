GLProgram(name::String) = GLProgram("$(name).vert", "$(name).frag")



function getInfoLog(obj::GLuint)
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
function validateShader(shader)
    success::Array{GLint, 1} = [0]
    glGetShaderiv(shader, GL_COMPILE_STATUS, success)
    success[1] == GL_TRUE
end

function readshader(shadercode::ASCIIString, shaderType, path::String)
    shadercode = get_glsl_version_string() * shadercode
    const source = bytestring(shadercode)
    const sourcePTR::Ptr{GLchar} = convert(Ptr{GLchar}, pointer(source))

    shaderID::GLuint = glCreateShader(shaderType)
    @assert shaderID > 0
    glShaderSource(shaderID, 1, convert(Ptr{Uint8}, pointer([sourcePTR])), 0)
    glCompileShader(shaderID)
    if !validateShader(shaderID)
        log = getInfoLog(shaderID)
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

function uniforms(program::GLuint)
    uniformLength   = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)

    if uniformLength == 0
        return ()
    else
        return ntuple(uniformLength, i -> glGetActiveUniform(program, i-1))
    end
end



export readshader
