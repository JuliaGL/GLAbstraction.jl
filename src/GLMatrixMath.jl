function scalematrix{T}(scale::Vector3{T})
    result      = eye(T, 4, 4)
    result[1,1] = scale[1]
    result[2,2] = scale[2]
    result[3,3] = scale[3]

    return Matrix4x4(result)
end


translationmatrix_x{T}(x::T) = translationmatrix( Vector3{T}(x, 0, 0))
translationmatrix_y{T}(y::T) = translationmatrix( Vector3{T}(0, y, 0))
translationmatrix_z{T}(z::T) = translationmatrix( Vector3{T}(0, 0, z))

function translationmatrix{T}(translation::Vector3{T})
    result          = eye(T, 4, 4)
    result[1:3,4]   = translation

    return Matrix4x4(result)
end
function rotate{T}(angle::T, axis::Vector3{T})
    rotationmatrix(qrotation(convert(Array, axis), angle))
end

function rotationmatrix_x{T}(angle::T)
    Matrix4x4{T}(
        Vector4{T}(1, 0, 0, 0),
        Vector4{T}(0, cos(angle), -sin(angle), 0),
        Vector4{T}(0, sin(angle), cos(angle), 0),
        Vector4{T}(0, 0, 0, 1))
end
function rotationmatrix_z{T}(angle::T)
    Matrix4x4{T}(
        Vector4{T}(cos(angle), 0, sin(angle), 0),
        Vector4{T}(0, 1, 0, 0),
        Vector4{T}(-sin(angle), 0, cos(angle), 0),
        Vector4{T}(0, 0, 0, 1))
end
function rotationmatrix_z{T}(angle::T)
    Matrix4x4{T}(
        Vector4{T}(cos(angle), -sin(angle), 0, 0),
        Vector4{T}(sin(angle), cos(angle), 0,  0),
        Vector4{T}(0, 0, 1, 0),
        Vector4{T}(0, 0, 0, 1))
end
#=
function rotationmatrix{T}(angle::T, axis::Vector3{T})
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
=#
#=
    Create view frustum

    Parameters
    ----------
        left : float
         Left coordinate of the field of view.
        right : float
         Left coordinate of the field of view.
        bottom : float
         Bottom coordinate of the field of view.
        top : float
         Top coordinate of the field of view.
        znear : float
         Near coordinate of the field of view.
        zfar : float
         Far coordinate of the field of view.

    Returns
    -------
        M : array
         View frustum matrix (4x4).
=#
function frustum{T}(left::T, right::T, bottom::T, top::T, znear::T, zfar::T)
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
    return Matrix4x4(M)
end
#=
    Create perspective projection matrix

    Parameters
    ----------
    fovy : float
        The field of view along the y axis.
    aspect : float
        Aspect ratio of the view.
    znear : float
        Near coordinate of the field of view.
    zfar : float
        Far coordinate of the field of view.

    Returns
    -------
    M : array
        Perspective projection matrix (4x4).
=#
function perspective(fovyRadians, aspect, zNear, zFar )

    f = tan((( pi/2 ) - ( 0.5f0 * fovyRadians )))
    rangeInv = ( 1.0f / ( zNear - zFar ) )
    return Matrix4x4(
        Vector4( ( f / aspect ), 0.0f, 0.0f, 0.0f ),
        Vector4( 0.0f, f, 0.0f, 0.0f ),
        Vector4( 0.0f, 0.0f, ( ( zNear + zFar ) * rangeInv ), -1.0f ),
        Vector4( 0.0f, 0.0f, ( ( ( zNear * zFar ) * rangeInv ) * 2.0f ), 0.0f )
    );
end
function perspectiveprojection{T}(fovy::T, aspect::T, znear::T, zfar::T)

    @assert znear != zfar
    h = convert(T, tan(fovy / 360.0 * pi) * znear)
    w = convert(T, h * aspect)
    return frustum(-w, w, -h, h, znear, zfar)
end

function orthoInverse( tfrm )
    inv0 = Vector3( tfrm.getCol0().getX(), tfrm.getCol1().getX(), tfrm.getCol2().getX() );
    inv1 = Vector3( tfrm.getCol0().getY(), tfrm.getCol1().getY(), tfrm.getCol2().getY() );
    inv2 = Vector3( tfrm.getCol0().getZ(), tfrm.getCol1().getZ(), tfrm.getCol2().getZ() );
    return Transform3(
        inv0,
        inv1,
        inv2,
        Vector3( ( -( ( inv0 * tfrm.getCol3().getX() ) + ( ( inv1 * tfrm.getCol3().getY() ) + ( inv2 * tfrm.getCol3().getZ() ) ) ) ) )
    );
