#the idea of a pipeline together with renderpasses is that one can jus throw in a scene 
#and the render functions take care of what renderables get drawn by what passes
struct Pipeline
    name::Symbol
    passes::Vector{RenderPass}
    context::Context
end

Pipeline(name::Symbol, rps::Vector{RenderPass}) = Pipeline(name, rps, current_context())

function render(pipe::Pipeline, args...)
    for pass in pipe.renderpasses
        start(pass)
        pass.render(args...)
    end
    stop(pipe.renderpasses[end])
end