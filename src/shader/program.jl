islinked(program::GLuint) = glGetProgramiv(program, GL_LINK_STATUS) == GL_TRUE

abstract type AbstractProgram end
mutable struct Program <: AbstractProgram
    id          ::GLuint
    shaders     ::Vector{Shader}
    nametype    ::Dict{Symbol, GLenum}
    uniformloc  ::Dict{Symbol, Tuple}
    context     ::AbstractContext
    function Program(shaders::Vector{Shader}, fragdatalocation::Vector{Tuple{Int, String}})
        # Remove old shaders
        exists_context()
        program = glCreateProgram()::GLuint
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
                write(stdout, shader.source)
                println("---------------------------")
            end
            @error "program $program not linked. Error in: \n $(join(map(x-> string(x.name), shaders))), or, \n $(getinfolog(program))"
        end

        # generate the link locations
        nametypedict = uniform_nametype(program)
        uniformlocationdict = uniformlocations(nametypedict, program)
        new(program, shaders, nametypedict, uniformlocationdict, current_context())
    end
end

function Program(sh_string_typ...)
    shaders = Shader[]
    for (source, typ) in sh_string_typ
        push!(shaders, Shader(gensym(), typ, Vector{UInt8}(source)))
    end
    Program(shaders, Tuple{Int, String}[])
end


bind(program::Program) = glUseProgram(program.id)
unbind(program::AbstractProgram) = glUseProgram(0)

mutable struct LazyProgram <: AbstractProgram
    sources::Vector
    data::Dict
    compiled_program::Union{Program, Nothing}
end
LazyProgram(sources...; data...) = LazyProgram(Vector(sources), Dict(data), nothing)

function Program(lazy_program::LazyProgram)
    fragdatalocation = get(lazy_program.data, :fragdatalocation, Tuple{Int, String}[])
    shaders = haskey(lazy_program.data, :arguments) ? Shader.(lazy_program.sources, Ref(lazy_program.data[:arguments])) : Shader.()
    return Program([shaders...], fragdatalocation)
end
function bind(program::LazyProgram)
    iscompiled_orcompile!(program)
    bind(program.compiled_program)
end

function iscompiled_orcompile!(program::LazyProgram)
    if program.compiled_program == nothing
        program.compiled_program = Program(program)
    end
end

####################################################################################
# freeing

# OpenGL has the annoying habit of reusing id's when creating a new context
# We need to make sure to only free the current one
function free!(x::Program)
    if !is_current_context(x.context)
        return x
    end
    try
        glDeleteProgram(x.id)
    catch e
        free_handle_error(e)
    end
    return
end

function Base.show(io::IO, p::Program)
    println(io, "Program: $(p.id)")
    println(io, "Shaders:")
    for shader in p.shaders
        println(io, shader)
    end
    println(io, "uniforms:")
    for (name, typ) in p.nametype
        println(io, "   ", name, "::", GLENUM(typ).name)
    end
end

function uniform_nametype(program::GLuint)
    uniformLength = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)
    Dict{Symbol, GLenum}(ntuple(uniformLength) do i # take size and name
        name, typ = glGetActiveUniform(program, i-1)
    end)
end
function attribute_nametype(program::GLuint)
    uniformLength = glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES)
    Dict{Symbol, GLenum}(ntuple(uniformLength) do i
        name, typ = glGetActiveAttrib(program, i-1)
    end)
end

