export render
function render(x::GLRenderObject)
    for elem in x.preRenderFunctions
        apply(elem...)
    end

    glUseProgram(x.program.id)
    glBindVertexArray(x.vertexArray.id)
    render(x.uniforms)
    #glUniform4f(glGetUniformLocation(x.program.id, "Color"), 1,1,0,1)
    for elem in x.postRenderFunctions
        apply(elem...)
    end
end


#Render Unifomrs!!

#Render Dicts filled with uniforms
function render(obj::Dict{String, Any}, shaderId)
  for elem in obj
    render(elem..., shaderId)
  end
end

function render(obj::Dict{GLint, Any})
  for elem in obj
    render(elem...)
  end
end

function render(name::String, t::Texture, shaderId)
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(t.textureType, t.id)
    glUniform1i(glGetUniformLocation(id, name), 0)
end

function render(attribute::String, cam::Camera, shaderId)
    glUniformMatrix4fv(glGetUniformLocation(shaderId, attribute), 1, GL_FALSE, cam.viewProjMat)
end

#handle all remaining uniform funcitons
setProgramDefault(location::ASCIIString, object::Array, programID) = setProgramDefault(glGetUniformLocation(programID, location), object, programID)

function setProgramDefault(location::GLint, object::Array, programID)
    func = getUniformFunction(object, "Program")
    D = length(size(object))
    T = eltype(object)
    objectPtr = convert(Ptr{T}, pointer(object))
    if D == 1
        func(programID, location, 1, objectPtr)
    elseif D == 2
        func(programID, location, 1, GL_FALSE, objectPtr)
    else
        error("glUniform: unsupported dimensionality")
    end
end

render(location::ASCIIString, object::Array, programID) = render(glGetUniformLocation(programID, location), object)
function render(location::GLint, object::Array)
    func = getUniformFunction(object, "")
    D = length(size(object))
    T = eltype(object)
    objectPtr = convert(Ptr{T}, pointer(object))
    if D == 1
        func(location, 1, objectPtr)
    elseif D == 2
        func(location, 1, GL_FALSE, object)
    else
        error("glUniform: unsupported dimensionality")
    end
end


function getUniformFunction(object::Array, program::ASCIIString)
    T = eltype(object)
    D = length(size(object))
    @assert(!isempty(object))
    @assert D <= 2
    matrix = D == 2
    if matrix
        @assert T <: FloatingPoint #There are only functions for Float32 matrixes
    end

    dims = size(object)

    if D == 1 || dims[1] == dims[2]
        cardinality = string(dims[1])
    else
        cardinality = string(dims[1], "x", dims[2])
    end
    if T == GLuint
        elementType = "uiv"
    elseif T == GLint
        elementType = "iv"
    elseif T == GLfloat
        elementType = "fv"
    else
        error("type not supported")
    end
    func = eval(parse("gl" *program* "Uniform" * (matrix ? "Matrix" : "")* cardinality *elementType))
end



##############################################################################################
#  Generic render functions 
#####
function enableTransparency()
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end

function drawVertexArray(x::GLRenderObject)    
    glDrawArrays(x.vertexArray.primitiveMode, 0, x.vertexArray.size)
end

export enableTransparency, drawVertexArray