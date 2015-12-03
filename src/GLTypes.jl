############################################################################

type GLProgram
    id          ::GLuint
    names       ::Vector{Symbol}
    nametype    ::Dict{Symbol, GLenum}
    uniformloc  ::Dict{Symbol, Tuple}

    function GLProgram(id::GLuint, names::Vector{Symbol}, nametype::Dict{Symbol, GLenum}, uniformloc::Dict{Symbol, Tuple})
        obj = new(id, names, nametype, uniformloc)
        #finalizer(obj, free)
        obj
    end
end



############################################
# Framebuffers and the like

immutable RenderBuffer
    id      ::GLuint
    format  ::GLenum

    function RenderBuffer(format, dimension)
        @assert length(dimensions) == 2
        id = GLuint[0]
        glGenRenderbuffers(1, id)
        glBindRenderbuffer(GL_RENDERBUFFER, id[1])
        glRenderbufferStorage(GL_RENDERBUFFER, format, dimension...)
        new(id, format)
    end
end
function resize!(rb::RenderBuffer, newsize::AbstractArray)
    if length(newsize) != 2
        error("RenderBuffer needs to be 2 dimensional. Dimension found: ", newsize)
    end
    glBindRenderbuffer(GL_RENDERBUFFER, rb.id)
    glRenderbufferStorage(GL_RENDERBUFFER, rb.format, newsize...)
end

immutable FrameBuffer{T}
    id          ::GLuint
    attachments ::Vector{Any}

    function FrameBuffer(dimensions::Signal)
        fb = glGenFramebuffers()
        glBindFramebuffer(GL_FRAMEBUFFER, fb)
    end
end
function resize!(fbo::FrameBuffer, newsize::AbstractArray)
    if length(newsize) != 2
        error("FrameBuffer needs to be 2 dimensional. Dimension found: ", newsize)
    end
    for elem in fbo.attachments
        resize!(elem)
    end
end

########################################################################################
# OpenGL Arrays


const GLArrayEltypes = Union{FixedVector, Real, Colorant}

#Transfomr julia datatypes to opengl enum type
julia2glenum{T <: FixedPoint}(x::Type{T})               = julia2glenum(FixedPointNumbers.rawtype(x))
julia2glenum{T <: GLArrayEltypes}(x::Union{Type{T}, T}) = julia2glenum(eltype(x))

let TO_GL_TYPE = Dict(
        GLubyte     => GL_UNSIGNED_BYTE,
        GLbyte      => GL_BYTE,
        GLuint      => GL_UNSIGNED_INT,
        GLushort    => GL_UNSIGNED_SHORT,
        GLshort     => GL_SHORT,
        GLint       => GL_INT,
        GLfloat     => GL_FLOAT,
        Float16     => GL_HALF_FLOAT
    )
    julia2glenum{T <: Real}(::Type{T}) = get(TO_GL_TYPE, T) do
        error("Type: $T not supported as pixel datatype")
    end
end

include("GLBuffer.jl")
include("GLTexture.jl")

########################################################################


type GLVertexArray
  program       ::GLProgram
  id            ::GLuint
  length        ::Int
  indexlength   ::Int # is negative if not indexed

  function GLVertexArray(bufferdict::Dict{Symbol, GLBuffer}, program::GLProgram)
    #get the size of the first array, to assert later, that all have the same size
    indexSize = -1
    len = -1
    id  = glGenVertexArrays()
    glBindVertexArray(id)
    for (name, buffer) in bufferdict
        if buffer.buffertype == GL_ELEMENT_ARRAY_BUFFER
            glBindBuffer(buffer.buffertype, buffer.id)
            indexSize = length(buffer) * cardinality(buffer)
        else
            attribute = string(name)
            if len == -1
                len = length(buffer)
            end
            if len != length(buffer)
                error("buffer $attribute has not the same length as the other buffers. Has: $(length(buffer)). Should have: $len")
            end
            glBindBuffer(buffer.buffertype, buffer.id)
            attribLocation = get_attribute_location(program.id, attribute)
            glVertexAttribPointer(attribLocation, cardinality(buffer), julia2glenum(eltype(buffer)), GL_FALSE, 0, C_NULL)
            glEnableVertexAttribArray(attribLocation)
        end
    end
    glBindVertexArray(0)
    obj = new(program, id, len, indexSize)
    finalizer(obj, free)
    obj
    end
