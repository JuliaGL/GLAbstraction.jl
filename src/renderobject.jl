emit_placeholder(position, fragout) = nothing

glsl_type{T <: AbstractFloat}(::Type{T}) = Float32
glsl_type{T}(::UniformBuffer{T}) = T
glsl_type{T, N}(::Texture{T, N}) = gli.GLTexture{glsl_type(T), N}

immutable RenderObject{Vertex, N, Args}
    program::GLuint
    uniform_locations::NTuple{N, Int}
end

function (p::RenderObject{Vertex, N, Args}){Vertex, N, Args}(vertexarray::VertexArray{Vertex}, uniforms::Args)
    glUseProgram(p.program)
    blockid = 0
    for (i, uniform_idx) in enumerate(p.uniform_locations)
        uniform = uniforms[i]
        if isa(uniform, UniformBuffer)
            glBindBufferBase(GL_UNIFORM_BUFFER, blockid, uniform.buffer.id)
            blockid += 1
        elseif isa(uniform, Texture)
            gluniform(uniform_idx, blockid, uniform)
        end
    end
    glBindVertexArray(vertexarray.id)
    draw_vbo(vertexarray)
    glBindVertexArray(0)
end

function RenderObject{T}(
        window::Context,
        vertexarray::AbstractArray{T},
        uniforms::Tuple,
        vertexshader::Function,
        fragmentshader::Function;
        kw_args...
    )
    # TODO remove this hack. This is needed, because in the Julia backend we need th vbo
    # to contain tuples, while in opengl we need it to contain singular elements and communicate
    # the tuple nature via the face type
    vertexarray, ft = if T <: NTuple{N, <: AbstractVertex} where N
        reinterpret(eltype(T), vertexarray), Face{nfields(T), Int}
    else
        vertexarray, gl_face_type(T)
    end
    vbo = VertexArray(vertexarray, face_type = ft)
    gl_uniforms = map(x-> convert(UniformBuffer, x), uniforms)
    RenderObject(
        window,
        vbo, gl_uniforms,
        vertexshader, fragmentshader;
        kw_args...
    )
end

function RenderObject(
        window::Context,
        vertexarray::VertexArray,
        uniforms::T,
        vertexshader::Function,
        fragmentshader::Function;
        geometryshader = nothing,
        max_primitives = 4,
        primitive_in = :points,
        primitive_out = :triangle_strip,
    ) where T <: Tuple{Vararg{X where X <: UniformBuffer}}

    shaders = Shader[]

    uniform_types = map(glsl_type, uniforms)
    vertex_type = eltype(vertexarray)

    argtypes = (vertex_type, uniform_types...)
    vsource, vertexout = emit_vertex_shader(vertexshader, argtypes)
    vshader = compile_shader(vsource, GL_VERTEX_SHADER, :particle_vert)
    push!(shaders, vshader)
    fragment_in = vertexout # we first assume vertex stage outputs to fragment stage
    if geometryshader != nothing
        argtypes = (typeof(emit_placeholder), vertexout, uniform_types...)
        gsource, geomout = emit_geometry_shader(
            geometryshader, argtypes,
            max_primitives = max_primitives,
            primitive_in = primitive_in,
            primitive_out = primitive_out
        )
        gshader = compile_shader(gsource, GL_GEOMETRY_SHADER, :particle_geom)
        push!(shaders, gshader)
        fragment_in = geomout # rewire if geometry shader is present
    end

    argtypes = (fragment_in, uniform_types...)
    fsource, fragout = emit_fragment_shader(fragmentshader, argtypes)
    fshader = compile_shader(fsource, GL_FRAGMENT_SHADER, :particle_frag)
    push!(shaders, fshader)
    program = compile_program(shaders...)
    N = length(uniform_types)
    block_idx = 0
    uniform_locations = ntuple(N) do i
        if isa(uniforms[i], Texture)
            get_uniform_location(program, "intensities")
        else
            idx = glGetUniformBlockIndex(program, glsl_gensym("UniformArg$i"))
            glUniformBlockBinding(program, idx, block_idx)
            block_idx += 1
            idx
        end
    end
    raster = RenderObject{vertex_type, N, T}(
        program, uniform_locations
    )
    raster, (vertexarray, uniforms)
end

export RenderObject


function fullscreen_pass(fragment_shader, frag_args...)
    RenderObject(fragment_shader, fullscreen_vert, frag_args)

pass1 = RenderObject(pass1_frag, )
