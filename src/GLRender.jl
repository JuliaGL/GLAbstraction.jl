export render
using React
export enabletransparency, drawVertexArray

render(location::GLint, signal::Signal) = render(location, signal.value)

function render(renderObject::RenderObject)
    for elem in renderObject.preRenderFunctions
        apply(elem...)
    end

    programID = renderObject.vertexarray.program.id
    glUseProgram(programID)
    render(renderObject.uniforms)
    #render(renderObject.vertexarray)

    for elem in renderObject.postRenderFunctions
        apply(elem...)
    end
end

function render(vao::GLVertexArray)
    glBindVertexArray(vao.id)
    if vao.indexlength > 0
        glDrawElements(GL_TRIANGLES, vao.indexlength, GL_UNSIGNED_INT, GL_NONE)
    else
        glDrawArrays(GL_TRIANGLES, 0, vao.length)
    end
end
function render(vao::GLVertexArray, mode)
    glBindVertexArray(vao.id)
    if vao.indexlength > 0
        glDrawElements(mode, vao.indexlength, GL_UNSIGNED_INT, GL_NONE)
    else
        glDrawArrays(mode, 0, vao.length)
    end
end



#Render Uniforms

function render(obj::Dict{ASCIIString, Any}, programID)
  for elem in obj
    render(elem..., programID)
  end
end

function render(obj::AbstractArray)
  for elem in obj
    render(elem...)
  end
end

#handle all uniform objects

render(attribute::ASCIIString, anyUniform, programID::GLuint)               = render(glGetUniformLocation(programID, attribute), anyUniform)
render(attribute::Symbol, anyUniform, programID::GLuint)                    = render(glGetUniformLocation(programID, string(attribute)), anyUniform)


function render(location::GLint, target::GLint, t::Texture)
    activeTarget = GL_TEXTURE0 + uint32(target)
    glActiveTexture(activeTarget)
    glBindTexture(t.texturetype, t.id)
    glUniform1i(location, target)
end


function render(location::GLint, cam::Camera)
    render(location, cam.mvp)
end

render(location::GLint, object::Real)               = render(location, [object])

function render(location::GLint, object::AbstractArray)
    func = uniformfunction(object)
    D = length(size(object))
    T = eltype(object)
    objectPtr = convert(Ptr{T}, pointer([object]))
    if D == 1
        func(location, 1, objectPtr)
    elseif D == 2
        func(location, 1, GL_FALSE, objectPtr)
    else
        error("glUniform: unsupported dimensionality")
    end
end


function uniformfunction(object::Any)
    T, cardinality = opengl_compatible(T)
    uniformfunction(T, cardinality, [cardinality])
end
function uniformfunction(object::AbstractArray)
    T           = eltype(object)
    cardinality = length(size(object))
    dims        = [size(object)...]
    uniformfunction(T, cardinality, dims)
end
function uniformfunction(T::DataType, cardinality::Integer, dims::AbstractArray)
    D = length(dims)
    @assert D <= 2
    matrix = D == 2
    if matrix
        @assert T <: FloatingPoint #There are only functions for Float32 matrixes
    end

    if D == 1 || dims[1] == dims[2] # if dimension is one or both dimensions are equal, there is no x between the dims
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
    elseif T == GLdouble
        elementType = "dv"
    else
        error("type for gl uniform not supported: ", T)
    end
    func = eval(parse("gl" * "Uniform" * (matrix ? "Matrix" : "")* cardinality *elementType))
end



##############################################################################################
#  Generic render functions
#####
function enabletransparency()
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end

