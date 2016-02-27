
function Shader(f::File{format"GLSLShader"})
    st = stream(open(f))
    s = Shader(symbol(f.filename), read(st), shadertype(f))
    close(st)
    s
end
Shader(s::Shader; name=s.name, source=s.source, typ=s.typ) = Shader(name, source, typ)
# Different shader string literals- usage: e.g. frag" my shader code"
macro frag_str(source::AbstractString)
    quote
        Shader(symbol(@__FILE__), $(Vector{UInt8}(ascii(source))), GL_FRAGMENT_SHADER)
    end
end
macro vert_str(source::AbstractString)
    quote
        Shader(symbol(@__FILE__), $(Vector{UInt8}(ascii(source))), GL_VERTEX_SHADER)
    end
end
macro geom_str(source::AbstractString)
    quote
        Shader(symbol(@__FILE__), $(Vector{UInt8}(ascii(source))), GL_GEOMETRY_SHADER)
    end
end
macro comp_str(source::AbstractString)
    quote
        Shader(symbol(@__FILE__), $(Vector{UInt8}(ascii(source))), GL_COMPUTE_SHADER)
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
    return first(success) == GL_TRUE
end
islinked(program::GLuint) = glGetProgramiv(program, GL_LINK_STATUS) == GL_TRUE

function createshader(shadertype::GLenum)
    shaderid = glCreateShader(shadertype)
    @assert shaderid > 0 "opengl context is not active or shader type not accepted. Shadertype: $(GLENUM(shadertype).name)"
    shaderid::GLuint
end
function createprogram()
    program = glCreateProgram()
    @assert program > 0 "couldn't create program. Most likely, opengl context is not active"
    program::GLuint
end

shadertype(s::Shader)                      = s.typ
function shadertype(f::File{format"GLSLShader"})
    ext = file_extension(f)
    ext == ".comp" && return GL_COMPUTE_SHADER
    ext == ".vert" && return GL_VERTEX_SHADER
    ext == ".frag" && return GL_FRAGMENT_SHADER
    ext == ".geom" && return GL_GEOMETRY_SHADER
    error("$ext not a valid extension for $f")
end

"""
Gives back a signal, which signals true everytime the file gets edited
"""
function isupdated(file::File, updatewhile=Signal(true), update_interval=1.0)
    fn = filename(file)
    file_edited = foldp((false, mtime(fn)), fpswhen(updatewhile, 1.0/update_interval)) do v0, v1
        time_edited = mtime(fn)
        (!isapprox(0.0, v0[2] - time_edited), time_edited)
    end
    preserve(file_edited)
    return preserve(filter(identity, false, const_lift(first, file_edited))) # extract bool
end

#reads from the file and updates the source whenever the file gets edited
function const_lift_shader(shader_file::File, updatewhile=Signal(true), update_interval=1.0)
    s = const_lift(isupdated(shader_file, updatewhile, update_interval)) do _unused
        Shader(shader_file)
    end
    preserve(s)
end

#Implement File IO interface
load(f::File{format"GLSLShader"}) = preserve(const_lift_shader(f))
function save(f::File{format"GLSLShader"}, data::Shader)
    s = open(f, "w")
    write(s, data.source)
    close(s)
end

compileshader(file::File{format"GLSLShader"}, program::GLuint) = compileshader(load(file), program)
                    #(shadertype, shadercode) -> shader id
let shader_cache = Dict{Tuple{GLenum, Vector{UInt8}}, GLuint}() # shader cache prevents that a shader is compiled more than one time
    #finalizer(shader_cache, dict->foreach(glDeleteShader, values(dict))) # delete all shaders when done
    empty_shader_cache!() = empty!(shader_cache)
    global empty_shader_cache!

    function compileshader(shader::Shader)
        get!(shader_cache, (shader.typ, shader.source)) do
            shaderid = createshader(shader.typ)
            @assert isascii(bytestring(shader.source))
            glShaderSource(shaderid, shader.source)
            glCompileShader(shaderid)
            if !iscompiled(shaderid)
                print_with_lines(bytestring(shader.source))
                warn("shader $(shader.name) didn't compile. \n$(getinfolog(shaderid))")
            end
            shaderid
        end
    end
end

export empty_shadercache

