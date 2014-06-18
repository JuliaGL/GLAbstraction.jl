computeOrthographicProjection(
                        left::GLfloat, right::GLfloat,
                        bottom::GLfloat, top::GLfloat,
                        znear::GLfloat, zfar::GLfloat) = computeOrthographicProjection!(zeros(GLfloat, 4, 4), left, right, bottom, top, znear, zfar)

function computeOrthographicProjection!(
                        matrix::Matrix,
                        left::GLfloat, right::GLfloat,
                       bottom::GLfloat, top::GLfloat,
                       znear::GLfloat, zfar::GLfloat)

    @assert right != left
    @assert bottom != top
    @assert znear != zfar

    fill!(matrix, 0f0)

    matrix[1,1] = 2.0/(right-left);
    matrix[1,4] = -(right+left)/(right-left);
    matrix[2,2] = 2.0/(top-bottom);
    matrix[2,4] = -(top+bottom)/(top-bottom);
    matrix[3,3] = -2.0/(zfar-znear);
    matrix[3,4] = -(zfar+znear)/(zfar-znear);
    matrix[4,4] = 1.0;
    matrix
end

translateXMatrix(x::GLfloat) = translationMatrix( x, 0.0f0, 0.0f0)
translateYMatrix(y::GLfloat) = translationMatrix( 0.0f0, y, 0.0f0)
translateZMatrix(z::GLfloat) = translationMatrix( 0.0f0, 0.0f0, z)

function translationMatrix(translation::Array{GLfloat,1})
    result = eye(GLfloat, 4, 4)
    result[1:3,4] = translation
    return result
end


function frustum(left, right, bottom, top, znear, zfar):
    # Create view frustum

    # Parameters
    # ----------
    # left : float
    # Left coordinate of the field of view.
    # right : float
    # Left coordinate of the field of view.
    # bottom : float
    # Bottom coordinate of the field of view.
    # top : float
    # Top coordinate of the field of view.
    # znear : float
    # Near coordinate of the field of view.
    # zfar : float
    # Far coordinate of the field of view.

    # Returns
    # -------
    # M : array
    # View frustum matrix (4x4).
    
    @assert right != left
    @assert bottom != top
    @assert znear != zfar

    M = zeros(Float32, 4, 4)
    M[1, 1] = +2.0 * znear / (right - left)
    M[3, 1] = (right + left) / (right - left)
    M[2, 2] = +2.0 * znear / (top - bottom)
    M[4, 2] = (top + bottom) / (top - bottom)
    M[3, 3] = -(zfar + znear) / (zfar - znear)
    M[4, 3] = -2.0 * znear * zfar / (zfar - znear)
    M[3, 4] = -1.0
    return M
end

function pProj(fovy, aspect, znear, zfar):
    # Create perspective projection matrix

    # Parameters
    # ----------
    # fovy : float
    # The field of view along the y axis.
    # aspect : float
    # Aspect ratio of the view.
    # znear : float
    # Near coordinate of the field of view.
    # zfar : float
    # Far coordinate of the field of view.

    # Returns
    # -------
    # M : array
    # Perspective projection matrix (4x4).
    #
    @assert znear != zfar
    h = tan(fovy / 360.0 * pi) * znear
    w = h * aspect
    return frustum(-w, w, -h, h, znear, zfar)
end
function lookAt(eyePos::Array{Float32, 1}, lookAt::Array{Float32, 1}, up::Array{Float32, 1})
 
    zaxis = eyePos - lookAt
    zaxis *= 1.0 / norm(zaxis)
    xaxis = cross(up, zaxis)
    xaxis *= 1.0 / norm(xaxis)
    yaxis = cross(zaxis, xaxis)

    viewMatrix = eye(Float32, 4,4)
    viewMatrix[1,1:3] = xaxis
    viewMatrix[2,1:3] = yaxis
    viewMatrix[3,1:3] = zaxis

    viewMatrix * translationMatrix(-eyePos)
end
function rotatationMatrixX(angle::Float32)
    Float32[1 0 0 0;
     0 cos(angle) -sin(angle) 0;
     0 sin(angle) cos(angle) 0;
     0 0 0 1]
end
function rotatationMatrixY(angle::Float32)
    Float32[cos(angle) 0 sin(angle) 0;
     0 1 0 0;
     -sin(angle) 0 cos(angle) 0;
     0 0 0 1]
end
function rotatationMatrixZ(angle::Float32)
    Float32[cos(angle) -sin(angle) 0 0;
     sin(angle) cos(angle) 0 0;
     0 0 1 0;
     0 0 0 1]
end
function rotatationMatrix(angle::Float32, axis)
    x = axis[1]
    y = axis[2]
    z = axis[3]
    a = angle
    m1 = Float32[ x^2 * (1 - cos(a)) + cos(a) , x*y * (1 - cos(a)) - z*sin(a), x*z * (1 - cos(a)) + y*sin(a), 0]
    m2 = Float32[ x*y * (1 - cos(a)) + z*sin(a), y^2 * (1 - cos(a)) + cos(a) , y*z * (1 - cos(a)) - x*sin(a), 0]
    m3 = Float32[ x*z * (1 - cos(a)) - y*sin(a), y*z * (1 - cos(a)) + x*sin(a), z^2 * (1 - cos(a)) + cos(a) , 0]
    
    [m1'; m2'; m3';
     0f0 0f0 0f0 1f0]
end
#intended usage index 1,2,3 = x,y,z
immutable Vec{Cardinality, T}
    v::Array{T, 1}
    function Vec(v::Array{T,1})
        Cardinality == length(v)
        new(v)
    end
end

#typealias Vec32{Cardinality} Vec{Cardinality, Float32}
Vec{T}(v::Array{T, 1}) = Vec{length(v), T}(v)
Vec(v::Real...) = Vec([v...])


Vec32{T <: Real}(v::Array{T,1}) = Vec{length(v), Float32}(float32(v))
Vec32(v::Real...) = Vec32([v...])


export lookAt, computeFOVProjection, computeFOVProjection!, computeOrthographicProjection, computeOrthographicProjection!, translateXMatrix, translationMatrix, pProj

