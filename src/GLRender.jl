export render, enabletransparency, renderinstanced


function render(renderobject::RenderObject)
    for elem in renderobject.preRenderFunctions
        apply(elem...)
    end
    p = renderobject.vertexarray.program
    glUseProgram(p.id)
    for (key,value) in renderobject.uniforms
        gluniform(p.uniformloc[key]..., value)
    end
    for elem in renderobject.postRenderFunctions
        apply(elem...)
    end
end


function render(vao::GLVertexArray, mode::GLenum=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    if vao.indexlength > 0
        glDrawElements(mode, vao.indexlength, GL_UNSIGNED_INT, GL_NONE)
    else
        glDrawArrays(mode, 0, vao.length)
    end
end

function renderinstanced(vao::GLVertexArray, amount::Integer, primitive=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    #If you get an error here, notify me and try:
    #glDrawElementsInstancedEXT(primitive, vao.indexlength, GL_UNSIGNED_INT, C_NULL, amount)
    glDrawElementsInstanced(primitive, vao.indexlength, GL_UNSIGNED_INT, C_NULL, amount)
end

#handle all uniform objects



##############################################################################################
#  Generic render functions
#####
function enabletransparency()
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end

