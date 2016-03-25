"""
Dictionary types which keys are fixed at creation time
"""
abstract AbstractFixedDict{Keys}

"""
Dictionary types which keys and values are fixed at creation time
"""
immutable FixedKeyValueDict{Keys<:Tuple, Values<:Tuple} <: AbstractFixedDict{Keys}
    values::Values
end
function FixedKeyValueDict{N}(keys::NTuple{N, Symbol}, values::NTuple{N, Any})
    keyparams = Tuple{keys...}
    FixedKeyValueDict{keyparams}(values)
end
function FixedKeyValueDict{}(key_values::NTuple{N, Pair})
    keys = map(first, key_values)
    values = map(last, key_values)
    keyparams = Tuple{keys...}
    FixedKeyValueDict{keyparams}(values)
end

"""
Dictionary types which keys are fixed at creation time
"""
immutable FixedKeyDict{Keys<:Tuple, Values<:Vector} <: AbstractFixedDict{Keys}
    values::Values
end
function FixedKeyValueDict{}(keys::NTuple{N, Symbol}, values::NTuple{N, Any})
    keyparams = Tuple{keys...}
    FixedKeyValueDict{keyparams}(values)
end
function FixedKeyValueDict{}(key_values::NTuple{N, Pair})
    keys = map(first, key_values)
    values = [v for (k,v) in key_values]
    keyparams = Tuple{keys...}
    FixedKeyValueDict{keyparams}(values)
end

Base.keys{Keys}(::Type{AbstractFixedDict{Keys}}) = (Keys.parameters...)
Base.keys{T<:AbstractImmutableDict}(::Type{T}) = keys(super(T))
Base.keys{T<:AbstractImmutableDict}(::T) = keys(T)

@generated function Base.getindex{T<:AbstractImmutableDict, Key}(
        sd::T, ::Val{Key}
    )
    index = findfirst(keys(T), Key)
    index == 0 && throw(KeyError("key $Key not found in $sd"))
    :(sd.values[$index])
end

@generated function Base.setindex!{T<:AbstractImmutableDict, Key}(
        sd::T, value, ::Val{Key}
    )
    index = findfirst(keys(T), Key)
    index == 0 && throw(KeyError("key $Key not found in $sd"))
    :(sd.values[$index] = value)
end

@generated function Base.getindex{T<:AbstractImmutableDict, Key}(
        sd::T, ::Val{Key}
    )
    index = findfirst(keys(T), Key)
    index == 0 && throw(KeyError("key $Key not found in $sd"))
    :(sd.values[$index])
end

"""
Render a list of Renderables
"""
function render(list::AbstractVector{RenderObject{Pre, Post}})
    first(list).prerenderfunction()
    program = first(list).vertexarray.program
    glUseProgram(program)
    for elem in list
        if elem.vertexarray.program != program
            program = elem.vertexarray.program
            glUseProgram(program)
        end
        render(elem)
    end
end

"""
Renders a RenderObject
Note, that this function is not optimized at all!
It uses dictionaries and doesn't care about OpenGL call optimizations.
So rewriting this function could get us a lot of performance for scenes with
a lot of objects.
"""
function render(renderobject::RenderObject, vertexarray=renderobject.vertexarray)
    if Bool(value(renderobject.uniforms[:visible]))
        renderobject.prerenderfunction()
        program = vertexarray.program
        glUseProgram(program.id)
        for (key,value) in program.uniformloc
            if haskey(renderobject.uniforms, key)
                gluniform(value..., renderobject.uniforms[key])
            end
        end
        renderobject.postrenderfunction()
    end
end

"""
Renders a vertexarray, which consists of the usual buffers plus a vector of
unitranges which defines the segments of the buffers to be rendered
"""
function render{T <: VecOrSignal{UnitRange{Int}}}(vao::GLVertexArray{T}, mode::GLenum=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    for elem in value(vao.indexes)
        glDrawArrays(mode, max(first(elem)-1, 0), length(elem)+1)
    end
    glBindVertexArray(0)
end

"""
Renders a vertex array which supplies an indexbuffer
"""
function render{T<:Union{Integer, Face}}(vao::GLVertexArray{GLBuffer{T}}, mode::GLenum=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    glDrawElements(mode, length(vao.indices)*cardinality(vao.indices), julia2glenum(T), C_NULL)
    glBindVertexArray(0)
end
"""
Renders a normal vertex array only containing the usual buffers buffers.
"""
function render(vao::GLVertexArray, mode::GLenum=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    glDrawArrays(mode, 0, length(vao))
    glBindVertexArray(0)
end

"""
Render instanced geometry
"""
renderinstanced(vao::GLVertexArray, a, primitive=GL_TRIANGLES) = renderinstanced(vao, length(a), primitive)

"""
Renders `amount` instances of an indexed geometry
"""
function renderinstanced{T<:Union{Integer, Face}}(vao::GLVertexArray{GLBuffer{T}}, amount::Integer, primitive=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    glDrawElementsInstanced(primitive, length(vao.indices)*cardinality(vao.indices), julia2glenum(T), C_NULL, amount)
    glBindVertexArray(0)
end
"""
Renders `amount` instances of an not indexed geoemtry geometry
"""
function renderinstanced(vao::GLVertexArray, amount::Integer, primitive=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    glDrawElementsInstanced(primitive, length(vao), GL_UNSIGNED_INT, C_NULL, amount)
    glBindVertexArray(0)
end
#handle all uniform objects



##############################################################################################
#  Generic render functions
#####
function enabletransparency()
    glEnablei(GL_BLEND, 0)
    glDisablei(GL_BLEND, 1)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end