function uniforms_info(p::Program)
    program = p.id
    # Get uniforms info (not in named blocks)
    activeUnif = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)

    uniforms = Dict{Symbol, Any}[]
    for i in 0:activeUnif-1
        index = glGetActiveUniformsiv(program, i, GL_UNIFORM_BLOCK_INDEX)
        if (index == -1)
            for_dict = Dict{Symbol, Any}()
            name = glGetActiveUniformName(program, i)
            for_dict[:uniType] = glGetActiveUniformsiv(program, i, GL_UNIFORM_TYPE)

            for_dict[:uniSize] = glGetActiveUniformsiv(program, i, GL_UNIFORM_SIZE)
            for_dict[:uniArrayStride] = glGetActiveUniformsiv(program, i, GL_UNIFORM_ARRAY_STRIDE)

            auxSize = 0
            if (uniArrayStride > 0)
                for_dict[:auxSize] = uniArrayStride * uniSize
            else
                for_dict[:auxSize] = spGLSLTypeSize[uniType]
            end
            uniforms[name] = for_dict
        end
    end
    result[:uniforms] = uniforms
    # Get named blocks info
    count = glGetProgramiv(program, GL_ACTIVE_UNIFORM_BLOCKS)
    result[:uniform_blocks] = Dict{Symbol, Any}(map(0:count-1) do i
        for_dict = Dict{Symbol, Any}()
        # Get blocks name
        name = glGetActiveUniformBlockName(program, i)
        for_dict[:dataSize] = glGetActiveUniformBlockiv(program, i, GL_UNIFORM_BLOCK_DATA_SIZE)

        index = glGetActiveUniformBlockiv(program, i,  GL_UNIFORM_BLOCK_BINDING)
        for_dict[:binding_point] = glGetIntegeri_v(GL_UNIFORM_BUFFER_BINDING, index)
        for_dict[:activeUnif] = glGetActiveUniformBlockiv(program, i, GL_UNIFORM_BLOCK_ACTIVE_UNIFORMS)
        indices = zeros(GLuint, activeUnif)
        glGetActiveUniformBlockiv(program, i, GL_UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES, indices)
        for_dict[:uniformblocks] = map(indices) do ubindex
            for_dict = Dict{Symbol, Any}()
            for_dict[:name] = glGetActiveUniformName(program, ubindex)
            for_dict[:uniType] = glGetActiveUniformsiv(program, ubindex, GL_UNIFORM_TYPE)
            for_dict[:uniOffset] = glGetActiveUniformsiv(program, ubindex, GL_UNIFORM_OFFSET)
            for_dict[:uniSize] = glGetActiveUniformsiv(program, ubindex, GL_UNIFORM_SIZE)
            for_dict[:uniMatStride] = glGetActiveUniformsiv(program, ubindex, GL_UNIFORM_MATRIX_STRIDE)
            for_dict
        end
        name => for_dict
    end)
    result
end

# display the values for uniforms in the default block
function uniform_info(p::Program, uniName::Symbol)
    result = Dict{Symbol, Any}()
    # is it a program ?
    result[:program] = p.id
    result[:loc] = glGetUniformLocation(program, uniName)
    name, typ, uniform_size = glGetActiveUniform(program, loc)
    result[:name] = name
    result[:typ] = typ
    result[:size] = uniform_size
    result
end

# display the values for a uniform in a named block
function uniform_in_block_info(p::Program, blockName, uniName)
    result = Dict{Symbol, Any}()
    program = p.id

    result[:index] = glGetUniformBlockIndex(program, blockName)
    if (index == GL_INVALID_INDEX)
        println("$uniName is not a valid uniform name in block $blockName")
    end
    result[:bindIndex] = glGetActiveUniformBlockiv(program, index, GL_UNIFORM_BLOCK_BINDING)
    result[:bufferIndex] = glGetIntegeri_v(GL_UNIFORM_BUFFER_BINDING, result[:bindIndex])
    result[:uniIndex] = glGetUniformIndices(program, uniName)
    uniIndex = result[:uniIndex]
    result[:uniType] = glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_TYPE)
    result[:uniOffset] = glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_OFFSET)
    result[:uniSize] = glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_SIZE)
    result[:uniArrayStride] = glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_ARRAY_STRIDE)
    result[:uniMatStride] = glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_MATRIX_STRIDE)
    result
end

# display information for a program's attributes
function attributes_info(p::Program)
    program = p.id
    # how many attribs?
    activeAttr = glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES)
    # get location and type for each attrib
    map(0:activeAttr-1) do i
        result = Dict{Symbol, Any}()
        name, typ, siz = glGetActiveAttrib(program, i)
        result[:name] = name
        result[:type] = typ
        result[:size] = siz
        result[:location] = glGetAttribLocation(program, name)
        result
    end
