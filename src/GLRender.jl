

"""
Render a list of Renderables
"""
function render(list::AbstractVector{RenderObject{Pre}})
    first(list).prerenderfunction()
    vertexarray = first(list).vertexarray
    program = vertexarray.program
    glUseProgram(program)
    for elem in list
        renderobject.visible || continue # skip invisible
        # make sure we only bind new programs and vertexarray when it is actually
        # different from the previous one
        if elem.vertexarray != vertexarray
            vertexarray = elem.vertexarray
            if vertexarray.program != program
                program = elem.vertexarray.program
                glUseProgram(program)
            end
            glBindVertexArray(vertexarray.id)
        end
        for (key,value) in program.uniformloc
            if haskey(renderobject.uniforms, key)
                gluniform(value..., renderobject.uniforms[key])
            end
        end
        renderobject.postrenderfunction()
    end
    # we need to assume, that we're done here, which is why
    # we need to bind VertexArray to 0.
    # Otherwise, every glBind(::GLBuffer) operation will be recorded into the state
    # of the currenttly bound vertexarray
    glBindVertexArray(0)
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
    for elem in value(vao.indexes)
        glDrawArrays(mode, max(first(elem)-1, 0), length(elem)+1)
    end
end

"""
Renders a vertex array which supplies an indexbuffer
"""
function render{T<:Union{Integer, Face}}(vao::GLVertexArray{GLBuffer{T}}, mode::GLenum=GL_TRIANGLES)
    glDrawElements(mode, length(vao.indices)*cardinality(vao.indices), julia2glenum(T), C_NULL)
end
"""
Renders a normal vertex array only containing the usual buffers buffers.
"""
function render(vao::GLVertexArray, mode::GLenum=GL_TRIANGLES)
    glDrawArrays(mode, 0, length(vao))
end

"""
Render instanced geometry
"""
renderinstanced(vao::GLVertexArray, a, primitive=GL_TRIANGLES) = renderinstanced(vao, length(a), primitive)

"""
Renders `amount` instances of an indexed geometry
"""
function renderinstanced{T<:Union{Integer, Face}}(vao::GLVertexArray{GLBuffer{T}}, amount::Integer, primitive=GL_TRIANGLES)
    glDrawElementsInstanced(primitive, length(vao.indices)*cardinality(vao.indices), julia2glenum(T), C_NULL, amount)
end
"""
Renders `amount` instances of an not indexed geoemtry geometry
"""
function renderinstanced(vao::GLVertexArray, amount::Integer, primitive=GL_TRIANGLES)
    glDrawElementsInstanced(primitive, length(vao), GL_UNSIGNED_INT, C_NULL, amount)
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