end
GLVertexArray(bufferDict::Dict{ASCIIString, GLBuffer}, program::GLProgram) = GLVertexArray(mapkeys(symbol, bufferdict), program)

free(x::GLVertexArray) = glDeleteVertexArrays(1, [x.id])



##################################################################################

RENDER_OBJECT_ID_COUNTER = zero(GLushort)

type RenderObject <: Composable{DeviceUnit}
    main                ::Any # main object
    uniforms            ::Dict{Symbol, Any}
    vertexarray         ::GLVertexArray
    prerenderfunctions  ::Dict{Function, Tuple}
    postrenderfunctions ::Dict{Function, Tuple}
    id                  ::GLushort
    boundingbox          # workaround for having lazy boundingbox queries, while not using multiple dispatch for boundingbox function (No type hierarchy for RenderObjects)

    function RenderObject(data::Dict{Symbol, Any}, program, bbs=Signal(AABB{Float32}(Vec3f0(0),Vec3f0(1))), main=nothing)
        global RENDER_OBJECT_ID_COUNTER
        RENDER_OBJECT_ID_COUNTER += one(GLushort)
        targets = get(data, :gl_convert_targets, Dict())
        println(targets)
        passthrough = Dict{Symbol, Any}() # we also save a few non opengl related values in data
        for (k,v) in data # convert everything to OpenGL compatible types
            k == :light && continue
            if haskey(targets, k)
                data[k] = gl_convert(targets[k], v) # glconvert is designed to just convert everything to a fitting opengl datatype, but sometimes exceptions are needed
                # e.g. Texture{T,1} and GLBuffer{T} are both usable as an native conversion canditate for a Julia's Array{T, 1} type.
                # but in some cases we want a Texture, sometimes a GLBuffer or TextureBuffer
            else
                if applicable(gl_convert, v) # if can't be converted to an OpenGL datatype,
                    data[k] = gl_convert(v)
                else # put it in passthrough
                    delete!(data, k)
                    passthrough[k] = v
                end
            end
        end
        meshs = filter((key, value) -> isa(value, NativeMesh), data)
        if !isempty(meshs)
            merge!(data, map(x->last(x).data, meshs)...)
        end
        buffers         = filter((key, value) -> isa(value, GLBuffer), data)
        uniforms        = filter((key, value) -> !isa(value, GLBuffer), data)
        get!(data, :visible, true) # make sure, visibility is set
        merge!(data, passthrough) # in the end, we insert back the non opengl data, to keep things simple
        p = value(gl_convert(value(program), data)) # "compile" lazyshader
        vertexarray = GLVertexArray(Dict{Symbol, GLBuffer}(buffers), p)
        data[:objectid] = RENDER_OBJECT_ID_COUNTER # automatucally integrate object ID, will be discarded if shader doesn't use it

        return new(
            main,
            data,
            vertexarray,
            Dict{Function, Tuple}(),
            Dict{Function, Tuple}(),
            RENDER_OBJECT_ID_COUNTER,
            bbs
        )
    end
end



include("GLRenderObject.jl")




####################################################################################
# freeing
free(x::GLProgram)      = try glDeleteProgram(x.id) end # context might not be active anymore, so it errors and doesn' need to be freed anymore
free(x::GLBuffer)       = try glDeleteBuffers(x.id) end
free(x::Texture)        = try glDeleteTextures(x.id) end
free(x::GLVertexArray)  = try glDeleteVertexArrays(x.id) end
