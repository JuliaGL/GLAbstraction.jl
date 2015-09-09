RenderObject{T}(data::Dict{Symbol, T}, program::GLProgram) = RenderObject(Dict{Symbol, Any}(data), Input(program))


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


function instanced_renderobject(data, program::Signal{GLProgram}, bb=Input(AABB(Vec3f0(0), Vec3f0(1))), primitive::GLenum=GL_TRIANGLES, main=nothing)
    robj = RenderObject(data, program, bb, main)
    prerender!(robj,
        glEnable, GL_DEPTH_TEST,
        glDepthMask, GL_TRUE,
        glDepthFunc, GL_LEQUAL,
        glDisable, GL_CULL_FACE,
        enabletransparency)
    postrender!(robj,
        renderinstanced, robj.vertexarray, value(main), primitive)
    robj
end


function std_renderobject(data, shader::Signal{GLProgram}, bb=Input(AABB(Vec3f0(0), Vec3f0(1))), primitive=GL_TRIANGLES, main=nothing)
    robj = RenderObject(data, shader, bb, main)
    prerender!(robj,
        glEnable, GL_DEPTH_TEST,
        glDepthMask, GL_TRUE,
        glDepthFunc, GL_LEQUAL,
        glDisable, GL_CULL_FACE,
        enabletransparency)
    postrender!(robj,
        render, robj.vertexarray, primitive)
    robj
end
pushfunction(fs...) = pushfunction!(Dict{Function, Tuple}(), fs...)

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

extract_renderable(context::Vector{RenderObject}) = context
extract_renderable(context::RenderObject) = [context]
extract_renderable{T <: Composable}(context::Vector{T}) = map(extract_renderable, context)
function extract_renderable(context::Context)
    result = extract_renderable(context.children[1])
    for elem in context.children[2:end]
        push!(result, extract_renderable(elem)...)
    end
    result
end
transformation(c::RenderObject) = c[:model]
transformation(c::RenderObject, model) = (c[:model] = const_lift(*, model, c[:model]))
