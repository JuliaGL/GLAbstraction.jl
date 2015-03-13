function getinfolog(obj::GLuint)
    # Return the info log for obj, whether it be a shader or a program.
    isShader    = glIsShader(obj)
    getiv       = isShader == GL_TRUE ? glGetShaderiv : glGetProgramiv
    get_log     = isShader == GL_TRUE ? glGetShaderInfoLog : glGetProgramInfoLog
     
    # Get the maximum possible length for the descriptive error message
    maxlength = GLint[0]
    getiv(obj, GL_INFO_LOG_LENGTH, maxlength)
    maxlength = first(maxlength)
    # Return the text of the message if there is any
    if maxlength > 0
        buffer = zeros(GLchar, maxlength)
        sizei::Array{GLsizei, 1} = [0]
        get_log(obj, maxlength, sizei, buffer)
        length = sizei[1]
        return bytestring(pointer(buffer), length)
    else
        return "success"
    end
end

function iscompiled(shader::GLuint)
    success = GLint[0]
    glGetShaderiv(shader, GL_COMPILE_STATUS, success)
    success[1] == GL_TRUE
end


function createshader(shadertype::GLenum)
    shaderid = glCreateShader(shaderType)
    @assert shaderid > 0 "opengl context is not active or shader type not accepted. Shadertype: $(GLENUM(shadertype).name)"
    shaderid::GLuint
end
function createprogram()
    p = glCreateProgram()
    @assert p > 0 "couldn't create program. Most likely, opengl context is not active"
    p::GLuint
end




function isupdated(file::File, update_interval=1.0)
    filename = abspath(file)
    file_edited = foldl((false, mtime(filename)), every(update_interval)) do v0, v1 
        time_edited = mtime(filename)
        (!isapprox(0.0, v0[2] - time_edited), time_edited)
    end
    return keepwhen(x->x==true, lift(first, file_edited, Bool)) # extract bool
end


function update(vertcode::ASCIIString, fragcode::ASCIIString, vpath::String, fpath::String, program)
    try 
        vertid = compileshader(vertcode, GL_VERTEX_SHADER, vpath)
        fragid = compileshader(fragcode, GL_FRAGMENT_SHADER, fpath)
        glUseProgram(0)
        shader_ids = glGetAttachedShaders(program)
        foreach(shader -> glDetachShader(program, shader), shader_ids)
        
        glAttachShader(program, vertid)
        glAttachShader(program, fragid)

        glLinkProgram(program)
        glDeleteShader(vertid)
        glDeleteShader(fragid)
    catch theerror
        println(theerror)
    end
end

shadertype(::File{:vert})           = GL_VERTEX_SHADER
shadertype(::File{:frag})           = GL_FRAGMENT_SHADER
shadertype(::File{:geom})           = GL_GEOMETRY_SHADER
shadertype{Ending}(::File{Ending})  = error("File ending doesn't correspond to a shader type. Ending: $(Ending), File: $(abspath(file))")



function attachshader{Typ}(file::File{Typ}, program::GLuint)  
    fs = open(file)
    shaderid = attachshader(readbytes(fs), shadertype(file), program, abspath(file))
    close(fs)
    return shaderid
end
function attachshader(code::Vector{Uint8}, shadertype::GLenum, program::GLuint, name)
    shaderid = compileshader(code, shadertype, name)
    glAttachShader(program, shaderid)
    shaderid
end
compileshader(code::AbstractString, shadertype::GLenum, name::AbstractString) = compileshader(bytestring(ascii(code)), shadertype, name)

function compileshader(file::File, program::GLuint)
    fs = open(file)
    shaderid = compileshader(readbytes(fs), shadertype(file), program, abspath(file))
    close(fs)
    return shaderid
end
                    #(shadertype, shadercode) -> shader id
let shader_cache = Dict{(GLenum, Vector{Uint8}), GLuint}() # shader cache prevents that a shader is compiled more than one time
    function compileshader(shadercode::Vector{Uint8}, shadertype::GLenum, shadername::AbstractString)
        haskey(shader_cache, (shadertype, shadercode)) && return shader_cache[shadercode]
        shaderid = createshader(shadertype)
        glShaderSource(shaderid, shadercode)
        glCompileShader(shaderid)
        if !iscompiled(shaderid)
            print_with_lines(bytestring(shadercode))
            error("shader $shadername didn't compile. \n$(getinfolog(shaderid)")
        end
        shader_cache[shadercode] = shaderid
        return shaderid
    end
end



