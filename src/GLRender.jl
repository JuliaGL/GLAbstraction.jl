export render
using React
export enabletransparency, renderinstanced


function render(renderobject::RenderObject)
    for elem in renderobject.preRenderFunctions
        apply(elem...)
    end

    glUseProgram(renderobject.vertexarray.program.id)

    for elem in renderobject.uniforms
        gluniform(elem...)
    end

    #render(renderObject.vertexarray)

    for elem in renderobject.postRenderFunctions
        apply(elem...)
    end
end


function render(vao::GLVertexArray, mode::GLenum = GL_TRIANGLES)
    glBindVertexArray(vao.id)
    if vao.indexlength > 0
        glDrawElements(mode, vao.indexlength, GL_UNSIGNED_INT, GL_NONE)
    else
        glDrawArrays(mode, 0, vao.length)
    end
end

function renderinstanced(vao::GLVertexArray, amount::Integer)
    glBindVertexArray(vao.id)
    glDrawElementsInstancedEXT(GL_TRIANGLES, vao.indexlength, GL_UNSIGNED_INT, C_NULL, amount)
end

#handle all uniform objects






##############################################################################################
#  Generic render functions
#####
function enabletransparency()
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end

