RenderObject(data::Dict{Symbol}, program, bbs=Signal(AABB{Float32}(Vec3f0(0),Vec3f0(1))), main=nothing) = RenderObject(convert(Dict{Symbol,Any}, data), program, bbs, main)

function Base.show(io::IO, obj::RenderObject)
    println(io, "RenderObject with ID: ", obj.id)
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
Function which sets an argument of a Context/RenderObject.
If multiple RenderObjects are supplied, it'll try to set the same argument in all
of them.
"""
function set_arg!(robj::RenderObject, sym, value)
    current_val = robj[sym]
    set_arg!(robj, sym, current_val, value)
    # GLVisualize relies on reactives event system no for rendering
    # so if a change should be visible there must be an event to indicate change
    Reactive.post_empty()
    nothing
end
function set_arg!(robj::Context, sym, value)
    set_arg!(robj.children, sym, value)
    nothing
end
function set_arg!(robj::Vector, sym, value)
    for elem in robj
        set_arg!(elem, sym, value)
    end
    nothing
end

function set_arg!(robj::RenderObject, sym, to_update::GPUArray, value)
    update!(to_update, value)
end
function set_arg!(robj::RenderObject, sym, to_update, value)
    robj[sym] = value
end
function set_arg!(robj::RenderObject, sym, to_update::Signal, value::Signal)
    robj[sym] = value
end
function set_arg!(robj::RenderObject, sym, to_update::Signal, value)
    push!(to_update, value)
end


"""
Represents standard sets of function applied before rendering
"""
immutable StandardPrerender
end

@compat function (::StandardPrerender)()
    glEnable(GL_DEPTH_TEST)
    glDepthMask(GL_TRUE)
    glDepthFunc(GL_LEQUAL)
    glDisable(GL_CULL_FACE)
    enabletransparency()
end
immutable StandardPostrender
    vao::GLVertexArray
    primitive::GLenum
end
@compat function (sp::StandardPostrender)()
    render(sp.vao, sp.primitive)
end
immutable StandardPostrenderInstanced{T}
    main::T
    vao::GLVertexArray
    primitive::GLenum
end
@compat function (sp::StandardPostrenderInstanced)()
    renderinstanced(sp.vao, value(sp.main), sp.primitive)
end

immutable EmptyPrerender
end
@compat function (sp::EmptyPrerender)()
end
export EmptyPrerender
export prerendertype

function instanced_renderobject(data, program, bb = Signal(AABB(Vec3f0(0), Vec3f0(1))), primitive::GLenum=GL_TRIANGLES, main=nothing)
    pre = StandardPrerender()
    robj = RenderObject(data, program, pre, nothing, bb, main)
    robj.postrenderfunction = StandardPostrenderInstanced(main, robj.vertexarray, primitive)
    robj
end

function std_renderobject(data, program, bb = Signal(AABB(Vec3f0(0), Vec3f0(1))), primitive=GL_TRIANGLES, main=nothing)
    pre = StandardPrerender()
    robj = RenderObject(data, program, pre, nothing, bb, main)
    robj.postrenderfunction = StandardPostrender(robj.vertexarray, primitive)
    robj
end

prerendertype{Pre}(::Type{RenderObject{Pre}}) = Pre
prerendertype{Pre}(::RenderObject{Pre}) = Pre

extract_renderable(context::Vector{RenderObject}) = context
extract_renderable(context::RenderObject) = RenderObject[context]
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
transform!(c::RenderObject, model) = (c[:model] = const_lift(*, model, c[:model]))

function _translate!(c::RenderObject, trans::TOrSignal{Mat4f0})
    c[:model] = const_lift(*, trans, c[:model])
end
function _translate!(c::Context, m::TOrSignal{Mat4f0})
    for elem in c.children
        _translate!(elem, m)
    end
end

function translate!{T<:Vec{3}}(c::Composable, vec::TOrSignal{T})
     _translate!(c, const_lift(translationmatrix, vec))
end
function _boundingbox(c::RenderObject)
    bb = value(c[:boundingbox])
    bb == nothing && return AABB(Vec3f0(0), Vec3f0(0))
    value(c[:model]) * bb
end
function _boundingbox(c::Composable)
    robjs = extract_renderable(c)
    isempty(robjs) && return AABB(Vec3f0(NaN), Vec3f0(0))
    mapreduce(_boundingbox, union, robjs)
end
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
function Base.copy{Pre}(robj::RenderObject{Pre})
    uniforms = Dict{Symbol, Any}([(k,v) for (k,v) in robj.uniforms])
    robj = RenderObject{Pre}(
        robj.main,
        uniforms,
        robj.vertexarray,
        robj.prerenderfunction,
        robj.postrenderfunction,
        robj.boundingbox,
    )
    Context(robj)
end

# """
# If you have an array of OptimizedPrograms, you only need to put PreRender in front.
# """
# type OptimizedProgram{PreRender}
#     program::GLProgram
#     uniforms::FixedDict
#     vertexarray::GLVertexArray
#     gl_parameters::PreRender
#     renderfunc::Callable
#     visible::Boolean
# end
