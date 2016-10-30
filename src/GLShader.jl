
function Shader(f::File{format"GLSLShader"})
    st = stream(open(f))
    s = Shader(Symbol(f.filename), read(st), shadertype(f))
    close(st)
    s
end
Shader(s::Shader; name=s.name, source=s.source, typ=s.typ) = Shader(name, source, typ)
# Different shader string literals- usage: e.g. frag" my shader code"
macro frag_str(source::AbstractString)
    quote
        Shader(Symbol(@__FILE__), $(Vector{UInt8}(ascii(source))), GL_FRAGMENT_SHADER)
    end
end
macro vert_str(source::AbstractString)
    quote
        Shader(Symbol(@__FILE__), $(Vector{UInt8}(ascii(source))), GL_VERTEX_SHADER)
    end
end
macro geom_str(source::AbstractString)
    quote
        Shader(Symbol(@__FILE__), $(Vector{UInt8}(ascii(source))), GL_GEOMETRY_SHADER)
    end
end
macro comp_str(source::AbstractString)
    quote
        Shader(Symbol(@__FILE__), $(Vector{UInt8}(ascii(source))), GL_COMPUTE_SHADER)
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
        return unsafe_string(pointer(buffer), length)
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

shadertype(s::Shader) = s.typ
function shadertype(f::File{format"GLSLShader"})
    shadertype(file_extension(f))
end
function shadertype(ext::AbstractString)
    ext == ".comp" && return GL_COMPUTE_SHADER
    ext == ".vert" && return GL_VERTEX_SHADER
    ext == ".frag" && return GL_FRAGMENT_SHADER
    ext == ".geom" && return GL_GEOMETRY_SHADER
    error("$ext not a valid extension for $f")
end

#Implement File IO interface
function load(f::File{format"GLSLShader"})
    Shader(f)
end
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
    global empty_shader_cache!, deleteshader!
    function deleteshader!(id::GLuint)
        for (key, s_id) in shader_cache
            if s_id == id
                delete!(shader_cache, key)
                glDeleteShader(s_id)
                break
            end
        end
    end
    function compileshader(shader::Shader)
        get!(shader_cache, (shader.typ, shader.source)) do
            shaderid = createshader(shader.typ)
            glShaderSource(shaderid, shader.source)
            glCompileShader(shaderid)
            if !iscompiled(shaderid)
                print_with_lines(Compat.String(shader.source))
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
    return Dict{Symbol, Tuple}(map(nametypedict) do name_type
        name, typ = name_type
        loc = get_uniform_location(program, name)
        str_name = string(name)
        if istexturesampler(typ)
            texturetarget += 1
            return name => (loc, texturetarget)
        else
            return name => (loc,)
        end
    end)
end
# Actually compiles and links shader sources
function GLProgram(
        shaders::Vector{Shader}, program=createprogram();
        fragdatalocation=Tuple{Int, Compat.UTF8String}[]
    )
    # Remove old shaders
    glUseProgram(0)
    shader_ids = glGetAttachedShaders(program)
    foreach(glDetachShader, repeated(program), shader_ids)
    #foreach(deleteshader!, shader_ids)
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
    nametypedict = uniform_name_type(program)
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

gl_convert(shader::GLProgram, data) = shader




# caching templated shaders is a pain -.-

# cache for template keys per file
# path --> template keys
const _template_cache = Dict{String, Vector{String}}()
# path --> Dict{template_replacements --> Shader)
const _shader_cache = Dict{String, Dict{Any, Shader}}()
const _program_cache = Dict{Any, GLProgram}()
function __init__()
    Base.rehash!(_template_cache)
    Base.rehash!(_shader_cache)
    Base.rehash!(_program_cache)
end
function compile_shader(path, source_str::AbstractString)
    typ = GLAbstraction.shadertype(query(path))
    source = Vector{UInt8}(source_str)
    shaderid = GLAbstraction.createshader(typ)
    glShaderSource(shaderid, source)
    glCompileShader(shaderid)
    if !GLAbstraction.iscompiled(shaderid)
        GLAbstraction.print_with_lines(source_str)
        warn("shader $(path) didn't compile. \n$(GLAbstraction.getinfolog(shaderid))")
    end
    Shader(Symbol(path), source, typ, shaderid)
