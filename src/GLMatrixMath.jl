using ImmutableArrays


function orthographicprojection{T}(
                        left::T,   right::T,
                       bottom::T, top::T,
                       znear::T,  zfar::T)

    @assert right  != left 
    @assert bottom != top  
    @assert znear  != zfar 

    matrix = zeros(T, 4,4)

    matrix[1,1] = 2.0/(right-left)
    matrix[1,4] = -(right+left)/(right-left)
    matrix[2,2] = 2.0/(top-bottom)
    matrix[2,4] = -(top+bottom)/(top-bottom)
    matrix[3,3] = -2.0/(zfar-znear)
    matrix[3,4] = -(zfar+znear)/(zfar-znear)
    matrix[4,4] = 1.0
    Matrix4x4{T}(matrix)
end

translateXMatrix{T}(x::T) = translationMatrix( Vector3{T}(x, 0, 0))
translateYMatrix{T}(y::T) = translationMatrix( Vector3{T}(0, y, 0))
translateZMatrix{T}(z::T) = translationMatrix( Vector3{T}(0, 0, z))

function translationMatrix{T}(translation::Vector3{T})
    result          = eye(T, 4, 4)
    result[1:3,4]   = translation

    return Matrix4x4{T}(result)
end


function frustum{T}(left::T, right::T, bottom::T, top::T, znear::T, zfar::T)
    # Create view frustum

    # Parameters
    # ----------
    # left : float
    #     Left coordinate of the field of view.
    # right : float
    #     Left coordinate of the field of view.
    # bottom : float
    #     Bottom coordinate of the field of view.
    # top : float
    #     Top coordinate of the field of view.
    # znear : float
    #     Near coordinate of the field of view.
    # zfar : float
    #     Far coordinate of the field of view.

    # Returns
    # -------
    # M : array
    #     View frustum matrix (4x4).
    
    @assert right != left
    @assert bottom != top
    @assert znear != zfar

    M = zeros(T, 4, 4)
    M[1, 1] = +2.0 * znear / (right - left)
    M[3, 1] = (right + left) / (right - left)
    M[2, 2] = +2.0 * znear / (top - bottom)
    M[4, 2] = (top + bottom) / (top - bottom)
    M[3, 3] = -(zfar + znear) / (zfar - znear)
    M[4, 3] = -2.0 * znear * zfar / (zfar - znear)
    M[3, 4] = -1.0
    return Matrix4x4{T}(M)
end

function perspectiveprojection{T}(fovy::T, aspect::T, znear::T, zfar::T)
    # Create perspective projection matrix

    # Parameters
    # ----------
    # fovy : float
    #     The field of view along the y axis.
    # aspect : float
    #     Aspect ratio of the view.
    # znear : float
    #     Near coordinate of the field of view.
    # zfar : float
    #     Far coordinate of the field of view.

    # Returns
    # -------
    # M : array
    #     Perspective projection matrix (4x4).
    # 
    @assert znear != zfar
    h = tan(fovy / 360.0 * pi) * znear
    w = h * aspect
    return frustum{T}(-w, w, -h, h, znear, zfar)
end
function lookat{T}(eyePos::Vector3{T}, lookAt::Vector3{T}, up::Vector3{T}) 
 
    zaxis  = eyePos - lookAt
    zaxis  *= 1.0 / norm(zaxis)
    xaxis  = cross(up, zaxis)
    xaxis  *= 1.0 / norm(xaxis)
    yaxis  = cross(zaxis, xaxis)

    viewMatrix = eye(Float32, 4,4)
    viewMatrix[1,1:3]  = xaxis
    viewMatrix[2,1:3]  = yaxis
    viewMatrix[3,1:3]  = zaxis

    Matrix4x4(viewMatrix) * translationMatrix(-eyePos)
end
function rotatationMatrixX{T}(angle::T)
    Matrix4x4{T}(
        Vector4{T}(1, 0, 0, 0),
        Vector4{T}(0, cos(angle), -sin(angle), 0),
        Vector4{T}(0, sin(angle), cos(angle), 0),
        Vector4{T}(0, 0, 0, 1))
end
function rotatationMatrixY{T}(angle::T)
    Matrix4x4{T}(
        Vector4{T}(cos(angle), 0, sin(angle), 0),
        Vector4{T}(0, 1, 0, 0),
        Vector4{T}(-sin(angle), 0, cos(angle), 0),
        Vector4{T}(0, 0, 0, 1))
end
function rotatationMatrixZ{T}(angle::T)
    Matrix4x4{T}(
        Vector4{T}(cos(angle), -sin(angle), 0, 0),
        Vector4{T}(sin(angle), cos(angle), 0,  0),
        Vector4{T}(0, 0, 1, 0),
        Vector4{T}(0, 0, 0, 1))
end
function rotatationMatrix{T}(angle::T, axis::Vector3{T})
    x = axis[1]
    y = axis[2]
    z = axis[3]
    a = angle
    m1 = Vector4{T}( x^2 * (1 - cos(a)) + cos(a)  ,  x*y * (1 - cos(a)) - z*sin(a),  x*z * (1 - cos(a)) + y*sin(a), 0)
    m2 = Vector4{T}( x*y * (1 - cos(a)) + z*sin(a),  y^2 * (1 - cos(a)) + cos(a)  ,  y*z * (1 - cos(a)) - x*sin(a), 0)
    m3 = Vector4{T}( x*z * (1 - cos(a)) - y*sin(a),  y*z * (1 - cos(a)) + x*sin(a),  z^2 * (1 - cos(a)) + cos(a)  , 0)
    m4 = Vector4{T}(0, 0, 0, 1)
    Matrix4x4(m1, m2, m3, m4)
end



export lookAt, computeFOVProjection, computeFOVProjection!, computeOrthographicProjection, computeOrthographicProjection!, translateXMatrix, translationMatrix, pProj
