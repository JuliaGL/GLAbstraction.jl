immutable Shader
    name::Symbol
    source::Vector{Uint8}
    typ::GLenum
end
name(s::Shader) = s.name
function Shader(f::File)
    stream = open(f)
    s = Shader(symbol(f.abspath), readbytes(stream), shadertype(f))
    close(stream)
    s
end
Shader(s::Shader; name=s.name, source=s.source, typ=s.typ) = Shader(name, source, typ)
# Different shader string literals- usage: e.g. frag" my shader code"
macro frag_str(source::AbstractString)
    quote
        Shader(symbol(@__FILE__), $(Vector{Uint8}(ascii(source))), GL_FRAGMENT_SHADER)
    end
end
macro vert_str(source::AbstractString)
    quote
        Shader(symbol(@__FILE__), $(Vector{Uint8}(ascii(source))), GL_VERTEX_SHADER)
    end
end
macro geom_str(source::AbstractString)
    quote
        Shader(symbol(@__FILE__), $(Vector{Uint8}(ascii(source))), GL_GEOMETRY_SHADER)
    end
end
macro comp_str(source::AbstractString)
    quote
        Shader(symbol(@__FILE__), $(Vector{Uint8}(ascii(source))), GL_COMPUTE_SHADER)
    end
end

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
        sizei = GLsizei[0]
        get_log(obj, maxlength, sizei, buffer)
        length = first(sizei)
        return bytestring(pointer(buffer), length)
    else
        return "success"
    end
end

function iscompiled(shader::GLuint)
    success = GLint[0]
    glGetShaderiv(shader, GL_COMPILE_STATUS, success)
    first(success) == GL_TRUE
end


function createshader(shadertype::GLenum)
    shaderid = glCreateShader(shadertype)
    @assert shaderid > 0 "opengl context is not active or shader type not accepted. Shadertype: $(GLENUM(shadertype).name)"
    shaderid::GLuint
end
function createprogram()
    p = glCreateProgram()
    @assert p > 0 "couldn't create program. Most likely, opengl context is not active"
    p::GLuint
end

shadertype(s::Shader)               = s.typ

shadertype(::File{:comp})           = GL_COMPUTE_SHADER
shadertype(::File{:vert})           = GL_VERTEX_SHADER
shadertype(::File{:frag})           = GL_FRAGMENT_SHADER
shadertype(::File{:geom})           = GL_GEOMETRY_SHADER
shadertype{Ending}(::File{Ending})  = error("File ending doesn't correspond to a shader type. Ending: $(Ending), File: $(abspath(file))")

#Implement File IO interface
Base.read(f::File{:vert}) = Shader(f)
Base.read(f::File{:frag}) = Shader(f)
Base.read(f::File{:geom}) = Shader(f)
Base.write(io::IO, f::File{:vert}) = write(io, f.source)
Base.write(io::IO, f::File{:frag}) = write(io, f.source)
Base.write(io::IO, f::File{:geom}) = write(io, f.source)

compileshader(file::File, program::GLuint) = compileshader(read(file), program)

                    #(shadertype, shadercode) -> shader id
let shader_cache = Dict{(GLenum, Vector{Uint8}), GLuint}() # shader cache prevents that a shader is compiled more than one time
    function compileshader(shader::Shader)
        get!(shader_cache, (shader.typ, shader.source)) do 
            shaderid = createshader(shader.typ)
            glShaderSource(shaderid, shader.source)
            glCompileShader(shaderid)
            if !iscompiled(shaderid)
                print_with_lines(bytestring(shader.source))
                error("shader $(shader.name) didn't compile. \n$(getinfolog(shaderid))")
            end
            shaderid
        end
    end
end



