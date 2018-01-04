const Context = Symbol

#=
We need to track the current OpenGL context.
Since we can't do this via pointer identity  (OpenGL may reuse the same pointers)
We go for this slightly ugly version.
In the future, this should probably be part of GLWindow.
=#
const context = Base.RefValue{Context}(:none)

function current_context()
    context[]
end
function is_current_context(x)
    x == context[]
end
function new_context()
    context[] = gensym()
end
