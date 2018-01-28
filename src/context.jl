
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
const context = Base.RefValue{Context}(Context(:none))

function current_context()
    context[]
end
function is_current_context(x)
    x == context[]
end
function clear_context!()
    context[] = Context(:none)
end
#this should remain here, maybe, it uses a glframebuffer
# mutable struct Context <: AbstractContext
#     context
# end
function set_context!(x)
    context[] = x
end

function exists_context()
    if current_context().id == :none
        error("Couldn't find valid OpenGL Context. OpenGL Context active?")
    end
end