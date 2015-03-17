abstract AbstractFixedVector{T, NDim}


##############################################################################
abstract Shape
immutable Circle{T <: Real} <: Shape
    x::T
    y::T
    r::T
end

type Rectangle{T <: Real} <: Shape
    x::T
    y::T
    w::T
    h::T
end
#Axis Aligned Bounding Box
immutable AABB{T}
  min::Vector3{T}
  max::Vector3{T}
end
############################################################################

type GLProgram
    id::GLuint
    names::Vector{Symbol}
    nametype::Dict{Symbol, GLenum}
    uniformloc::Dict{Symbol, Tuple}
    function GLProgram(id::GLuint, names::Vector{Symbol}, nametype::Dict{Symbol, GLenum}, uniformloc::Dict{Symbol, Tuple})
        obj = new(id, names, nametype, uniformloc)
        finalizer(obj, delete!)
        obj
    end
end
function Base.delete!(x::GLProgram)
    glDeleteProgram(x.id)
end


############################################
# Framebuffers and the like

immutable RenderBuffer
    id::GLuint
    format::GLenum
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
    id::GLuint
    attachments::Vector{Any}

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

#=
type Texture{T <: TEXTURE_COMPATIBLE_NUMBER_TYPES, ColorDIM, NDIM}
    id::GLuint
    pixeltype::GLenum
    internalformat::GLenum
    format::GLenum
    size::Vector{Int}
end
=#
include("GLTexture.jl")
########################################################################


type GLBuffer{T, Cardinality} #<: DenseArray{T, 1}
    
    id::GLuint
    length::Int
    buffertype::GLenum
    usage::GLenum

    function GLBuffer(ptr::Ptr{T}, buffsize::Int, buffertype::GLenum, usage::GLenum)
        @assert buffsize % sizeof(T) == 0
        len = div(buffsize, sizeof(T))
        @assert len % Cardinality == 0
        len = div(len, Cardinality)

        id = glGenBuffers()
        glBindBuffer(buffertype, id)
        glBufferData(buffertype, buffsize, ptr, usage)
        glBindBuffer(buffertype, 0)

        obj = new(id, len, buffertype, usage)
        finalizer(obj, delete!)
        obj
    end
end

include("GLBuffer.jl")

type GLVertexArray
  program::GLProgram
  id::GLuint
  length::Int
  indexlength::Int # is negative if not indexed

  function GLVertexArray(bufferDict::Dict{Symbol, GLBuffer}, program::GLProgram)
    #get the size of the first array, to assert later, that all have the same size
    indexSize = -1
    len = -1
    id = glGenVertexArrays()
    glBindVertexArray(id)
    for (name, buffer) in bufferDict

      if buffer.buffertype == GL_ELEMENT_ARRAY_BUFFER
        glBindBuffer(buffer.buffertype, buffer.id)
        indexSize = buffer.length * cardinality(buffer)
      else
        attribute   = string(name)
        if len == -1 
            len = length(buffer)
        end
        if len != length(buffer)
            error("buffer $attribute has not the same length as the other buffers. Has: $(buffer.length). Should have: $len")
        end
        glBindBuffer(buffer.buffertype, buffer.id)
        attribLocation = get_attribute_location(program.id, attribute)
        glVertexAttribPointer(attribLocation, cardinality(buffer), glpixelformat(eltype(buffer)), GL_FALSE, 0, C_NULL)
        glEnableVertexAttribArray(attribLocation)
      end
    end
    glBindVertexArray(0)
    obj = new(program, id, len, indexSize)
    finalizer(obj, delete!)
    obj
  end
end
GLVertexArray(bufferDict::Dict{ASCIIString, GLBuffer}, program::GLProgram) = GLVertexArray(mapkeys(symbol, bufferdict), program)

function Base.delete!(x::GLVertexArray)
    glDeleteVertexArrays(1, [x.id])
end


##################################################################################

type RenderObject
    uniforms::Dict{Symbol, Any}
    alluniforms::Dict{Symbol, Any}
    vertexarray::GLVertexArray
    prerenderfunctions::Dict{Function, Tuple}
    postrenderfunctions::Dict{Function, Tuple}
    id::GLushort
    boundingbox::Function # workaround for having lazy boundingbox queries, while not using multiple dispatch for boundingbox function (No type hierarchy for RenderObjects)

    objectid = GLushort(0)

    function RenderObject(data::Dict{Symbol, Any}, program::Signal{GLProgram}, bbf::Function=(x)->error("boundingbox not implemented"))
        objectid             += GLushort(1)
        program              = program.value
        buffers              = filter((key, value) -> isa(value, GLBuffer), data)
        uniforms             = filter((key, value) -> !isa(value, GLBuffer), data)
        uniforms[:objectid]  = objectid # automatucally integrate object ID, will be discarded if shader doesn't use it
        
        vertexarray          = GLVertexArray(Dict{Symbol, GLBuffer}(buffers), program)
        
        uniformtypesandnames = uniform_name_type(program.id) # get active uniforms and types from program
        optimizeduniforms    = Dict{Symbol, Any}()

        for (uniform_name, typ) in uniformtypesandnames
            if haskey(uniforms, uniform_name)
                 optimizeduniforms[uniform_name] = uniforms[uniform_name]
            end
        end # only use active uniforms && check the type
        return new(optimizeduniforms, uniforms, vertexarray, Dict{Function, Tuple}(), Dict{Function, Tuple}(), objectid, bbf)
    end
end
include("GLRenderObject.jl")




####################################################################################
