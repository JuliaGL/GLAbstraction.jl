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
    vertpath::String
    fragpath::String
    nametype::Dict{Symbol, GLenum}
    uniformloc::Dict{Symbol, Tuple}
    function GLProgram(id::GLuint, vertpath::String, fragpath::String, nametype::Dict{Symbol, GLenum}, uniformloc::Dict{Symbol, Tuple})
        obj = new(id, vertpath, fragpath, nametype, uniformloc)
    end
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
immutable Texture{T <: TEXTURE_COMPATIBLE_NUMBER_TYPES, ColorDIM, NDIM}
    id::GLuint
    pixeltype::GLenum
    internalformat::GLenum
    format::GLenum
    dims::Vector{Int}
end
=#
include("GLTexture.jl")
########################################################################

opengl_compatible{C <: AbstractAlphaColorValue}(T::Type{C}) = eltype(T), 4
opengl_compatible{C <: RGB4}(T::Type{C})                    = eltype(T), 4

opengl_compatible{C <: ColorValue}(T::Type{C})              = eltype(T), 3
opengl_compatible{C <: AbstractGray}(T::Type{C})            = eltype(T), 1

function opengl_compatible(T::DataType)
    if T <: Number
        return T, 1
    end
    if !isbits(T)
        error("only pointer free, immutable types are supported for upload to OpenGL. Found type: $(T)")
    end
    elemtype = T.types[1]
    if !(elemtype <: Real)
        error("only real numbers are allowed as element types for upload to OpenGL. Found type: $(T) with $(ptrtype)")
    end
    if !all(x -> x == elemtype , T.types)
        error("all values in $(T) need to have the same type to create a GLBuffer")
    end
    cardinality = length(names(T))
    if cardinality > 4
        error("there should be at most 4 values in $(T) to create a GLBuffer")
    end
    elemtype, cardinality
end

type GLBuffer{T <: Real, Cardinality}
    id::GLuint
    length::Int
    buffertype::GLenum
    usage::GLenum

    function GLBuffer(ptr::Ptr{T}, size::Int, buffertype::GLenum, usage::GLenum)
        @assert size % sizeof(T) == 0
        _length = div(size, sizeof(T))
        @assert _length % Cardinality == 0
        _length = div(_length, Cardinality)

        id = glGenBuffers()
        glBindBuffer(buffertype, id)
        glBufferData(buffertype, size, ptr, usage)
        glBindBuffer(buffertype, 0)

        obj = new(id, _length, buffertype, usage)
    end
end
include("GLBuffer.jl")

type GLVertexArray
  program::GLProgram
  id::GLuint
  length::Int
  indexlength::Int # is negative if not indexed

  function GLVertexArray(bufferDict::Dict{Symbol, GLBuffer}, program::GLProgram)
    @assert !isempty(bufferDict)
    debugFlagOn && debugGLVertexAConstruct(bufferDict, program)

    #get the size of the first array, to assert later, that all have the same size
    indexSize = -1
    _length = -1
    id = glGenVertexArrays()
    glBindVertexArray(id)
    for (name, value) in bufferDict
      buffer      = value
      if buffer.buffertype == GL_ELEMENT_ARRAY_BUFFER
        glBindBuffer(buffer.buffertype, buffer.id)
        indexSize = buffer.length * cardinality(buffer)
      else
        attribute   = string(name)
        if _length == -1 
            _length = length(buffer)
        end
        if _length != length(buffer)
            error("buffer $attribute has not the same length as the other buffers. Has: $(buffer.length). Should have: $_length")
        end
        glBindBuffer(buffer.buffertype, buffer.id)
        attribLocation = get_attribute_location(program.id, attribute)

        glVertexAttribPointer(attribLocation,  cardinality(buffer), GL_FLOAT, GL_FALSE, 0, C_NULL)
        glEnableVertexAttribArray(attribLocation)
      end
    end
    glBindVertexArray(0)
    new(program, id, _length, indexSize)
  end
end
function GLVertexArray(bufferDict::Dict{ASCIIString, GLBuffer}, program::GLProgram)
    GLVertexArray(Dict{Symbol, GLBuffer}(map(elem -> (symbol(elem[1]), elem[2]), bufferDict)), program)
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

    objectid::GLushort = 0

    function RenderObject(data::Dict{Symbol, Any}, program::GLProgram, bbf::Function=(x)->error("boundingbox not implemented"))
        objectid::GLushort += 1

        buffers     = filter((key, value) -> isa(value, GLBuffer), data)
        uniforms    = filter((key, value) -> !isa(value, GLBuffer), data)
        uniforms[:objectid] = objectid # automatucally integrate object ID, will be discarded if shader doesn't use it
        
        if length(buffers) > 0
            vertexarray = GLVertexArray(Dict{Symbol, GLBuffer}(buffers), program)
        else
            error("no buffers supplied")
        end
        uniformtypesandnames = uniform_name_type(program.id) # get active uniforms and types from program
        optimizeduniforms = Dict{Symbol, Any}()
        for (uniform_name, typ) in uniformtypesandnames
            if haskey(uniforms, uniform_name)
                 optimizeduniforms[uniform_name] = uniforms[uniform_name]
            end
        end # only use active uniforms && check the type
        new(optimizeduniforms, uniforms, vertexarray, Dict{Function, Tuple}(), Dict{Function, Tuple}(), objectid, bbf)
    end
