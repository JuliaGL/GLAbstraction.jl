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
        log = bytestring(pointer(convert(Array{Uint8,1}, infoLog)), charsWritten[1])
        println(log)
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
        log = bytestring(pointer(convert(Array{Uint8,1}, infoLog)), charsWritten[1])
        println(log)
        infoLog = 0
    end
    return errorOccured
end

function readshader(shadercode::ASCIIString, shaderType, name)
    shadercode = get_glsl_version_string() * shadercode
    const source = bytestring(shadercode)
    const sourcePTR::Ptr{GLchar} = convert(Ptr{GLchar}, pointer(source))

    shaderID::GLuint = glCreateShader(shaderType)
    @assert shaderID > 0
    glShaderSource(shaderID, 1, convert(Ptr{Uint8}, pointer([sourcePTR])), 0)
    glCompileShader(shaderID)
    printShaderInfoLog(shaderID, name)
    return shaderID
end
function readshader(fileStream::IOStream, shaderType, name)
    @assert isopen(fileStream)
    return readShader(readall(fileStream), shaderType, name)
end


export readshader
