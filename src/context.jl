
#Context and current_context should be overloaded by users of the library! They are standard Symbols
abstract type AbstractContext end

struct Context <: AbstractContext
    id::Symbol
end
#=
We need to track the current OpenGL context.
Since we can't do this via pointer identity  (OpenGL may reuse the same pointers)
We go for this slightly ugly version.
In the future, this should probably be part of GLWindow.
=#
const GLOBAL_CONTEXT = Base.RefValue{AbstractContext}(Context(:none))

function current_context()
    GLOBAL_CONTEXT[]
end
function is_current_context(x)
    x == GLOBAL_CONTEXT[]
end
function clear_context!()
    GLOBAL_CONTEXT[] = Context(:none)
end
#this should remain here, maybe, it uses a glframebuffer
# mutable struct Context <: AbstractContext
#     context
# end
function set_context!(x)
    GLOBAL_CONTEXT[] = x
end

function exists_context()
    if current_context().id == :none
        @error "Couldn't find valid OpenGL Context. OpenGL Context active?"
    end
end

#These have to get overloaded for the pipeline to work!
swapbuffers(c::AbstractContext) = return
clear!(c::AbstractContext) = return
