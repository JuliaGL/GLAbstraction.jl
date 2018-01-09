function scalematrix(s::Vec{3, T}) where T
    T0, T1 = zero(T), one(T)
    Mat{4}(
        s[1],T0,  T0,  T0,
        T0,  s[2],T0,  T0,
        T0,  T0,  s[3],T0,
        T0,  T0,  T0,  T1,
    )
end

translationmatrix_x(x::T) where {T} = translationmatrix(Vec{3, T}(x, 0, 0))
translationmatrix_y(y::T) where {T} = translationmatrix(Vec{3, T}(0, y, 0))
translationmatrix_z(z::T) where {T} = translationmatrix(Vec{3, T}(0, 0, z))

function translationmatrix(t::Vec{3, T}) where T
    T0, T1 = zero(T), one(T)
    Mat{4}(
        T1,  T0,  T0,  T0,
        T0,  T1,  T0,  T0,
        T0,  T0,  T1,  T0,
        t[1],t[2],t[3],T1,
    )
end

rotate(angle::T, axis::Vec{3, T}) where {T} = rotationmatrix4(Quaternions.qrotation(convert(Array, axis), angle))
rotate(::Type{T}, angle::Number, axis::Vec{3}) where {T} = rotate(T(angle), convert(Vec{3, T}, axis))

function rotationmatrix_x(angle::T) where T
    T0, T1 = zero(T), one(T)
    Mat{4}(
        T1, T0, T0, T0,
        T0, cos(angle), sin(angle), T0,
        T0, -sin(angle), cos(angle),  T0,
        T0, T0, T0, T1
    )
end
function rotationmatrix_y(angle::T) where T
    T0, T1 = zero(T), one(T)
    Mat{4}(
        cos(angle), T0, -sin(angle),  T0,
        T0, T1, T0, T0,
        sin(angle), T0, cos(angle), T0,
        T0, T0, T0, T1
    )
end
function rotationmatrix_z(angle::T) where T
    T0, T1 = zero(T), one(T)
    Mat{4}(
        cos(angle), sin(angle), T0, T0,
        -sin(angle), cos(angle),  T0, T0,
        T0, T0, T1, T0,
        T0, T0, T0, T1
    )
end
"""
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
"""
function frustum(left::T, right::T, bottom::T, top::T, znear::T, zfar::T) where T
    (right == left || bottom == top || znear == zfar) && return eye(Mat{4,4,T})
    T0, T1, T2 = zero(T), one(T), T(2)
    return Mat{4}(
        T2 * znear / (right - left), T0, T0, T0,
        T0, T2 * znear / (top - bottom), T0, T0,
        (right + left) / (right - left), (top + bottom) / (top - bottom), -(zfar + znear) / (zfar - znear), -T1,
        T0, T0, (-T2 * znear * zfar) / (zfar - znear), T0
    )
end

"""
`proj = perspectiveprojection([T], fovy, aspect, znear, zfar)` defines
a projection matrix with a given angular field-of-view `fovy` along
the y-axis (measured in degrees), the specified `aspect` ratio, and
near and far clipping planes `znear`, `zfar`. Optionally specify the
element type `T` of the matrix.
"""
function perspectiveprojection(fovy::T, aspect::T, znear::T, zfar::T) where T
    (znear == zfar) && error("znear ($znear) must be different from tfar ($zfar)")
    h = T(tan(fovy / 360.0 * pi) * znear)
    w = T(h * aspect)
    return frustum(-w, w, -h, h, znear, zfar)
end
function perspectiveprojection(
        ::Type{T}, fovy::Number, aspect::Number, znear::Number, zfar::Number
    ) where T
    perspectiveprojection(T(fovy), T(aspect), T(znear), T(zfar))
end
"""
`proj = perspectiveprojection([T], rect, fov, near, far)` defines the
projection ratio in terms of the rectangular view size `rect` rather
than the aspect ratio.
"""
function perspectiveprojection(wh::SimpleRectangle, fov::T, near::T, far::T) where T
    perspectiveprojection(fov, T(wh.w/wh.h), near, far)
end
function perspectiveprojection(
        ::Type{T}, wh::SimpleRectangle, fov::Number, near::Number, far::Number
    ) where T
    perspectiveprojection(T(fov), T(wh.w/wh.h), T(near), T(far))
end

"""
`view = lookat(eyeposition, lookat, up)` creates a view matrix with
the eye located at `eyeposition` and looking at position `lookat`,
with the top of the window corresponding to the direction `up`. Only
the component of `up` that is perpendicular to the vector pointing
from `eyeposition` to `lookat` will be used.  All inputs must be
supplied as 3-vectors.
"""
function lookat(eyePos::Vec{3, T}, lookAt::Vec{3, T}, up::Vec{3, T}) where T
    zaxis  = normalize(eyePos-lookAt)
    xaxis  = normalize(cross(up,    zaxis))
    yaxis  = normalize(cross(zaxis, xaxis))
    T0, T1 = zero(T), one(T)
    return Mat{4}(
        xaxis[1], yaxis[1], zaxis[1], T0,
        xaxis[2], yaxis[2], zaxis[2], T0,
        xaxis[3], yaxis[3], zaxis[3], T0,
        T0,       T0,       T0,       T1
    ) * translationmatrix(-eyePos)
end
function lookat(::Type{T}, eyePos::Vec{3}, lookAt::Vec{3}, up::Vec{3}) where T
    lookat(Vec{3,T}(eyePos), Vec{3,T}(lookAt), Vec{3,T}(up))
