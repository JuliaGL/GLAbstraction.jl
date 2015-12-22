
function render(list::AbstractVector)
    for elem in list
        render(elem)
    end
end


function render(renderobject::RenderObject, vertexarray=renderobject.vertexarray)
    if Bool(value(renderobject.uniforms[:visible]))
        for elem in renderobject.prerenderfunctions
            elem[1](elem[2]...)
        end
        program = vertexarray.program
        glUseProgram(program.id)
        for (key,value) in program.uniformloc
            if haskey(renderobject.uniforms, key)
                gluniform(value..., renderobject.uniforms[key])
            end
        end
        for elem in renderobject.postrenderfunctions
            f, args = elem
            f(args...)
        end
    end
end
function render{T <: VecOrSignal{UnitRange{Int}}}(vao::GLVertexArray{T}, mode::GLenum=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    for elem in value(vao.indexes)
        glDrawArrays(mode, max(first(elem)-1, 0), length(elem)+1)
    end
    glBindVertexArray(0)
end
function render{T<:Union{Integer, Face}}(vao::GLVertexArray{GLBuffer{T}}, mode::GLenum=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    glDrawElements(mode, length(vao.indexes)*cardinality(vao.indexes), julia2glenum(T), C_NULL)
    glBindVertexArray(0)
end
function render{T<:TOrSignal{Int}}(vao::GLVertexArray{T}, mode::GLenum=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    glDrawArrays(mode, 0, value(vao.indexes))
    glBindVertexArray(0)
end
renderinstanced(vao::GLVertexArray, a, primitive=GL_TRIANGLES) = renderinstanced(vao, length(a), primitive)
function renderinstanced{T<:Union{Integer, Face}}(vao::GLVertexArray{GLBuffer{T}}, amount::Integer, primitive=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    glDrawElementsInstanced(primitive, length(vao.indexes)*cardinality(vao.indexes), julia2glenum(T), C_NULL, amount)
    glBindVertexArray(0)
end
function renderinstanced{T<:TOrSignal{Int}}(vao::GLVertexArray{T}, amount::Integer, primitive=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    glDrawElementsInstanced(primitive, length(value(vao.indexes)), GL_UNSIGNED_INT, C_NULL, amount)
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
