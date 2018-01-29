
#Do we really need the context if it is already in frambuffer and program?
struct RenderPass
    # id::Int
    name::Symbol
    program::Program
    target::FrameBuffer
    render::Function
end

function RenderPass(name::Symbol, shaders::Vector{Tuple{Symbol, AbstractString}}, render_func::Function)
    pass_shaders = Shader[]
    for (name, source) in shaders
        push!(pass_shaders, Shader(name, shadertype(name), Vector{UInt8}(source)))
    end

    prog   = Program(pass_shaders, Tuple{Int, String}[])
    target = contextfbo()
    return RenderPass(name, prog, target, render_func)
end

render(rp::RenderPass, args...) = rp.render(args...)


