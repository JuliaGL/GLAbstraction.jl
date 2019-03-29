import FileIO: File, filename, file_extension, @format_str, query

function iscompiled(shader::GLuint)
    success = GLint[0]
    glGetShaderiv(shader, GL_COMPILE_STATUS, success)
    return first(success) == GL_TRUE
end

abstract type AbstractShader end

struct Shader <: AbstractShader
    name    ::Symbol
    source  ::Vector{UInt8} #UInt representation of the source program string,
    typ     ::GLenum
    id      ::GLuint
    function Shader(name, source, typ, id)
        new(name, source, typ, id)
    end
end

function Shader(name, shadertype, source::Vector{UInt8})
    shaderid = glCreateShader(shadertype)::GLuint
    @assert shaderid > 0 "opengl context is not active or shader type not accepted. Shadertype: $(GLENUM(shadertype).name)"
    glShaderSource(shaderid, source)
    glCompileShader(shaderid)
    if !iscompiled(shaderid)
        print_with_lines(String(source))
        @error "shader $(name) didn't compile. \n$(getinfolog(shaderid))"
    end
    Shader(name, source, shadertype, shaderid)
end
function Shader(path::String, source_str::AbstractString)
    typ = shadertype(query(path))
    source = Vector{UInt8}(source_str)
    name = Symbol(path)
    Shader(name, typ, source)
end
Shader(path::File{format"GLSLShader"}) = load(path)

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
    @error "$ext not a valid shader extension."
end
function shadertype(typ::Symbol)
    (typ == :compute  || typ == :comp) && return GL_COMPUTE_SHADER
    (typ == :vertex   || typ == :vert) && return GL_VERTEX_SHADER
    (typ == :fragment || typ == :frag) && return GL_FRAGMENT_SHADER
    (typ == :geometry || typ == :geom) && return GL_GEOMETRY_SHADER
    @error "$typ not a valid shader symbol."
end

#Implement File IO interface
function load(f::File{format"GLSLShader"})
    fname = filename(f)
    source = read(open(fname), String)
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

function getinfolog(id::GLuint)
    # Get the maximum possible length for the descriptive error message
    maxlength = GLint[0]
    glGetShaderiv(id, GL_INFO_LOG_LENGTH, maxlength)
    maxlength = first(maxlength)
    # Return the text of the message if there is any
    if maxlength > 0
        buffer = zeros(GLchar, maxlength)
        sizei = GLsizei[0]
        glGetShaderInfoLog(id, maxlength, sizei, buffer)
        length = first(sizei)
        return unsafe_string(pointer(buffer), length)
    else
        return "success"
    end
end
