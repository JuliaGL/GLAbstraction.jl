
#Do we really need the context if it is already in frambuffer and program?
struct RenderPass{Name}
    # id::Int
    name::Symbol
    program::Program
    target::FrameBuffer
    # render::Function
end
"RednerPass that renders directly to the current context."
function RenderPass(name::Symbol, shaders::Vector{Shader})
    prog   = Program(shaders, Tuple{Int, String}[])
    target = contextfbo()
    return RenderPass{name}(name, prog, target)
end
function RenderPass(name::Symbol, shaders::Vector{Tuple{Symbol, AbstractString}})
    pass_shaders = Shader[]
    for (shname, source) in shaders
        push!(pass_shaders, Shader(shname, shadertype(shname), Vector{UInt8}(source)))
    end
    return RenderPass(name, shaders)
end
function RenderPass(name::Symbol, shaders::Vector{Tuple{String, UInt32}})
    pass_shaders = Shader[]
    for (source, typ) in shaders
        push!(pass_shaders, Shader(gensym(), typ, Vector{UInt8}(source)))
    end

    prog   = Program(pass_shaders, Tuple{Int, String}[])
    target = contextfbo()
    return RenderPass{name}(name, prog, target)
end

function start(rp::RenderPass)
    Base.bind(rp.target)
    # clear!(rp.target)
    Base.bind(rp.program)
end

function stop(rp::RenderPass)
    unbind(rp.target)
    unbind(rp.program)
end
# render(rp::RenderPass, args...) = rp.render(args...)


function free!(rp::RenderPass)
    free!(rp.program)
    free!(rp.target)
    return
end
