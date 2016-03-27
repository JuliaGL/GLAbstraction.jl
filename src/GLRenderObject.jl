RenderObject(data::Dict{Symbol}, program, bbs=Signal(AABB{Float32}(Vec3f0(0),Vec3f0(1))), main=nothing) = RenderObject(convert(Dict{Symbol,Any}, data), program, bbs, main)

function Base.show(io::IO, obj::RenderObject)
    println(io, "RenderObject with ID: ", obj.id)

    println(io, "uniforms: ")
    for (name, uniform) in obj.uniforms
        println(io, "   ", name, "\n      ", uniform)
    end
    println(io, "vertexarray length: ", length(obj.vertexarray))
    println(io, "vertexarray indexlength: ", obj.vertexarray.indices)
end



Base.getindex(obj::RenderObject, symbol::Symbol)         = obj.uniforms[symbol]
Base.setindex!(obj::RenderObject, value, symbol::Symbol) = obj.uniforms[symbol] = value

Base.getindex(obj::RenderObject, symbol::Symbol, x::Function)     = getindex(obj, Val{symbol}(), x)
Base.getindex(obj::RenderObject, ::Val{:prerender}, x::Function)  = obj.prerenderfunctions[x]
Base.getindex(obj::RenderObject, ::Val{:postrender}, x::Function) = obj.postrenderfunctions[x]

Base.setindex!(obj::RenderObject, value, symbol::Symbol, x::Function)     = setindex!(obj, value, Val{symbol}(), x)
Base.setindex!(obj::RenderObject, value, ::Val{:prerender}, x::Function)  = obj.prerenderfunctions[x] = value
Base.setindex!(obj::RenderObject, value, ::Val{:postrender}, x::Function) = obj.postrenderfunctions[x] = value


"""
Represents standard sets of function applied before rendering
"""
immutable StandardPrerender
end

function call(::StandardPrerender)
    glEnable(GL_DEPTH_TEST)
    glDepthMask(GL_TRUE)
    glDepthFunc(GL_LEQUAL)
    glDisable(GL_STENCIL_TEST)
    glStencilMask(0xff)
    glDisable(GL_CULL_FACE)
    enabletransparency()
end
immutable StandardPostrender
    vao::VertexArray
    primitive::GLenum
end
function call(sp::StandardPostrender)
    render(sp.vao, sp.primitive)
end
immutable StandardPostrenderInstanced{T}
    main::T
    vao::VertexArray
    primitive::GLenum
end
function call(sp::StandardPostrenderInstanced)
    renderinstanced(sp.vao, value(sp.main), sp.primitive)
end

function instanced_renderobject(data, program, bb=Signal(AABB(Vec3f0(0), Vec3f0(1))), primitive::GLenum=GL_TRIANGLES, main=nothing)
    robj = RenderObject(data, program, bb, main)
    robj.prerenderfunction = StandardPrerender()
    robj.postrenderfunction = StandardPostrenderInstanced(main, bj.vertexarray, primitive)
    robj
end

function std_renderobject(data, shader, bb=Signal(AABB(Vec3f0(0), Vec3f0(1))), primitive=GL_TRIANGLES, main=nothing)
    robj = RenderObject(data, shader, bb, main)
    robj.prerenderfunction = StandardPrerender()
    robj.postrenderfunction = StandardPostrender(bj.vertexarray, primitive)
    robj
end


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


"""
Copy function for a context. We only need to copy the children
"""
function Base.copy{T}(c::GLAbstraction.Context{T})
    new_children = [copy(child) for child in c.children]
    Context{T}(new_children, c.boundingbox, c.transformation)
end


"""
Copy function for a RenderObject. We only copy the uniform dict
"""
function Base.copy(robj::GLAbstraction.RenderObject)
    uniforms = Dict{Symbol, Any}([k=>v for (k,v) in robj.uniforms])
    robj = RenderObject(
        robj.main,
        uniforms,
        robj.vertexarray,
        robj.prerenderfunctions,
        robj.postrenderfunctions,
        robj.boundingbox,
    )
    Context(robj)
end

"""
If you have an array of OptimizedPrograms, you only need to put PreRender in front.
"""
type OptimizedProgram{PreRender}
    program::GLProgram
    uniforms::FixedDict
    vertexarray::GLVertexArray
    gl_parameters::PreRender
    renderfunc::Callable
    visible::Boolean
end