end
function orthoInverse(mat )

    tfrm = Matrix3x4(
    Vector3(mat.c1[1:3]...),
    Vector3(mat.c2[1:3]...),
    Vector3(mat.c3[1:3]...),
    Vector3(mat.c4[1:3]...))

    inv0 = Vector3( tfrm.c1[1], tfrm.c2[1], tfrm.c3[1] )
    inv1 = Vector3( tfrm.c1[2], tfrm.c2[2], tfrm.c3[2] )
    inv2 = Vector3( tfrm.c1[3], tfrm.c2[3], tfrm.c3[3] )
    return Matrix4x4(
        Vector4(inv0..., 0f0),
        Vector4(inv1..., 0f0),
        Vector4(inv2..., 0f0),
        Vector4( ( -( ( inv0 * tfrm.c4[1] ) + ( ( inv1 * tfrm.c4[2] ) + ( inv2 * tfrm.c4[3] ) ) ) )..., 0f0)
    )
end
export lookAt
function lookAt(eyePos,lookAtPos, upVec )
    v3Y = unit( upVec )
    v3Z = unit( ( eyePos - lookAtPos ) )
    v3X = unit( cross( v3Y, v3Z ) )
    v3Y = cross( v3Z, v3X )
    m4EyeFrame = Matrix4x4( Vector4( v3X..., 0f0), Vector4( v3Y..., 0f0 ), Vector4( v3Z..., 0f0 ), Vector4( eyePos..., 0f0 ) )
    return orthoInverse( m4EyeFrame )
end

function lookat{T}(eyePos::Vector3{T}, lookAt::Vector3{T}, up::Vector3{T})

    zaxis  = unit(eyePos - lookAt)
    xaxis  = unit(cross(up, zaxis))
    yaxis  = unit(cross(zaxis, xaxis))

    viewMatrix = eye(T, 4,4)
    viewMatrix[1,1:3]  = xaxis
    viewMatrix[2,1:3]  = yaxis
    viewMatrix[3,1:3]  = zaxis

    Matrix4x4(viewMatrix) * translationmatrix(-eyePos)
end

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
    Matrix4x4(matrix)
end


import Base: (*)
function (*){T}(q::Quaternion{T}, v::Vector3{T}) 
    t = 2 * cross(Vector3(q.v1, q.v2, q.v3), v)
    v + q.s * t + cross(Vector3(q.v1, q.v2, q.v3), t)
end
function Quaternions.qrotation{T<:Real}(axis::Vector3{T}, theta::T)
    u = unit(axis)
    s = sin(theta/2)
    Quaternion(cos(theta/2), s*u.e1, s*u.e2, s*u.e3, true)
end

immutable Pivot{T}

    origin::Vector3{T}

    xaxis::Vector3{T}
    yaxis::Vector3{T}
    zaxis::Vector3{T}
    
    rotation::Quaternion

    translation::Vector3{T}
    scale::Vector3{T}
    
end
function rotationmatrix4{T}(q::Quaternion{T})
    sx, sy, sz = 2q.s*q.v1, 2q.s*q.v2, 2q.s*q.v3
    xx, xy, xz = 2q.v1^2, 2q.v1*q.v2, 2q.v1*q.v3
    yy, yz, zz = 2q.v2^2, 2q.v2*q.v3, 2q.v3^2

    Matrix4x4([1-(yy+zz) xy-sz xz+sy 0;
        xy+sz 1-(xx+zz) yz-sx 0;
        xz-sy yz+sx 1-(xx+yy) 0;
        0 0 0 1])
end
function transformationmatrix(p::Pivot)
    (
    translationmatrix(p.origin)* #go to origin
        Matrix4x4(rotationmatrix4(p.rotation))*
        #scalematrix(p.scale)*
    translationmatrix(-p.origin)* # go back to origin
    translationmatrix(p.translation)

    ) 
end
#Calculate rotation between two vectors
function rotation{T}(u::Vector3{T}, v::Vector3{T})
    # It is important that the inputs are of equal length when
    # calculating the half-way vector.
    u = unit(u)
    v = unit(v)

    # Unfortunately, we have to check for when u == -v, as u + v
    # in this case will be (0, 0, 0), which cannot be normalized.
    if (u == -v)
        # 180 degree rotation around any orthogonal vector
        other = (abs(dot(u, Vector3{T}(1,0,0))) < 1.0) ? Vector3{T}(1,0,0) : Vector3{T}(0,1,0)
        return qrotation(unit(cross(u, other)), 180)
    end

    half = unit(u + v)
    return Quaternion(dot(u, half), cross(u, half)...)
end


