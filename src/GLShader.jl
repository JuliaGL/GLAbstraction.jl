GLProgram(name::String) = GLProgram("$(name).vert", "$(name).frag")

function printShaderInfoLog(obj::GLuint)
    infologLength::Array{GLint, 1} = [0]
    charsWritten::Array{GLsizei, 1}  = [0]
    glGetShaderiv(obj, GL_INFO_LOG_LENGTH, infologLength)
    errorOccured = false
    if infologLength[1] > 1
        errorOccured = true
        println("~~~~~~~~~~~~~~ ShaderInfoLog ~~~~~~~~~~~~~~")
        infoLog = zeros(GLchar, infologLength[1])
        glGetShaderInfoLog(obj, infologLength[1], charsWritten, infoLog)
        for elem in infoLog
            print(char(elem))
        end
        println("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
        infoLog = 0
    end
    return errorOccured
end
 
function printProgramInfoLog(obj::GLuint)
    infologLength::Array{GLint, 1} = [0]
    charsWritten::Array{GLsizei, 1}  = [0]
 
    glGetProgramiv(obj, GL_INFO_LOG_LENGTH, infologLength)
    errorOccured = false
    if infologLength[1] > 1
        errorOccured = true
        println("~~~~~~~~~~~~~~ ProgramInfoLog ~~~~~~~~~~~~~~")
        infoLog = zeros(GLchar, infologLength[1])
        glGetProgramInfoLog(obj, infologLength[1], charsWritten, infoLog)
        for elem in infoLog
            print(char(elem))
        end
        println("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
        infoLog = 0
    end
    return errorOccured
end

function readShader(shader::ASCIIString, shaderType)
    shaderID::GLuint          = glCreateShader(shaderType)
    @assert shaderID > 0
    const source = bytestring(shader)
    shaderCode::Ptr{GLchar}   = convert(Ptr{GLchar}, pointer(source))
    glShaderSource(shaderID, 1, convert(Ptr{Uint8}, pointer([shaderCode])), 0)
    glCompileShader(shaderID)
    printShaderInfoLog(shaderID)
    return shaderID
end

function readShader(fileStream::IOStream, shaderType)
    @assert isopen(fileStream)
    shaderID::GLuint          = glCreateShader(shaderType)
    @assert shaderID > 0
    shaderCode::Ptr{GLchar}   = convert(Ptr{GLchar}, pointer(readbytes(fileStream)))
    close(fileStream)
    glShaderSource(shaderID, 1, convert(Ptr{Uint8}, pointer([shaderCode])), 0)
    glCompileShader(shaderID)
    printShaderInfoLog(shaderID)
    return shaderID
end

export readShader
