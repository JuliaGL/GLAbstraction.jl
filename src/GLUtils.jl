macro gputime(codeblock)
  quote 
    local const query        = GLuint[1]
    local const elapsed_time = GLuint64[1]
    local const done         = GLint[0]
    glGenQueries(1, query)
    glBeginQuery(GL_TIME_ELAPSED, query[1])
    value = $(esc(codeblock))
    glEndQuery(GL_TIME_ELAPSED)

    while (done[1] != 1)
      glGetQueryObjectiv(query[1],
              GL_QUERY_RESULT_AVAILABLE,
              done)
    end 
    glGetQueryObjectui64v(query[1], GL_QUERY_RESULT, elapsed_time)
    println("Time Elapsed: ", elapsed_time[1] / 1000000.0, "ms")
  end
end

immutable IterOrScalar{T}
  val::T
end
minlenght(a::(IterOrScalar...)) = foldl(typemax(Int), a) do len, elem
  if isa(elem.val, AbstractArray) && len > length(elem.val) 
    return length(elem.val)
  end
  len
end
Base.getindex{T<:AbstractArray}(A::IterOrScalar{T}, i::Integer) = A.val[i] 
Base.getindex(A::IterOrScalar, i::Integer) = A.val

foreach(func::Union(Function, DataType), args...) = foreach(func, map(IterOrScalar, args)...)

# Applies a function over multiple args
# staged, so it can specialize on the arguments being scalar or iterable
stagedfunction foreach(func::Function, args::IterOrScalar...)
  args_access = [:(args[$i][i]) for i=1:length(args)]
  quote
    len = minlenght(args)
    for i=1:len 
      func($(args_access...))
    end
  end
end

#Some mapping functions for dictionaries
function mapvalues(func::Union(Function, Base.Func), collection::Dict)
   [key => func(value) for (key, value) in collection]
end
function mapkeys(func::Union(Function, Base.Func), collection::Dict)
   [func(key) => value for (key, value) in collection]
end

function print_with_lines(text::AbstractString)
    for (i,line) in enumerate(split(text, "\n"))
        @printf("%-4d: %s\n", i, line)
    end
end




#=
Style Type, which is used to choose different visualization/editing styles via multiple dispatch
Usage pattern:
visualize(::Style{:Default}, ...)           = do something
visualize(::Style{:MyAwesomeNewStyle}, ...) = do something different
=#
immutable Style{StyleValue}
end
Style(x::Symbol) = Style{x}()
Style() = Style{:Default}()
mergedefault!{S}(style::Style{S}, styles, customdata) = merge!(copy(styles[S]), Dict{Symbol, Any}(customdata))



Base.length{T <: Real}(::Type{T}) = 1


#splats keys from a dict into variables
macro materialize(dict_splat)
    keynames, dict = dict_splat.args
    dict_instance = gensym()
    kd = [:($key = $dict_instance[$(Expr(:quote, key))]) for key in keynames.args]
    kdblock = Expr(:block, kd...)
    expr = quote
        $dict_instance = $dict # handle if dict is not a variable but an expression 
        $kdblock
    end
    esc(expr)
end

macro materialize!(dict_splat)
    keynames, dict = dict_splat.args
    dict_instance = gensym()
    kd = [:($key = pop!($dict_instance, $(Expr(:quote, key)))) for key in keynames.args]
    kdblock = Expr(:block, kd...)
    expr = quote
        $dict_instance = $dict # handle if dict is not a variable but an expression 
        $kdblock
    end
    esc(expr)
end