end
function orthographicprojection(wh::SimpleRectangle, near::T, far::T) where T
    orthographicprojection(zero(T), T(wh.w), zero(T), T(wh.h), near, far)
end
function orthographicprojection(
        ::Type{T}, wh::SimpleRectangle, near::Number, far::Number
    ) where T
    orthographicprojection(wh, T(near), T(far))
end

function orthographicprojection(
        left  ::T, right::T,
        bottom::T, top  ::T,
        znear ::T, zfar ::T
    ) where T
    (right==left || bottom==top || znear==zfar) && return eye(Mat{4,4,T})
    T0, T1, T2 = zero(T), one(T), T(2)
    Mat{4}(
        T2/(right-left), T0, T0,  T0,
        T0, T2/(top-bottom), T0,  T0,
        T0, T0, -T2/(zfar-znear), T0,
        -(right+left)/(right-left), -(top+bottom)/(top-bottom), -(zfar+znear)/(zfar-znear), T1
    )
end
function orthographicprojection(::Type{T},
        left  ::Number, right::Number,
        bottom::Number, top  ::Number,
        znear ::Number, zfar ::Number
    ) where T
    orthographicprojection(
        T(left),   T(right),
        T(bottom), T(top),
        T(znear),  T(zfar)
    )
end

import Base: (*)
function (*)(q::Quaternions.Quaternion{T}, v::Vec{3, T}) where T
    t = T(2) * cross(Vec(q.v1, q.v2, q.v3), v)
    v + q.s * t + cross(Vec(q.v1, q.v2, q.v3), t)
end
function Quaternions.qrotation(axis::Vec{3, T}, theta::T) where T<:Real
    u = normalize(axis)
    s = sin(theta/2)
    Quaternions.Quaternion(cos(theta/2), s*u[1], s*u[2], s*u[3], true)
end

mutable struct Pivot{T}
    origin      ::Vec{3, T}
    xaxis       ::Vec{3, T}
    yaxis       ::Vec{3, T}
    zaxis       ::Vec{3, T}
    rotation    ::Quaternions.Quaternion
    translation ::Vec{3, T}
    scale       ::Vec{3, T}
end

GeometryTypes.origin(p::Pivot) = p.origin

rotationmatrix4(q::Quaternions.Quaternion{T}) where {T} = Mat4{T}(q)

function (::Type{M})(q::Quaternions.Quaternion) where M <: Mat4
    T = eltype(M)
    sx, sy, sz = 2q.s*q.v1,  2q.s*q.v2,   2q.s*q.v3
    xx, xy, xz = 2q.v1^2,    2q.v1*q.v2,  2q.v1*q.v3
    yy, yz, zz = 2q.v2^2,    2q.v2*q.v3,  2q.v3^2
    T0, T1 = zero(T), one(T)
    Mat{4}(
        T1-(yy+zz), xy+sz,      xz-sy,      T0,
        xy-sz,      T1-(xx+zz), yz+sx,      T0,
        xz+sy,      yz-sx,      T1-(xx+yy), T0,
        T0,         T0,         T0,         T1
    )
end

function (::Type{M})(q::Quaternions.Quaternion) where M <: Mat3
    T = eltype(M)
    sx, sy, sz = 2q.s*q.v1, 2q.s*q.v2,  2q.s*q.v3
    xx, xy, xz = 2q.v1^2,   2q.v1*q.v2, 2q.v1*q.v3
    yy, yz, zz = 2q.v2^2,   2q.v2*q.v3, 2q.v3^2
    T0, T1 = zero(T), one(T)
    Mat{3}(
        T1-(yy+zz), xy+sz,      xz-sy,
        xy-sz,      T1-(xx+zz), yz+sx,
        xz+sy,      yz-sx,      T1-(xx+yy)
    )
end
function transformationmatrix(p::Pivot)
    translationmatrix(p.origin) * #go to origin
    rotationmatrix4(p.rotation) * #apply rotation
    translationmatrix(-p.origin)* # go back to origin
    translationmatrix(p.translation) #apply translation
end

function transformationmatrix(translation, scale)
    T = eltype(translation)
    T0, T1 = zero(T), one(T)
    Mat{4}(
        scale[1],T0,  T0,  T0,
        T0,  scale[2],T0,  T0,
        T0,  T0,  scale[3],T0,
        translation[1],translation[2],translation[3], T1
    )
end

function transformationmatrix(translation, scale, rotation::Quaternions.Quaternion)
    T = eltype(translation)
    trans_scale = transformationmatrix(translation, scale)
    rotation = Mat4f0(rotation)
    trans_scale*rotation
end
function transformationmatrix(
        translation, scale, rotation::Vec{3,T}, up = Vec{3,T}(0,0,1)
    ) where T
    q = rotation(rotation, up)
    transformationmatrix(translation, scale, q)
end

#Calculate rotation between two vectors
function rotation(u::Vec{3, T}, v::Vec{3, T}) where T
    # It is important that the inputs are of equal length when
    # calculating the half-way vector.
    u, v = normalize(u), normalize(v)
    # Unfortunately, we have to check for when u == -v, as u + v
    # in this case will be (0, 0, 0), which cannot be normalized.
    if (u == -v)
        # 180 degree rotation around any orthogonal vector
        other = (abs(dot(u, Vec{3, T}(1,0,0))) < 1.0) ? Vec{3, T}(1,0,0) : Vec{3, T}(0,1,0)
        return Quaternions.qrotation(normalize(cross(u, other)), T(180))
    end
    half = normalize(u+v)
    return Quaternions.Quaternion(dot(u, half), cross(u, half)...)
end
