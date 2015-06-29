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
minlenght(a::@compat(Tuple{Vararg{IterOrScalar}})) = foldl(typemax(Int), a) do len, elem
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
@generated function foreach(func::Function, args::IterOrScalar...)
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
    keynames = isa(keynames, Symbol) ? [keynames] : keynames.args
    dict_instance = gensym()
    kd = [:($key = $dict_instance[$(Expr(:quote, key))]) for key in keynames]
    kdblock = Expr(:block, kd...)
    expr = quote
        $dict_instance = $dict # handle if dict is not a variable but an expression 
        $kdblock
    end
    esc(expr)
end

macro materialize!(dict_splat)
    keynames, dict = dict_splat.args
    keynames = isa(keynames, Symbol) ? [keynames] : keynames.args
    dict_instance = gensym()
    kd = [:($key = pop!($dict_instance, $(Expr(:quote, key)))) for key in keynames]
    kdblock = Expr(:block, kd...)
    expr = quote
        $dict_instance = $dict # handle if dict is not a variable but an expression 
        $kdblock
    end
    esc(expr)
end


makesignal(s::Signal) = s
makesignal(v)         = Input(v)
function Base.consume(f::Reactive.Callable, inputs...)
    consume(f, map(makesignal, inputs)...)
end


function close_to_square(n::Real)
    # a cannot be greater than the square root of n
    # b cannot be smaller than the square root of n
    # we get the maximum allowed value of a
    amax = floor(Int, sqrt(n));
    if 0 == rem(n, amax)
        # special case where n is a square number
        return (amax, div(n, amax))
    end
    # Get its prime factors of n
    primeFactors  = factor(n);
    # Start with a factor 1 in the list of candidates for a
    candidates = Int[1]
    for (f, _) in primeFactors
        # Add new candidates which are obtained by multiplying
        # existing candidates with the new prime factor f
        # Set union ensures that duplicate candidates are removed
        candidates  = union(candidates, f .* candidates);
        # throw out candidates which are larger than amax
        filter!(x-> x <= amax, candidates)
    end
    # Take the largest factor in the list d
    (candidates[end], div(n, candidates[end]))
end