end
function Base.show(io::IO, obj::RenderObject)
    println(io, "RenderObject with ID: ", obj.id)

    println(io, "uniforms: ")
    for (name, uniform) in obj.uniforms
        println(io, "   ", name, "\n      ", uniform)
    end
    println(io, "vertexarray length: ", obj.vertexarray.length)
    println(io, "vertexarray indexlength: ", obj.vertexarray.indexlength)    
end
RenderObject{T}(data::Dict{Symbol, T}, program::GLProgram) = RenderObject(Dict{Symbol, Any}(data), program)

immutable Field{Symbol}
end

Base.getindex(obj::RenderObject, symbol::Symbol) = obj.uniforms[symbol]
Base.setindex!(obj::RenderObject, value, symbol::Symbol) = obj.uniforms[symbol] = value

Base.getindex(obj::RenderObject, symbol::Symbol, x::Function) = getindex(obj, Field{symbol}(), x)
Base.getindex(obj::RenderObject, ::Field{:prerender}, x::Function) = obj.prerenderfunctions[x]
Base.getindex(obj::RenderObject, ::Field{:postrender}, x::Function) = obj.postrenderfunctions[x]

Base.setindex!(obj::RenderObject, value, symbol::Symbol, x::Function) = setindex!(obj, value, Field{symbol}(), x)
Base.setindex!(obj::RenderObject, value, ::Field{:prerender}, x::Function) = obj.prerenderfunctions[x] = value
Base.setindex!(obj::RenderObject, value, ::Field{:postrender}, x::Function) = obj.postrenderfunctions[x] = value

function instancedobject(data, amount::Integer, program::GLProgram, primitive::GLenum=GL_TRIANGLES, bbf::Function=(x)->error("boundingbox not implemented"))
    obj = RenderObject(data, program, bbf)
    postrender!(obj, renderinstanced, obj.vertexarray, amount, primitive)
    obj
end

function pushfunction!(target::Dict{Function, Tuple}, fs...)
    func = fs[1]
    args = Any[]
    for i=2:length(fs)
        elem = fs[i]
        if isa(elem, Function)
            target[func] = tuple(args...)
            func = elem
            args = Any[]
        else
            push!(args, elem)
        end
    end
    target[func] = tuple(args...)
end
prerender!(x::RenderObject, fs...)   = pushfunction!(x.prerenderfunctions, fs...)
postrender!(x::RenderObject, fs...)  = pushfunction!(x.postrenderfunctions, fs...)

function Base.delete!(x::Any)
    x = 0
end
function Base.delete!(x::Dict)
    for (k,v) in x
        if !contains(string(k), "dontdelete")
            delete!(v)
            delete!(x, k)
        end
    end
end
function Base.delete!(x::Array)
    while !isempty(x)
        elem = pop!(x)
        delete!(elem)
    end
end
function Base.delete!(x::GLProgram)
    glDeleteProgram(x.id)
end
function Base.delete!(x::GLBuffer)
    glDeleteBuffers(1, [x.id])
end
function Base.delete!(x::Texture)
    glDeleteTextures(1, [x.id])
end
function Base.delete!(x::GLVertexArray)
    glDeleteVertexArrays(1, [x.id])
end
function Base.delete!(x::RenderObject)
    delete!(x.uniforms)
    delete!(x.vertexarray)
end



####################################################################################

#=
Style Type, which is used to choose different visualization/editing styles via multiple dispatch
Usage pattern:
visualize(::Style{:Default}, ...)           = do something
visualize(::Style{:MyAwesomeNewStyle}, ...) = do something different
=#
immutable Style{StyleValue}
end
Style(x::Symbol) = Style{x}()
Style() = Style{:Default}()
mergedefault!{S}(style::Style{S}, styles, customdata) = merge!(copy(styles[S]), Dict{Symbol, Any}(customdata))


#==
   Debugging, see conventions in GLRender.jl
==#

function    debugGLVertexAConstruct(bufferDict::Dict{Symbol, GLBuffer},
                                    program::GLProgram)
    debugLevel & 16 == 0 && return
    id = program.id
    println("In debugGLVertexAConstruct program.id=$id")
    map (bufferDict)   do kv
        k=kv[1]
        v=kv[2]
        println("\tkey=$k\tvalue type:", typeof(v))
    end
   if debugLevel & 1
       println("Traceback for debugGLVertexAConstruct")
       Base.show_backtrace(STDOUT, backtrace())
   end
end