function uniformlocations(nametypedict::Dict{Symbol, GLenum}, program)
    isempty(nametypedict) && return Dict{Symbol,Tuple}()
    texturetarget = -1 # start -1, as texture samplers start at 0
    return Dict{Symbol,Tuple}(map(nametypedict) do name_type
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

# Actually compiles and links shader sources
function GLProgram(
                        shaders::Vector{Shader}, program=createprogram(); 
                        fragdatalocation=(Int, ASCIIString)[]
                    )

    # Remove old shaders
    glUseProgram(0)
    shader_ids = glGetAttachedShaders(program)
    foreach(glDetachShader, program, shader_ids)

    #attach new ones
    shader_ids = map(shaders) do shader
        shaderid = compileshader(shader)
        glAttachShader(program, shaderid)
        shaderid
    end

    #Bind frag data
    for (location, name) in fragdatalocation
        glBindFragDataLocation(program, location, ascii(name))
    end
    
    #link program
    glLinkProgram(program)
    foreach(glDeleteShader, shader_ids) # Can be deleted, as they will still be linked to Program and released after program gets released

    # generate the link locations
    nametypedict        = uniform_name_type(program)
    uniformlocationdict = uniformlocations(nametypedict, program)

    return GLProgram(program, map(name,shaders), nametypedict, uniformlocationdict)
end



# Gives back a signal, which signals true everytime the file gets edited
function isupdated(file::File, update_interval=1.0)
    filename    = abspath(file)
    file_edited = foldl((false, mtime(filename)), every(update_interval)) do v0, v1 
        time_edited = mtime(filename)
        (!isapprox(0.0, v0[2] - time_edited), time_edited)
    end
    return filter(identity, false, lift(first, Bool, file_edited)) # extract bool
end

#reads from the file and updates the source whenever the file gets edited
function lift_shader(shader_file::File)
    lift(Shader, isupdated(shader_file)) do _unused
        read(shader_file)
    end
end


# Takes a shader template and renders the template and returns shader source
template2source(source::Array{UInt8, 1}, attributes::Dict{Symbol, Any}, view::Dict{ASCIIString, ASCIIString}) = template2source(bytestring(source), attributes, view)
function template2source(source::AbstractString, attributes::Dict{Symbol, Any}, view::Dict{ASCIIString, ASCIIString})
    code_template    = Mustache.parse(source)
    specialized_view = merge(createview(attributes, mustachekeys(code_template)), view)
    code_source     = replace(replace(Mustache.render(code_template, specialized_view), "&#x2F;", "/"), "&gt;", ">")
    ascii(code_source)
end


function TemplateProgram(shaders::File...;
                            view::Dict{ASCIIString, ASCIIString}=Dict{ASCIIString, ASCIIString}(), 
                            attributes::Dict{Symbol, Any}=Dict{Symbol, Any}(),
                            fragdatalocation=(Int, ASCIIString)[]
                        )
    code_signals = Reactive.Lift{Shader}[lift_shader(shader_file) for shader_file in shaders]
    TemplateProgram(code_signals, view=view, attributes=attributes, fragdatalocation=fragdatalocation)
end
function TemplateProgram(
                            shaders::Vector{Reactive.Lift{Shader}}, p=createprogram(); 
                            view::Dict{ASCIIString, ASCIIString}=Dict{ASCIIString, ASCIIString}(), 
                            attributes::Dict{Symbol, Any}=Dict{Symbol, Any}(),
                            fragdatalocation=(Int, ASCIIString)[]
                        )

    program_signal = lift(shaders...) do _unused... #just needed to update the signal
        # extract values from signals
        shader_values = map(value, shaders)::Vector{Shader}
        TemplateProgram(shader_values, p, view=view, attributes=attributes, fragdatalocation=fragdatalocation)
    end
end

function TemplateProgram(
                            shaders::Vector{Shader}, p=createprogram(); 
                            view::Dict{ASCIIString, ASCIIString}=Dict{ASCIIString, ASCIIString}(), 
                            attributes::Dict{Symbol, Any}=Dict{Symbol, Any}(),
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
    internaldata = @compat(Dict(
        "GLSL_VERSION"    => glsl_version_string(),
        "GLSL_EXTENSIONS" => extension
    ))
    view = merge(internaldata, view)

    # transform dict of templates into actual shader source
    code = Shader[Shader(shader, source=template2source(shader.source, attributes, view)) for shader in shaders]

    return GLProgram(code, p, fragdatalocation=fragdatalocation)
end



# Gets used to access a 
glsl_variable_access{T,D}(keystring, ::Texture{T, D}) = "texture($(keystring), uv)."*"rgba"[1:length(T)]*";"

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
