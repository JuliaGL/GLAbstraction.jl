mutable struct GLProgram
    id          ::GLuint
    shader      ::Vector{Shader}
    nametype    ::Dict{Symbol, GLenum}
    uniformloc  ::Dict{Symbol, Tuple}
    context     ::GLContext
    function GLProgram(id::GLuint, shader::Vector{Shader}, nametype::Dict{Symbol, GLenum}, uniformloc::Dict{Symbol, Tuple})
        obj = new(id, shader, nametype, uniformloc, current_context())
        finalizer(obj, free)
        obj
    end
end
####################################################################################
# freeing

# OpenGL has the annoying habit of reusing id's when creating a new context
# We need to make sure to only free the current one
function free(x::GLProgram)
    if !is_current_context(x.context)
        return # don't free from other context
    end
    try
        glDeleteProgram(x.id)
    catch e
        free_handle_error(e)
    end
    return
end

function Base.show(io::IO, p::GLProgram)
    println(io, "GLProgram: $(p.id)")
    println(io, "Shaders:")
    for shader in p.shader
        println(io, shader)
    end
    println(io, "uniforms:")
    for (name, typ) in p.nametype
        println(io, "   ", name, "::", GLENUM(typ).name)
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
    if !islinked(program)
        for shader in shaders
            write(STDOUT, shader.source)
            println("---------------------------")
        end
        error(
            "program $program not linked. Error in: \n",
            join(map(x-> string(x.name), shaders), " or "), "\n", getinfolog(program)
        )
    end
    # Can be deleted, as they will still be linked to Program and released after program gets released
    #foreach(glDeleteShader, shader_ids)
    # generate the link locations
    nametypedict = uniform_name_type(program)
    uniformlocationdict = uniformlocations(nametypedict, program)
    GLProgram(program, shaders, nametypedict, uniformlocationdict)
end
