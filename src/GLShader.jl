

function getinfolog(obj::GLuint)
    # Return the info log for obj, whether it be a shader or a program.
    isShader    = glIsShader(obj)
    getiv       = isShader == GL_TRUE ? glGetShaderiv : glGetProgramiv
    getInfo     = isShader == GL_TRUE ? glGetShaderInfoLog : glGetProgramInfoLog
     
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
        for (i,line) in enumerate(split(shadercode, "\n"))
            println(i, "  ", line)
        end
        log = getinfolog(shaderID)
        error(path * "\n" * log)
    end

    return shaderID
end
function readshader(fileStream::IOStream, shaderType, name)
    @assert isopen(fileStream)
    return readShader(readall(fileStream), shaderType, name)
end

function update(vertcode::ASCIIString, fragcode::ASCIIString, vpath::String, fpath::String, program)
    try 
        vertid = readshader(vertcode, GL_VERTEX_SHADER, vpath)
        fragid = readshader(fragcode, GL_FRAGMENT_SHADER, fpath)
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


glsl_variable_access{T,D}(keystring, ::Texture{T, 1, D}) = "texture($(keystring), uv).r;"
glsl_variable_access{T,D}(keystring, ::Texture{T, 2, D}) = "texture($(keystring), uv).rg;"
glsl_variable_access{T,D}(keystring, ::Texture{T, 3, D}) = "texture($(keystring), uv).rgb;"
glsl_variable_access{T,D}(keystring, ::Texture{T, 4, D}) = "texture($(keystring), uv).rgba;"
glsl_variable_access{T,D}(keystring, ::Texture{T, 4, D}) = "texture($(keystring), uv).rgba;"

glsl_variable_access(keystring, ::Union(Real, GLBuffer, AbstractArray, AbstractRGB, AbstractAlphaColorValue)) = keystring*";"

glsl_variable_access(keystring, s::Signal)  = glsl_variable_access(keystring, s.value)
glsl_variable_access(keystring, t::Any)     = error("no glsl variable calculation available for :",keystring, " of type ", typeof(t))


function createview(x::Dict{Symbol, Any}, keys)
  view = Dict{ASCIIString, ASCIIString}()
  for (key,value) in x
    if !isa(value, String)
        keystring = string(key)
        typekey = keystring*"_type"
        calculationkey = keystring*"_calculation"
        if in(typekey, keys)
          view[keystring*"_type"] = toglsltype_string(value)
        end
        if in(calculationkey, keys)
            view[keystring*"_calculation"] = glsl_variable_access(keystring, value)
        end
    end
  end
  view
end
mustachekeys(mustache::Mustache.MustacheTokens) = map(x->x[2], filter(x-> x[1] == "name", mustache.tokens))


function GLProgram( vertex::ASCIIString, fragment::ASCIIString, vertpath::String, fragpath::String; 
                    fragdatalocation=(Int, ASCIIString)[])

    vertexShaderID::GLuint   = readshader(vertex, GL_VERTEX_SHADER, vertpath)
    fragmentShaderID::GLuint = readshader(fragment, GL_FRAGMENT_SHADER, fragpath)
    p = glCreateProgram()

    @assert p > 0
    glAttachShader(p, vertexShaderID)
    glAttachShader(p, fragmentShaderID)
    for elem in fragdatalocation
        glBindFragDataLocation(p, elem...)
    end
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

# REAALLY ugly way of doing this.. I still don't completely know, why my other approaches haven't worked
function watch_file_react(filename)
    f = open(filename)
    firstcontent = readall(f)
    close(f)
    file_edited = lift(x->x[1], Bool, foldl((v0, v1) -> begin 
        t = mtime(filename)
        (!isapprox(0.0, v0[2] - t), t)
    end, (false, mtime(filename)), every(1.0)))
    return lift(x -> begin
        f = open(filename)
        content = readall(f)
        close(f)
        content
    end, keepwhen(file_edited, false, file_edited))
end

