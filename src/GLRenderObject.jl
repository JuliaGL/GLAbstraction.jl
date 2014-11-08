
macro inject(x::Symbol)
    t = eval(x)
    @assert isa(t, DataType)
    returnValue = Expr[]
    for i =1:length(t.types)
        push!(returnValue, Expr(:(::), t.names[i], t.types[i].name.name))
    end
    esc((Expr(:block, returnValue...)))
end

abstract RenderObject{Dimensionality}

immutable CommonRenderObjectAttributes
    uniforms::Dict{Symbol, Any}
    vertexarray::GLVertexArray
    prerenderfunctions::Dict{Function, Tuple}
    postrenderfunctions::Dict{Function, Tuple}
    id::GLushort
end

type Instanced{PrimitiveDimensionality} <: RenderObject{3}
    primitive::Mesh{PrimitiveDimensionality}
    instances::Int
end
type Mesh{Dimensionality} <: RenderObject{Dimensionality}
    primitive::CommonRenderObjectAttributes
    instances::Int
end
immutable Text{Dimensionality} <: RenderObject{Dimensionality}
    @inject CommonRenderObjectAttributes
end
immutable Volume <: RenderObject{3}
    @inject CommonRenderObjectAttributes
end

begin
local NEXT_RENDER_OBJECT_ID = zero(GLushorts)
function RenderObject(data::Dict{Symbol, Any}, program::GLProgram; editables=Dict{Symbol,Input}())
    NEXT_RENDER_OBJECT_ID::GLushort += 1

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
    optimizeduniforms = map(uniformtypesandnames) do elem
        name = elem[1]
        typ = elem[2]
        if !haskey(uniforms, name)
            error("not sufficient uniforms supplied. Missing: ", name, " type: ", GLENUM(typ).name)
        end
        value = uniforms[name]
        if !is_correct_uniform_type(value, GLENUM(typ))
            error("Uniform ", name, " not of correct type. Expected: ", GLENUM(typ).name, ". Got: ", typeof(value))
        end
        if isa(value, Input)
            editables[name] = value
        end
        (name, value)
    end # only use active uniforms && check the type

    new(Dict{Symbol, Any}(optimizeduniforms), uniforms, vertexArray, Dict{Function, Tuple}(), Dict{Function, Tuple}(), objectid)
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


function instancedobject(data, program::GLProgram, amount::Integer, primitive::GLenum=GL_TRIANGLES)
    obj = RenderObject(data, program)
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