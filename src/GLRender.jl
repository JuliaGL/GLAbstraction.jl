
function render(name::String, t::Texture, shaderId)
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(t.textureType, t.id)
    glUniform1i(glGetUniformLocation(id, name), 0)
end


function render(attribute::String, cam::Camera, shaderId)
     glUniformMatrix4fv(glGetUniformLocation(shaderId, attribute), 1, GL_FALSE, cam.viewProjMat)
end
function render(attribute::String, vector::Vector4{Float32}, shaderId)
glUniform4fv(glGetUniformLocation(shaderId, attribute), vector)
end
function render(attribute::String, vector::Vector3{Float32}, shaderId)
     glUniform3fv(glGetUniformLocation(shaderId, attribute), vector)
end
function render(attribute::String, vector::Vector2{Float32}, shaderId)
     glUniform2fv(glGetUniformLocation(shaderId, attribute), vector)
end
function render(attribute::String, vector::Union(Vector1, Float32), shaderId)
     glUniform1f(glGetUniformLocation(shaderId, attribute), vector)
end

function render(attributeLocation::GLuint, m::Matrix4x4{Float32})
     glUniform4fv(attributeLocation, m)
end
function render(attributeLocation::GLuint, cam::Camera)
     glUniformMatrix4fv(attributeLocation, 1, GL_FALSE, cam.viewProjMat)
end
function render(attributeLocation::GLuint, vector::Vector4{Float32})
glUniform4fv(attributeLocation, vector)
end
function render(attributeLocation::GLuint, vector::Vector3{Float32})
     glUniform3fv(attributeLocation, vector)
end
function render(attributeLocation::GLuint, vector::Vector2{Float32})
     glUniform2fv(attributeLocation, vector)
end
function render(attributeLocation::GLuint, vector::Union(Vector1, Float32))
     glUniform1f(attributeLocation, vector)
end

function render(attributeLocation::GLuint, m::Matrix4x4{Float32})
     glUniform4fv(attributeLocation, m)
end
 
function render(obj::Dict{String, Any}, shaderId)
  for elem in obj
    render(elem..., shaderId)
  end
end

function render(obj::Dict{GLuint, Any})
  for elem in obj
    render(elem...)
  end
end

function render(x::RenderObject)
    for elem in preRenderFunctions
        apply(elem..., x)
    end

    glUseProgram(x.shader.id)
    render(x.uniforms)
    glBindVertexArray(x.vertArray.id)

    for elem in postRenderFunctions
        apply(elem..., x)
    end
end

# macro createUniformFunctions(types)
  
#     body = Expr(:call, glFuncName, :attributeLocation, 1, :GL_FALSE, object...)
#     ret  = Expr(:function, 
#       Expr(:call, :render, 
#       Expr(:(::), attribute, ASCIIString), 
#       Expr(:(::), attributeLocation, GLuint), 
#       Expr(:(::), object, types), body)

#     return esc(ret)
# end

# macro createUniformFunctions(types)
#   glFunc = symbol("glUniform"**"fv")
#   quote
#       function render(attributeLocation::GLuint, object::types)
#         $(glFunc)(attributeLocation, object)
#     end
#   end
#     return esc(ret)
# end