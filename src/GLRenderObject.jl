RenderObject{T}(data::Dict{Symbol, T}, program::GLProgram) = RenderObject(Dict{Symbol, Any}(data), program)


function Base.show(io::IO, obj::RenderObject)
    println(io, "RenderObject with ID: ", obj.id)

    println(io, "uniforms: ")
    for (name, uniform) in obj.uniforms
        println(io, "   ", name, "\n      ", uniform)
    end
    println(io, "vertexarray length: ", obj.vertexarray.length)
    println(io, "vertexarray indexlength: ", obj.vertexarray.indexlength)
end



Base.getindex(obj::RenderObject, symbol::Symbol)         = obj.uniforms[symbol]
Base.setindex!(obj::RenderObject, value, symbol::Symbol) = obj.uniforms[symbol] = value

Base.getindex(obj::RenderObject, symbol::Symbol, x::Function)       = getindex(obj, Val{symbol}(), x)
Base.getindex(obj::RenderObject, ::Val{:prerender}, x::Function)    = obj.prerenderfunctions[x]
Base.getindex(obj::RenderObject, ::Val{:postrender}, x::Function)   = obj.postrenderfunctions[x]

Base.setindex!(obj::RenderObject, value, symbol::Symbol, x::Function)       = setindex!(obj, value, Val{symbol}(), x)
Base.setindex!(obj::RenderObject, value, ::Val{:prerender}, x::Function)    = obj.prerenderfunctions[x] = value
Base.setindex!(obj::RenderObject, value, ::Val{:postrender}, x::Function)   = obj.postrenderfunctions[x] = value

function instancedobject(data, amount::Integer, program::Signal{GLProgram}, primitive::GLenum=GL_TRIANGLES, bbf::Function=(x)->error("boundingbox not implemented"))
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