end

function get_shader!(path, template_replacement, view, attributes)
    # this should always be in here, since we already have the template keys
    shader_dict = _shader_cache[path]
    get!(shader_dict, template_replacement) do
        template_source = readstring(path)
        source = mustache_replace(template_replacement, template_source)
        compile_shader(path, source)::Shader
    end::Shader
end
function get_template!(path, view, attributes)
    get!(_template_cache, path) do
        _, ext = splitext(path)

        typ = shadertype(ext)
        template_source = readstring(path)
        source, replacements = template2source(
            template_source, view, attributes
        )
        s = compile_shader(path, source)
        template_keys = collect(keys(replacements))
        template_replacements = collect(values(replacements))
        # can't yet be in here, since we didn't even have template keys
        _shader_cache[path] = Dict(template_replacements => s)

        template_keys
    end
end


function compile_program(shaders, fragdatalocation)
    # Remove old shaders
    program = createprogram()
    glUseProgram(program)
    #attach new ones
    foreach(shaders) do shader
        glAttachShader(program, shader.id)
    end

    #Bind frag data
    for (location, name) in fragdatalocation
        glBindFragDataLocation(program, location, ascii(name))
    end

    #link program
    glLinkProgram(program)
    if !GLAbstraction.islinked(program)
        error(
            "program $program not linked. Error in: \n",
            join(map(x->String(x.name), shaders), " or "), "\n", getinfolog(program)
        )
    end
    # Can be deleted, as they will still be linked to Program and released after program gets released
    #foreach(glDeleteShader, shader_ids)
    # generate the link locations
    nametypedict = uniform_name_type(program)
    uniformlocationdict = uniformlocations(nametypedict, program)
    GLProgram(program, shaders, nametypedict, uniformlocationdict)
end

function get_view(kw_dict)
    view = get(kw_dict, :view, Dict{String, String}())
    extension = is_apple() ? "" : "#extension GL_ARB_draw_instanced : enable\n"
    view["GLSL_EXTENSION"] = extension*get(()->"", view, "GLSL_EXTENSIONS")
    view["GLSL_VERSION"] = glsl_version_string()
    view
end

function gl_convert(lazyshader::AbstractLazyShader, data)
    kw_dict = Dict(lazyshader.kw_args)
    paths = lazyshader.paths
    template_replacements = map(paths) do path
        template = get_template!(path, get_view(kw_dict), data)
        template_replacement = Dict(map(template) do key
            val = mustache2replacement(key, get_view(kw_dict), data)
            key => val
        end)
    end
    program = get!(_program_cache, (paths, template_replacements)) do
        # when we're here, this means there were uncached shaders, meaning we definitely have
        # to compile a new program
        shaders = map(zip(paths, template_replacements)) do args
            get_shader!(args..., get_view(kw_dict), data)::Shader
        end
        fragdatalocation = get(kw_dict, :fragdatalocation, Tuple{Int, Compat.UTF8String}[])
        compile_program(convert(Vector{Shader}, shaders), fragdatalocation)
    end
end


function insert_from_view(io, replace_view::Function, keyword::AbstractString)
    print(io, replace_view(keyword))
    nothing
end

function insert_from_view(io, replace_view::Dict, keyword::AbstractString)
    if haskey(replace_view, keyword)
        print(io, replace_view[keyword])
    end
    nothing
end
"""
Replaces
{{keyword}} with the key in `replace_view`, or replace_view(key)
in a string
"""
function mustache_replace(replace_view::Union{Dict, Function}, string)
    io = IOBuffer()
    replace_started = false
    open_mustaches = 0
    closed_mustaches = 0
    i = 0
    replace_begin = i
    last_char = SubString(string, 1, 1)
    len = endof(string)
    while i <= len
        i = nextind(string, i)
        char = SubString(string, i, i)
        if replace_started
            # ignore, or wait for }
            if char == "}"
                closed_mustaches += 1
                if closed_mustaches == 2 # we found a complete mustache!
                    insert_from_view(io, replace_view, SubString(string, replace_begin+1, i-2))
                    open_mustaches = 0
                    closed_mustaches = 0
                    replace_started = false
                end
            else
                closed_mustaches = 0
                continue
            end
        elseif char == "{"
            open_mustaches += 1
            if open_mustaches == 2
                replace_begin = i
                replace_started = true
            end
        else
            if open_mustaches == 1
                print(io, last_char)
            end
            print(io, char) # just copy all the rest
            open_mustaches = 0
            closed_mustaches = 0
        end
        last_char = char
    end
    takebuf_string(io)