end

# display program's information
function program_info(p::Program)
    result = Dict{Symbol, Any}()
    # check if name is really a program
    result[:program] = p.id
    # Get the shader's name
    result[:shaders] = glGetAttachedShaders(program)
    for shader in shaders
        result[Symbol("shader_type_$shader")] = GLENUM(convert(GLenum, glGetShaderiv(shader, GL_SHADER_TYPE))).name
    end
    # Get program info
    result[:program_seperable] = glGetProgramiv(program, GL_PROGRAM_SEPARABLE)
    result[:binary_retrievable_hint] = glGetProgramiv(program, GL_PROGRAM_BINARY_RETRIEVABLE_HINT)
    result[:link_status] = glGetProgramiv(program, GL_LINK_STATUS)
    result[:validate_status] = glGetProgramiv(program, GL_VALIDATE_STATUS)
    result[:delete_status] = glGetProgramiv(program, GL_DELETE_STATUS)
    result[:active_attributes] = glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES)
    result[:active_uniforms] = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)
    result[:active_uniform_blocks] = glGetProgramiv(program, GL_ACTIVE_UNIFORM_BLOCKS)
    result[:active_atomic_counter_buffers] = glGetProgramiv(program, GL_ACTIVE_ATOMIC_COUNTER_BUFFERS)
    result[:transform_feedback_buffer_mode] = glGetProgramiv(program, GL_TRANSFORM_FEEDBACK_BUFFER_MODE)
    result[:transform_feedback_varyings] = glGetProgramiv(program, GL_TRANSFORM_FEEDBACK_VARYINGS)
    result
end

function uniformlocations(nametypedict::Dict{Symbol, GLenum}, program)
    result = Dict{Symbol, Tuple}()
    texturetarget = -1 # start -1, as texture samplers start at 0
    for (name, typ) in nametypedict
        loc = get_uniform_location(program, name)
        str_name = string(name)
        if istexturesampler(typ)
            texturetarget += 1
            result[name] = (loc, texturetarget)
        else
            result[name] = (loc,)
        end
    end
    return result
end

function istexturesampler(typ::GLenum)
    return (
        typ == GL_SAMPLER_BUFFER || typ == GL_INT_SAMPLER_BUFFER || typ == GL_UNSIGNED_INT_SAMPLER_BUFFER ||
    	typ == GL_IMAGE_2D ||
        typ == GL_SAMPLER_1D || typ == GL_SAMPLER_2D || typ == GL_SAMPLER_3D ||
        typ == GL_UNSIGNED_INT_SAMPLER_1D || typ == GL_UNSIGNED_INT_SAMPLER_2D || typ == GL_UNSIGNED_INT_SAMPLER_3D ||
        typ == GL_INT_SAMPLER_1D || typ == GL_INT_SAMPLER_2D || typ == GL_INT_SAMPLER_3D ||
        typ == GL_SAMPLER_1D_ARRAY || typ == GL_SAMPLER_2D_ARRAY ||
        typ == GL_UNSIGNED_INT_SAMPLER_1D_ARRAY || typ == GL_UNSIGNED_INT_SAMPLER_2D_ARRAY ||
        typ == GL_INT_SAMPLER_1D_ARRAY || typ == GL_INT_SAMPLER_2D_ARRAY
    )
end

function infolog(program::Program)
    # Get the maximum possible length for the descriptive error message
    maxlength = GLint[0]
    glGetProgramiv(program.id, GL_INFO_LOG_LENGTH, maxlength)
    maxlength = first(maxlength)
    # Return the text of the message if there is any
    if maxlength > 0
        buffer = zeros(GLchar, maxlength)
        sizei = GLsizei[0]
        glGetProgramInfoLog(program.id, maxlength, sizei, buffer)
        length = first(sizei)
        return unsafe_string(pointer(buffer), length)
    else
        return "success"
    end
end
