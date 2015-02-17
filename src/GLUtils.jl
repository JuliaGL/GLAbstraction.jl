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



foreach(func::Function, collection) = for elem in collection; func(elem); end

function mapvalues(func::Union(Function, Base.Func), collection::Dict)
   [key => func(value) for (key, value) in collection]
end
function mapkeys(func::Union(Function, Base.Func), collection::Dict)
   [func(key) => value for (key, value) in collection]
end
# Simple file wrapper, which encodes the type of the file in its parameter
# Usefull for file IO
immutable File{Ending}
  abspath::UTF8String
end
File(folders...) = File(joinpath(folders...))
function File(file)
  @assert !isdir(file) "file string refers to a path, not a file. Path: $file"
  file  = abspath(file)
  path  = dirname(file)
  name  = file[length(path):end]
  ending  = rsearch(name, ".")
  ending  = isempty(ending) ? "" : name[first(ending)+1:end]
  File{symbol(ending)}(file)
end

Base.open(x::File)    = open(abspath(x))
Base.abspath(x::File) = x.abspath


function print_with_lines(text::AbstractString)
    for (i,line) in enumerate(split(shadercode, "\n"))
        @printf("%-4d: %s\n", i, line)
    end
end


immutable Field{Symbol}
end