end


function mustache2replacement(mustache_key, view, attributes)
    haskey(view, mustache_key) && return view[mustache_key]
    for postfix in ("_type", "_calculation")
        keystring = replace(mustache_key, postfix, "")
        keysym = Symbol(keystring)
        if haskey(attributes, keysym)
            val = attributes[keysym]
            if !isa(val, AbstractString)
                return if postfix == "_type"
                    toglsltype_string(val)
                else  postfix == "_calculation"
                    glsl_variable_access(keystring, val)
                end
            end
        end
    end
    "" # no match found, leave empty!
end

# Takes a shader template and renders the template and returns shader source
template2source(source::Array{UInt8, 1}, view, attributes::Dict{Symbol, Any}) = template2source(Compat.String(source), attributes, view)
function template2source(source::AbstractString, view, attributes::Dict{Symbol, Any})
    replacements = Dict{String, String}()
    source = mustache_replace(source) do mustache_key
        r = mustache2replacement(mustache_key, view, attributes)
        replacements[mustache_key] = r
        r
    end
    source, replacements
end


#TemplateProgram() = error("Can't create TemplateProgram without parameters")

function TemplateProgram(x::Union{Shader, File}...; kw_args...)
    TemplateProgram(merge(Dict(
        :view               => Dict{Compat.UTF8String, Compat.UTF8String}(),
        :attributes         => Dict{Symbol, Any}(),
        :fragdatalocation   => Tuple{Int, Compat.UTF8String}[],
        :program            => createprogram()
    ), Dict{Symbol, Any}(kw_args)), x...)
end

function TemplateProgram(kw_args::Dict{Symbol, Any}, s::File, shaders::File...)
    TemplateProgram(kw_args, map(Shader, (s,shaders...))...)
end

function TemplateProgram(kw_args::Dict{Symbol, Any}, s::Shader, shaders::Shader...)
    @materialize program, view, attributes, fragdatalocation = kw_args
    if haskey(view, "in") || haskey(view, "out") || haskey(view, "GLSL_VERSION")
        println("warning: using internal keyword \"$(in/out/GLSL_VERSION)\" for shader template. The value will be overwritten")
    end
    extension = is_apple() ? "" : "#extension GL_ARB_draw_instanced : enable"
    if haskey(view, "GLSL_EXTENSIONS")
        #to do: check custom extension...
        #for now we just append the extensions
        extension *= "\n" * view["GLSL_EXTENSIONS"]
    end
    internaldata = Dict{Compat.UTF8String, Compat.UTF8String}(
        "GLSL_VERSION"    => glsl_version_string(),
        "GLSL_EXTENSIONS" => extension
    )
    view = merge(internaldata, view)

    # transform dict of templates into actual shader source
    code = Shader[Shader(shader, source=template2source(shader.source, attributes, view)[1]) for shader in [s, shaders...]]
    return GLProgram(code, program, fragdatalocation=fragdatalocation)
end


function glsl_version_string()
    glsl = split(unsafe_string(glGetString(GL_SHADING_LANGUAGE_VERSION)), ['.', ' '])
    if length(glsl) >= 2
        glsl = VersionNumber(parse(Int, glsl[1]), parse(Int, glsl[2]))
        glsl.major == 1 && glsl.minor <= 2 && error("OpenGL shading Language version too low. Try updating graphic driver!")
        glsl_version = string(glsl.major) * rpad(string(glsl.minor),2,"0")
        return "#version $(glsl_version)\n"
    else
        error("could not parse GLSL version: $glsl")
    end
end
