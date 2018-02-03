#the idea of a pipeline together with renderpasses is that one can jus throw in a scene
#and the render functions take care of what renderables get drawn by what passes
struct Pipeline{Name}
    name::Symbol
    passes::Vector{RenderPass}
    context::AbstractContext
end
Pipeline(name::Symbol, rps::Vector{<:RenderPass}, context=current_context()) = Pipeline{name}(name, rps, context)

function render(pipe::Pipeline, args...)
    start(pipe)
    for pass in pipe.passes
        start(pass)
        pass(args...)
    end
    stop(pipe.passes[end])
end

function free!(pipe::Pipeline)
    if !is_current_context(pipe.context)
        return pipe
    end
    for pass in pipe.passes
        free!(pass)
    end
    return
end
#overload!
start(pipe::Pipeline) = return