function TemplateProgram(
                            vertex_file_path::ASCIIString, fragment_file_path::ASCIIString; 
                            view::Dict{ASCIIString, ASCIIString} = Dict{ASCIIString, ASCIIString}(), 
                            attributes::Dict{Symbol, Any} = Dict{Symbol, Any}(),
                            fragdatalocation=(Int, ASCIIString)[]
                        )

    if haskey(view, "in") || haskey(view, "out") || haskey(view, "GLSL_VERSION")
        println("warning: using internal keyword \"$(in/out/GLSL_VERSION)\" for shader template. The value will be overwritten")
    end
    extension = "" #Still empty, but might be replaced by a platform dependant extension string
    if haskey(view, "GLSL_EXTENSIONS")
        #to do: check custom extension...
        #for now we just append the extensions
        extension *= "\n" * view["GLSL_EXTENSIONS"]
    end
    internaldata = @compat Dict(
        "out"             => get_glsl_out_qualifier_string(),
        "in"              => get_glsl_in_qualifier_string(),
        "GLSL_VERSION"    => get_glsl_version_string(),
        
        "GLSL_EXTENSIONS" => extension
    )
    view    = merge(internaldata, view)
    sources = lift( (vertex_file_path, fragment_file_path) -> begin
        vertex_tm       = Mustache.parse(vertex_file_path)
        fragment_tm     = Mustache.parse(fragment_file_path)

        vertex_view     = merge(createview(attributes, mustachekeys(vertex_tm)), view)
        fragment_view   = merge(createview(attributes, mustachekeys(fragment_tm)), view)
        vertsource      = replace(replace(Mustache.render(vertex_tm, vertex_view), "&#x2F;", "/"), "&gt;", ">")
        fragsource      = replace(replace(Mustache.render(fragment_tm, fragment_view), "&#x2F;", "/"), "&gt;", ">")
        (vertsource, fragsource)
    end, watch_file_react(vertex_file_path), watch_file_react(fragment_file_path))

    #just using one view for vert and frag shader plus workaround for mustache bug
    p = GLProgram(sources.value[1], sources.value[2], vertex_file_path, fragment_file_path, fragdatalocation=fragdatalocation)
    lift( x-> update(x[1], x[2], vertex_file_path, fragment_file_path, p.id), sources)
    p
end


function TemplateProgram(
                            vertex_source::ASCIIString, fragment_source::ASCIIString, 
                            vertex_name::ASCIIString, fragment_name::ASCIIString;
                            view::Dict{ASCIIString, ASCIIString} = Dict{ASCIIString, ASCIIString}(), 
                            attributes::Dict{Symbol, Any}=Dict{Symbol, Any}(),
                            fragdatalocation=(Int, ASCIIString)[]
                        )

    if haskey(view, "in") || haskey(view, "out") || haskey(view, "GLSL_VERSION")
        println("warning: using internal keyword \"$(in/out/GLSL_VERSION)\" for shader template. The value will be overwritten")
    end
    extension = "" #Still empty, but might be replaced by a platform dependant extension string
    if haskey(view, "GLSL_EXTENSIONS")
        #to do: check if extension is available...
        #for now we just append the extensions
        extension *= "\n" * view["GLSL_EXTENSIONS"]
    end
    internaldata = @compat Dict(
        "out"             => get_glsl_out_qualifier_string(),
        "in"              => get_glsl_in_qualifier_string(),
        "GLSL_VERSION"    => get_glsl_version_string(),
        
        "GLSL_EXTENSIONS" => extension
    )
    view    = merge(internaldata, view)
    sources = lift( (vertex_file_path, fragment_file_path) -> begin
        vertex_tm       = Mustache.parse(vertex_file_path)
        fragment_tm     = Mustache.parse(fragment_file_path)

        vertex_view     = merge(createview(attributes, mustachekeys(vertex_tm)), view)
        fragment_view   = merge(createview(attributes, mustachekeys(fragment_tm)), view)
        vertsource      = replace(Mustache.render(vertex_tm, vertex_view), "&#x2F;", "/")
        fragsource      = replace(Mustache.render(fragment_tm, fragment_view), "&#x2F;", "/")
        (vertsource, fragsource)
    end, Input(vertex_source), Input(fragment_source))

    #just using one view for vert and frag shader plus workaround for mustache bug
    p = GLProgram(sources.value[1], sources.value[2], vertex_name, fragment_name, fragdatalocation=fragdatalocation)
    lift( x-> update(x[1], x[2], vertex_name, fragment_name, p.id), sources)
    p
end