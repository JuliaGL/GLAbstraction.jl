struct Context
    context
    threadid::Int
    queue::Vector{Function} # Closures to be executed when the context becomes current again
end

Context(x=nothing) = Context(x, threadid(), Function[])

Base.push!(c::Context, f::Function) = push!(c.queue, f)

const GLOBAL_CONTEXT = Base.RefValue{Context}(Context())
const GLOBAL_CONTEXTS = Dict{Any, Context}()

current_context() = GLOBAL_CONTEXT[]
is_current_context(x::Context) = x == GLOBAL_CONTEXT[]
is_current_context(x) = x == GLOBAL_CONTEXT[].context
clear_context!() = GLOBAL_CONTEXT[] = Context()

function set_context!(x)
    if haskey(GLOBAL_CONTEXTS, x)
        c = GLOBAL_CONTEXTS[x]
        GLOBAL_CONTEXT[] = c 
        for f in c.queue
            @tspawnat c.threadid f()
        end
    else
        c = Context(x)
        GLOBAL_CONTEXTS[x] = c
        GLOBAL_CONTEXT[] = c
    end
end

function exists_context()
    if current_context().context === nothing
        @error "Couldn't find valid OpenGL Context. OpenGL Context active?"
    end
end

function context_command(c::Context, f::Function)
    if !is_current_context(c)
        push!(c, f)
    else
        f()
    end
end
