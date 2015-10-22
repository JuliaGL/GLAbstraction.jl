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

    function FrameBuffer(dimensions::Input)
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
    boundingbox         ::Signal # workaround for having lazy boundingbox queries, while not using multiple dispatch for boundingbox function (No type hierarchy for RenderObjects)

    function RenderObject(data::Dict{Symbol, Any}, program::Signal{GLProgram}, bbs=Input(AABB{Float32}(Vec3f0(0),Vec3f0(1))), main=nothing)
        global RENDER_OBJECT_ID_COUNTER
        RENDER_OBJECT_ID_COUNTER     += one(GLushort)
        program              = program.value
        buffers              = filter((key, value) -> isa(value, GLBuffer), data)
        uniforms             = filter((key, value) -> !isa(value, GLBuffer), data)
        data[:objectid]      = RENDER_OBJECT_ID_COUNTER # automatucally integrate object ID, will be discarded if shader doesn't use it
        get!(data, :visible, true) # make sure, visibility is set

        vertexarray = GLVertexArray(Dict{Symbol, GLBuffer}(buffers), program)

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