function uniformlocations(nametypedict::Dict{Symbol, GLenum}, program)
    isempty(nametypedict) && return Dict{Symbol,Tuple}()
    texturetarget = -1 # start -1, as texture samplers start at 0
    return Dict{Symbol,Tuple}(map(nametypedict) do name_type
        name, typ = name_type
        loc = get_uniform_location(program, name)
        str_name = string(name)
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
        fragdatalocation=Tuple{Int, ASCIIString}[]
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
    !islinked(program) && warn("program $program not linked. Error in: \n", join(map(x->x.name, shaders), " or\n"), "\n", getinfolog(program))
    #foreach(glDeleteShader, shader_ids) # Can be deleted, as they will still be linked to Program and released after program gets released

    # generate the link locations
    nametypedict        = uniform_name_type(program)
    uniformlocationdict = uniformlocations(nametypedict, program)

    GLProgram(program, shaders, nametypedict, uniformlocationdict)
end


abstract AbstractLazyShader
immutable LazyShader <: AbstractLazyShader
    paths  ::Tuple
    kw_args::Vector
    function LazyShader(paths...; kw_args...)
        new(paths, kw_args)
    end
end

gl_convert(lazyshader::AbstractLazyShader, data) = TemplateProgram(
    lazyshader.paths...;
    attributes = data,
    lazyshader.kw_args...
)


# Takes a shader template and renders the template and returns shader source
template2source(source::Array{UInt8, 1}, attributes::Dict{Symbol, Any}, view::Dict{ASCIIString, ASCIIString}) = template2source(bytestring(source), attributes, view)
function template2source(source::AbstractString, attributes::Dict{Symbol, Any}, view::Dict{ASCIIString, ASCIIString})
    code_template    = Mustache.parse(source)
    specialized_view = merge(createview(attributes, mustachekeys(code_template)), view)
    code_source      = replace(replace(Mustache.render(code_template, specialized_view), "&#x2F;", "/"), "&gt;", ">")
    ascii(code_source)
end

#TemplateProgram() = error("Can't create TemplateProgram without parameters")


function TemplateProgram(x::Union{Shader, File, Signal{Shader}}...; kw_args...)
    TemplateProgram(merge(Dict(
        :view               => Dict{ASCIIString, ASCIIString}(),
        :attributes         => Dict{Symbol, Any}(),
        :fragdatalocation   => Tuple{Int, ASCIIString}[],
        :program            => createprogram()
    ), Dict{Symbol, Any}(kw_args)), x...)
end

function TemplateProgram(kw_args::Dict{Symbol, Any}, s::File, shaders::File...)
    updatewhile     = get(kw_args, :updatewhile, Signal(true))
    update_interval = get(kw_args, :update_interval, 1.0)
    shader_signals  = map(s->const_lift_shader(s, updatewhile, update_interval), [s,shaders...])
    TemplateProgram(kw_args, shader_signals...)
end
function TemplateProgram(kw_args::Dict{Symbol, Any}, s::Signal{Shader}, shaders::Signal{Shader}...)
    program_signal = const_lift(s, shaders...) do _unused... #just needed to update the signal
        # extract values from signals
        shader_values = map(value, [s, shaders...])
        TemplateProgram(kw_args, shader_values...)
    end
    Reactive.preserve(program_signal)
    program_signal
end
function TemplateProgram(kw_args::Dict{Symbol, Any}, shaders::Union{Shader,Signal{Shader}}...)
    newshaders = map(s->isa(s, Shader) ? Signal(s) : s, shaders)
    TemplateProgram(kw_args, newshaders...)
end

function TemplateProgram(kw_args::Dict{Symbol, Any}, s::Shader, shaders::Shader...)
    @materialize program, view, attributes, fragdatalocation = kw_args
    if haskey(view, "in") || haskey(view, "out") || haskey(view, "GLSL_VERSION")
        println("warning: using internal keyword \"$(in/out/GLSL_VERSION)\" for shader template. The value will be overwritten")
    end
    extension = @osx? "" : "#extension GL_ARB_draw_instanced : enable"
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

    # transform dict of templates into actual shader source
    code = Shader[Shader(shader, source=template2source(shader.source, attributes, view)) for shader in [s, shaders...]]
    return GLProgram(code, program, fragdatalocation=fragdatalocation)
end



function createview(x::Dict{Symbol, Any}, keys)
  view = Dict{ASCIIString, ASCIIString}()
  for (key, val) in x
    if !isa(val, AbstractString)
        keystring = string(key)
        typekey = keystring*"_type"
        calculationkey = keystring*"_calculation"
        in(typekey, keys) && (view[keystring*"_type"] = toglsltype_string(val))
        in(calculationkey, keys) && (view[keystring*"_calculation"] = glsl_variable_access(keystring, val))
    end
  end
  view
end
mustachekeys(mustache::Mustache.MustacheTokens) = map(x->x[2], filter(x-> x[1] == "name", mustache.tokens))

function glsl_version_string()
    glsl = split(bytestring(glGetString(GL_SHADING_LANGUAGE_VERSION)), ['.', ' '])
    if length(glsl) >= 2
        glsl = VersionNumber(parse(Int, glsl[1]), parse(Int, glsl[2]))
        glsl.major == 1 && glsl.minor <= 2 && error("OpenGL shading Language version too low. Try updating graphic driver!")
        glsl_version = string(glsl.major) * rpad(string(glsl.minor),2,"0")
        return "#version $(glsl_version)\n"
    else
        error("could not parse GLSL version: $glsl")
    end
end
