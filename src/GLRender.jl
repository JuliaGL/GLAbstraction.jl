
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
        glDrawArrays(mode, max(first(elem)-1, 0), min(length(elem)+1, vao.length))
    end
    glBindVertexArray(0)
end
function render{T<:TOrSignal{Int}}(vao::GLVertexArray{T}, mode::GLenum=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    if value(vao.indexes) > 0
        glDrawElements(mode, value(vao.indexes), GL_UNSIGNED_INT, C_NULL)
    else
        glDrawArrays(mode, 0, vao.length)
    end
    glBindVertexArray(0)
end
renderinstanced(vao::GLVertexArray, a, primitive=GL_TRIANGLES) = renderinstanced(vao, length(a), primitive)
function renderinstanced(vao::GLVertexArray, amount::Integer, primitive=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    glDrawElementsInstanced(primitive, value(vao.indexes), GL_UNSIGNED_INT, C_NULL, amount)
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