function uniformlocations(nametypedict::Dict{Symbol, GLenum})
    texturetarget = -1 # start -1, as texture samplers start at 0
    return  Dict{Symbol,Tuple}(map(nametypedict) do name_type
        name, typ = name_type
        loc = get_uniform_location(program, name)
        if istexturesampler(typ)
            texturetarget += 1
            return (name, (loc, texturetarget))
        else
            return (name, (loc,))
        end
    end)
end


function GLProgram{S1 <: AbstractString, S2 <: AbstractString, S3 <: AbstractString}(
                    code::Dict{S1, (GLenum, S2)}, program=createprogram(); 
                    fragdatalocation=(Int, S3)[])

    # Remove old shaders
    glUseProgram(0)
    shader_ids = glGetAttachedShaders(program)
    foreach(glDetachShader, program, shader_ids)

    #attach new ones
    shaders = map(code) do name_type_source
        name, type_code     = name_type_source
        typ, source         = type_source
        shaderid            = compileshader(typ, source, name)
        glAttachShader(program, shaderid)
    end

    #Bind frag data
    for (location, name) in fragdatalocation
        glBindFragDataLocation(program, location, ascii(name))
    end
    
    #link program
    glLinkProgram(program)
    foreach(glDeleteShader, shaders) # Can be deleted, as they will still be linked to Program and released after program gets released

    # generate the link locations
    nametypedict        = uniform_name_type(program)
    uniformlocationdict = uniformlocations(nametypedict)

    return GLProgram(program, map(symbol, keys(code)), nametypedict, uniformlocationdict)
end



function template2source(code::AbstractString, attributes::Dict{Symbol, Any}, view::Dict{ASCIIString, ASCIIString})
    code_template    = Mustache.parse(code)
    specialized_view = merge(createview(attributes, mustachekeys(code_template)), view)
    code_sourece     = replace(replace(Mustache.render(code_template, specialized_view), "&#x2F;", "/"), "&gt;", ">")
end



function TemplateProgram{S1 <: AbstractString, S2 <: AbstractString}(
                            code::Dict{S1, (GLenum, Input{S2})}; 
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
        "GLSL_VERSION"    => glsl_version_string(),
        "GLSL_EXTENSIONS" => extension
    )
    view = merge(internaldata, view)
    TemplateProgram(code, view, attributes=attributes, fragdatalocation=fragdatalocation)
end



function TemplateProgram{S1 <: AbstractString, S2 <: AbstractString}(
                            code::Dict{S1, (GLenum, S2)}, view::Dict{ASCIIString, ASCIIString}; 
                            attributes::Dict{Symbol, Any} = Dict{Symbol, Any}(),
                            fragdatalocation=(Int, ASCIIString)[]
                        )
    # transform dict of templates into actual shader source
    code = [begin
        typ, code_template  = type_code
        name => (typ, template2source(code_template, attributes, view)) 
    end for (name, type_code) in code]
    return GLProgram(code, fragdatalocation=fragdatalocation)
end


# Gets used to access a 
glsl_variable_access{T,D}(keystring, ::Texture{T, 1, D}) = "texture($(keystring), uv).r;"
glsl_variable_access{T,D}(keystring, ::Texture{T, 2, D}) = "texture($(keystring), uv).rg;"
glsl_variable_access{T,D}(keystring, ::Texture{T, 3, D}) = "texture($(keystring), uv).rgb;"
glsl_variable_access{T,D}(keystring, ::Texture{T, 4, D}) = "texture($(keystring), uv).rgba;"

glsl_variable_access(keystring, ::Union(Real, GLBuffer, AbstractArray, AbstractRGB, AbstractAlphaColorValue)) = keystring*";"

glsl_variable_access(keystring, s::Signal)  = glsl_variable_access(keystring, s.value)
glsl_variable_access(keystring, t::Any)     = error("no glsl variable calculation available for :", keystring, " of type ", typeof(t))


function createview(x::Dict{Symbol, Any}, keys)
  view = Dict{ASCIIString, ASCIIString}()
  for (key, value) in x
    if !isa(value, String)
        keystring = string(key)
        typekey = keystring*"_type"
        calculationkey = keystring*"_calculation"

        in(typekey, keys) && (view[keystring*"_type"] = toglsltype_string(value))
        in(calculationkey, keys) && (view[keystring*"_calculation"] = glsl_variable_access(keystring, value))
    end
  end
  view
end
mustachekeys(mustache::Mustache.MustacheTokens) = map(x->x[2], filter(x-> x[1] == "name", mustache.tokens))
