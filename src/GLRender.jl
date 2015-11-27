
function render(list::AbstractVector)
    for elem in list
        render(elem)
    end
end

headtail(a::Tuple) = a[1], Base.tail(a)
headtail{T}(a::Tuple{T}) = a[1], ()

function render(renderobject::RenderObject, vertexarray=renderobject.vertexarray)
    if value(renderobject.uniforms[:visible])
        for elem in renderobject.prerenderfunctions
            f, args = headtail(elem)
            f(args...)
        end
        program = vertexarray.program
        glUseProgram(program.id)
        for (key,value) in program.uniformloc
            haskey(renderobject.uniforms, key) && gluniform(value..., renderobject.uniforms[key])
        end
        for elem in renderobject.postrenderfunctions
            f, args = headtail(elem)
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


function renderinstanced(vao::GLVertexArray, amount::Union{GPUArray, GPUVector}, primitive=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    glDrawElementsInstanced(primitive, vao.indexlength, GL_UNSIGNED_INT, C_NULL, length(amount))
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
