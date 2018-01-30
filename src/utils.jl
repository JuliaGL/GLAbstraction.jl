
macro gputime(codeblock)
    quote
        local const query        = GLuint[1]
        local const elapsed_time = GLuint64[1]
        local const done         = GLint[0]
        glGenQueries(1, query)
        glBeginQuery(GL_TIME_ELAPSED, query[1])
        $(esc(codeblock))
        glEndQuery(GL_TIME_ELAPSED)

        while (done[1] != 1)
            glGetQueryObjectiv(
                query[1],
                GL_QUERY_RESULT_AVAILABLE,
                done
            )
        end
        glGetQueryObjectui64v(query[1], GL_QUERY_RESULT, elapsed_time)
        println("Time Elapsed: ", elapsed_time[1] / 1000000.0, "ms")
    end
end

function print_with_lines(out::IO, text::AbstractString)
    io = IOBuffer()
    for (i,line) in enumerate(split(text, "\n"))
        println(io, Base.Printf.@sprintf("%-4d: %s", i, line))
    end
    write(out, take!(io))
end

print_with_lines(text::AbstractString) = print_with_lines(STDOUT, text)
function free_handle_error(e)
    #ignore, since freeing is not needed if context is not available
    isa(e, ContextNotAvailable) && return
    rethrow(e)
end
"""
Returns the cardinality of a type. falls back to length
"""
cardinality(x) = length(x)
cardinality(x::Number) = 1
cardinality(::Void) = 1
cardinality(x::Type{T}) where {T <: Number} = 1

function glasserteltype(::Type{T}) where T 
    try
        length(T)
    except
        error("Error only types with well defined lengths are allowed")
    end
end