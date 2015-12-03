
function render(list::AbstractVector)
    for elem in list
        render(elem)
    end
end

function render(renderobject::RenderObject, vertexarray=renderobject.vertexarray)
    if value(renderobject.uniforms[:visible])
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

function render(vao::GLVertexArray, mode::GLenum=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    if vao.indexlength > 0
        glDrawElements(mode, vao.indexlength, GL_UNSIGNED_INT, C_NULL)
    else
        glDrawArrays(mode, 0, vao.length)
    end
    glBindVertexArray(0)
end
renderinstanced(vao::GLVertexArray, a::AbstractArray, primitive=GL_TRIANGLES) = renderinstanced(vao, length(a), primitive)
function renderinstanced(vao::GLVertexArray, amount::Integer, primitive=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    glDrawElementsInstanced(primitive, vao.indexlength, GL_UNSIGNED_INT, C_NULL, amount)
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
