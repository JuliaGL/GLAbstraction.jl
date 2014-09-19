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
export Circle, Rectangle, Shape
############################################################################

immutable GLProgram
    id::GLuint
    vertpath::String
    fragpath::String
    nametype::Dict{Symbol, GLenum}
    uniformloc::Dict{Symbol, Tuple}
end

export GLProgram

########################################################################################
#12 seconds loading are wasted here

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

immutable GLBuffer{T <: Real, Cardinality}
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

        new(id, _length, buffertype, usage)
    end
end
include("GLBuffer.jl")

immutable GLVertexArray
  program::GLProgram
  id::GLuint
  length::Int
  indexlength::Int # is negative if not indexed

  function GLVertexArray(bufferDict::Dict{Symbol, GLBuffer}, program::GLProgram)
    @assert !isempty(bufferDict)
    #get the size of the first array, to assert later, that all have the same size
    indexSize = -1
    _length = get(bufferDict, collect(keys(bufferDict))[1], 0).length
    id = glGenVertexArrays()
    glBindVertexArray(id)
    for elem in bufferDict
      buffer      = elem[2]
      if buffer.buffertype == GL_ELEMENT_ARRAY_BUFFER
        glBindBuffer(buffer.buffertype, buffer.id)
        indexSize = buffer.length * cardinality(buffer)
      else
        attribute   = string(elem[1])
        @assert _length == buffer.length
        glBindBuffer(buffer.buffertype, buffer.id)
        attribLocation = get_attribute_location(program.id, attribute)

        glVertexAttribPointer(attribLocation,  cardinality(buffer), GL_FLOAT, GL_FALSE, 0, 0)
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
export GLVertexArray, GLBuffer, indexbuffer, opengl_compatible, cardinality

##################################################################################
immutable RenderObject
    uniforms::Dict{Symbol, Any}
    vertexarray::GLVertexArray
    prerenderfunctions::Dict{Function, Tuple}
    postrenderfunctions::Dict{Function, Tuple}
    id::GLushort
    #editables::Dict{Symbol, Input}

    objectid::GLushort = 0

    function RenderObject(data::Dict{Symbol, Any}, program::GLProgram; editables=(Symbol=>Input)[])
        objectid::GLushort += 1

        buffers     = filter((key, value) -> isa(value, GLBuffer), data)
        uniforms    = filter((key, value) -> !isa(value, GLBuffer), data)
        
        uniforms[:objectid] = objectid # automatucally integrate object ID, will be discarded if shader doesn't use it
        
        if length(buffers) > 0
            vertexArray = GLVertexArray(Dict{Symbol, GLBuffer}(buffers), program)
        else
            vertexarray
        end
        textureTarget::GLint = -1
        uniformtypesandnames = uniform_name_type(program.id) # get active uniforms and types from program
        optimizeduniforms = map(elem -> begin
            name = elem[1]
            typ = elem[2]
            if !haskey(uniforms, name)
                error("not sufficient uniforms supplied. Missing: ", name, " type: ", uniform_type(typ))
            end
            value = uniforms[name]
            if !is_correct_uniform_type(typ, value)
                error("Uniform ", name, " not of correct type. Expected: ", uniform_type(typ), ". Got: ", typeof(value))
            end
            if isa(value, Input)
                editables[name] = value
            end
            (name, value)
        end, uniformtypesandnames) # only use active uniforms && check the type

        new(Dict{Symbol, Any}(optimizeduniforms), vertexArray, (Function => Tuple)[], (Function => Tuple)[], objectid)
    end
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


function instancedobject(data, program::GLProgram, amount::Integer, primitive::GLenum=GL_TRIANGLES)
    obj = RenderObject(data, program)
    postrender!(obj, renderinstanced, obj.vertexarray, amount, primitive)
    obj
end

function pushfunction!(target::Dict{Function, Tuple}, fs...)
    func = fs[1]
    args = {}
    for i=2:length(fs)
        elem = fs[i]
        if isa(elem, Function)
            target[func] = tuple(args...)
            func = elem
            args = {}
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
        delete!(v)
        delete!(x, k)
    end
end
function Base.delete!(x::Array)
    while !isempty(x)
        elem = pop!(x)
        delete!(elem)
    end
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
    x = 0
end
export RenderObject, prerender!, postrender!, instancedobject
####################################################################################



