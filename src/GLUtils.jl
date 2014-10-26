macro gputime(codeblock)
  quote 
    local const query = GLuint[1]
    local const elapsed_time = GLuint64[1]
    local const done = GLint[0]
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