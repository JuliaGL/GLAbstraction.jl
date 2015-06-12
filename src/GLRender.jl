
function render(list::AbstractVector)
    for elem in list
        render(elem)
    end
end

function render(renderobject::RenderObject, vertexarray=renderobject.vertexarray)
    if value(renderobject.alluniforms[:visible])
        for elem in renderobject.prerenderfunctions
            elem[1](elem[2]...)
        end
        program = vertexarray.program
        glUseProgram(program.id)
        for (key,value) in program.uniformloc
            haskey(renderobject.uniforms, key) && gluniform(value..., renderobject.uniforms[key])
        end
        for elem in renderobject.postrenderfunctions
            elem[1](elem[2]...)
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

function renderinstanced(vao::GLVertexArray, amount::Integer, primitive=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    #If you get an error here, notify me and try:
    #glDrawElementsInstancedEXT(primitive, vao.indexlength, GL_UNSIGNED_INT, C_NULL, amount)
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

