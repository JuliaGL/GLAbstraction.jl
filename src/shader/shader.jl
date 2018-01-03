struct Shader
    name::Symbol
    source::Vector{UInt8}
    typ::GLenum
    id::GLuint
    context::GLContext
    function Shader(name, source, typ, id)
        new(name, source, typ, id, current_context())
    end
end

function Shader(source::Vector{UInt8}, typ, name)
    shaderid = createshader(typ)
    glShaderSource(shaderid, source)
    glCompileShader(shaderid)
    if !iscompiled(shaderid)
        print_with_lines(String(source))
        error("shader $(name) didn't compile. \n$(GLAbstraction.getinfolog(shaderid))")
    end
    Shader(name, source, typ, shaderid)
end
function Shader(path, source_str::AbstractString)
    typ = GLAbstraction.shadertype(query(path))
    source = Vector{UInt8}(source_str)
    name = Symbol(path)
    Shader(source, typ, name)
end

import Base: ==
(==)(a::Shader, b::Shader) = a.source == b.source && a.typ == b.typ && a.id == b.id && a.context == b.context
Base.hash(s::Shader, h::UInt64) = hash((s.source, s.typ, s.id, s.context), h)

function Base.show(io::IO, shader::Shader)
    println(io, GLENUM(shader.typ).name, " shader: $(shader.name))")
    println(io, "source:")
    print_with_lines(io, String(shader.source))
end

shadertype(s::Shader) = s.typ
function shadertype(f::File{format"GLSLShader"})
    shadertype(file_extension(f))
end
function shadertype(ext::AbstractString)
    ext == ".comp" && return GL_COMPUTE_SHADER
    ext == ".vert" && return GL_VERTEX_SHADER
    ext == ".frag" && return GL_FRAGMENT_SHADER
    ext == ".geom" && return GL_GEOMETRY_SHADER
    error("$ext not a valid extension for $f")
end
#Implement File IO interface
function load(f::File{format"GLSLShader"})
    fname = filename(f)
    source = open(readstring, fname)
    Shader(fname, source)
end
function save(f::File{format"GLSLShader"}, data::Shader)
    s = open(f, "w")
    write(s, data.source)
    close(s)
end
# Different shader string literals- usage: e.g. frag" my shader code"
macro frag_str(source::AbstractString)
    quote
        ($source, GL_FRAGMENT_SHADER)
    end
end
macro vert_str(source::AbstractString)
    quote
        ($source, GL_VERTEX_SHADER)
    end
end
macro geom_str(source::AbstractString)
    quote
        ($source, GL_GEOMETRY_SHADER)
    end
end
macro comp_str(source::AbstractString)
    quote
        ($source, GL_COMPUTE_SHADER)
    end
end
