#the idea of a pipeline together with renderpasses is that one can jus throw in a scene
#and the render functions take care of what renderables get drawn by what passes
struct Pipeline
    name::Symbol
    passes::Vector{RenderPass}
    context::AbstractContext
end

Pipeline(name::Symbol, rps::Vector{RenderPass}) = Pipeline(name, rps, current_context())

function render(pipe::Pipeline, args...)
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
