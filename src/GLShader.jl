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


const UNIFORM_TYPE_ENUM_DICT = [

    GL_FLOAT        => [GLfloat, vec1],
    GL_FLOAT_VEC2   => [vec2],
    GL_FLOAT_VEC3   => [vec3],
    GL_FLOAT_VEC4   => [vec4],

    GL_INT          => [GLint, Integer, ivec1],
    GL_INT_VEC2     => [ivec2],
    GL_INT_VEC3     => [ivec3],
    GL_INT_VEC4     => [ivec4],

    GL_BOOL         => [GLint, Integer, ivec1, Bool],
    GL_BOOL_VEC2    => [ivec2],
    GL_BOOL_VEC3    => [ivec3],
    GL_BOOL_VEC4    => [ivec4],

    GL_FLOAT_MAT2   => [mat2],
    GL_FLOAT_MAT3   => [mat3],
    GL_FLOAT_MAT4   => [mat4],

    GL_FLOAT_MAT2x3 => [mat2x3],
    GL_FLOAT_MAT2x4 => [mat2x4],

    GL_FLOAT_MAT3x2 => [mat3x2],
    GL_FLOAT_MAT3x4 => [mat3x4],

    GL_FLOAT_MAT4x3 => [mat4x3],
    GL_FLOAT_MAT4x2 => [mat4x2],


    GL_SAMPLER_1D   => [Texture{GLfloat,1,1}, Texture{GLfloat,2,1}, Texture{GLfloat,3,1}, Texture{GLfloat,4,1}],
    GL_SAMPLER_2D   => [Texture{GLfloat,1,2}, Texture{GLfloat,2,2}, Texture{GLfloat,3,2}, Texture{GLfloat,4,2}],
    GL_SAMPLER_3D   => [Texture{GLfloat,1,3}, Texture{GLfloat,2,3}, Texture{GLfloat,3,3}, Texture{GLfloat,4,3}],

    GL_UNSIGNED_INT_SAMPLER_1D  => [Texture{GLuint,1,1}, Texture{GLuint,2,1}, Texture{GLuint,3,1}, Texture{GLuint,4,1}],
    GL_UNSIGNED_INT_SAMPLER_2D  => [Texture{GLuint,1,2}, Texture{GLuint,2,2}, Texture{GLuint,3,2}, Texture{GLuint,4,2}],
    GL_UNSIGNED_INT_SAMPLER_3D  => [Texture{GLuint,1,3}, Texture{GLuint,2,3}, Texture{GLuint,3,3}, Texture{GLint,4,3}],

    GL_INT_SAMPLER_1D   => [Texture{GLint,1,1}, Texture{GLint,2,1}, Texture{GLint,3,1}, Texture{GLint,4,1}],
    GL_INT_SAMPLER_2D   => [Texture{GLint,1,2}, Texture{GLint,2,2}, Texture{GLint,3,2}, Texture{GLint,4,2}],
    GL_INT_SAMPLER_3D   => [Texture{GLint,1,3}, Texture{GLint,2,3}, Texture{GLint,3,3}, Texture{GLint,4,3}],
]

function is_correct_uniform_type{T <: Real}(targetuniform::GLenum, tocheck::T)
    shouldbe = uniform_type(targetuniform)
    return in(T, shouldbe)
end
function is_correct_uniform_type{T <: Real}(targetuniform::GLenum, tocheck::AbstractArray{T})
    shouldbe = uniform_type(targetuniform)
    return in(typeof(tocheck), shouldbe)
end
function is_correct_uniform_type{T <: Real}(targetuniform::GLenum, tocheck::Vector{T})
    shouldbe = uniform_type(targetuniform)
    return in(T, shouldbe)
end
is_correct_uniform_type(targetuniform::GLenum, tocheck::Signal) = is_correct_uniform_type(targetuniform, tocheck.value)

function is_correct_uniform_type(targetuniform::GLenum, tocheck::Texture)
    shouldbe = uniform_type(targetuniform)
    
    return in(typeof(tocheck), shouldbe)
end
function uniform_type(targetuniform::GLenum)
    if haskey(UNIFORM_TYPE_ENUM_DICT, targetuniform)
        UNIFORM_TYPE_ENUM_DICT[targetuniform]
    else
        error("Unrecognized Unifom Enum. Enum found: ", GLENUM(targetuniform).name)
    end
end





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

=#
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


function uniformdescription(program::GLuint)
    uniformLength   = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)
    if uniformLength == 0
        return ()
    else
        nametypelist = ntuple(uniformLength, i -> glGetActiveUniform(program, i-1)[1:2]) # take size and name
        return nametypelist
    end
end

function istexturesampler(typ::GLenum)
    return (typ == GL_SAMPLER_1D || typ == GL_SAMPLER_2D || typ == GL_SAMPLER_3D ||  

    typ == GL_UNSIGNED_INT_SAMPLER_1D || typ == GL_UNSIGNED_INT_SAMPLER_2D || typ == GL_UNSIGNED_INT_SAMPLER_3D ||

    typ == GL_INT_SAMPLER_1D || typ == GL_INT_SAMPLER_2D || typ == GL_INT_SAMPLER_3D)
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

    nametypedict = Dict{Symbol, GLenum}(uniformdescription(p))
    texturetarget = -1
    println(typeof(nametypedict))
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
    println(typeof(uniformlocationdict))

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
