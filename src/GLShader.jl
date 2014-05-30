GLProgram(name::String) = GLProgram("$(name).vert", "$(name).frag")

function printShaderInfoLog(obj::GLuint, name)
    infologLength::Array{GLint, 1} = [0]
    charsWritten::Array{GLsizei, 1}  = [0]
    glGetShaderiv(obj, GL_INFO_LOG_LENGTH, infologLength)
    errorOccured = false
    if infologLength[1] > 1
        errorOccured = true
        println("ShaderInfoLog for: $(name)")
        infoLog = zeros(GLchar, infologLength[1])
        glGetShaderInfoLog(obj, infologLength[1], charsWritten, infoLog)
        for elem in infoLog
            print(char(elem))
        end
        println("\nProgramInfoLog: $(name) end")
        infoLog = 0
    end
    return errorOccured
end
 
function printProgramInfoLog(obj::GLuint, programname)
    infologLength::Array{GLint, 1} = [0]
    charsWritten::Array{GLsizei, 1}  = [0]
 
    glGetProgramiv(obj, GL_INFO_LOG_LENGTH, infologLength)
    errorOccured = false
    if infologLength[1] > 1
        errorOccured = true
        println("ProgramInfoLog: $(programname)")
        infoLog = zeros(GLchar, infologLength[1])
        glGetProgramInfoLog(obj, infologLength[1], charsWritten, infoLog)
        for elem in infoLog
            print(char(elem))
        end
        println("\nProgramInfoLog: $(programname) end")
        infoLog = 0
    end
    return errorOccured
end

function readShader(shaderCode::ASCIIString, shaderType, name)
    const source = bytestring(shaderCode)
    const sourcePTR::Ptr{GLchar} = convert(Ptr{GLchar}, pointer(source))
    return readShader(sourcePTR, shaderType, name)
end
function readShader(fileStream::IOStream, shaderType, name)
    @assert isopen(fileStream)
    const shaderCode::Ptr{GLchar}   = convert(Ptr{GLchar}, pointer(readbytes(fileStream)))
    return readShader(shaderCode, shaderType, name)
end
function readShader(shaderCode::Ptr{GLchar}, shaderType, name)
    shaderID::GLuint = glCreateShader(shaderType)
    @assert shaderID > 0
    glShaderSource(shaderID, 1, convert(Ptr{Uint8}, pointer([shaderCode])), 0)
    glCompileShader(shaderID)
    printShaderInfoLog(shaderID, name)
    return shaderID
end


export readShader
