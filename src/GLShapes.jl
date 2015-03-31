
function isinside(circle::Circle, x::Real, y::Real)
    xD = abs(circle.x - x) - circle.r 
    yD = abs(circle.y - y) - circle.r
    xD <= 0 && yD <= 0
end

function isinside(rect::Rectangle, x::Real, y::Real)
    rect.x <= x && rect.y <= y && rect.x + rect.w >= x && rect.y + rect.h >= y 
end

function genquad{T <: Real}(x::T, y::T, width::T, height::T)
    v = Vector2{T}[
        Vector2{T}(x, y),
        Vector2{T}(x, y + height),
        Vector2{T}(x+ width, y + height),
        Vector2{T}(x + width,  y)
    ]

    uv = Vector2{T}[
        Vector2{T}(0, 0),
        Vector2{T}(0, 1),
        Vector2{T}(1, 1),
        Vector2{T}(1, 0)
    ]

    indexes = GLuint[0,1,2,2,3,0]
    v, uv , indexes
end
genquad(x::Real) = genquad(x, x)
genquad(x::Real, y::Real) = genquad(0, 0, promote(x, y)...)
genquad(x::Real, y::Real, width::Real, height::Real) = genquad(promote(x, x, width, height)...)

function genquad{T}(downleft::Vector3{T}, width::Vector3{T}, height::Vector3{T})
    v = Vector3{T}[
        downleft,
        downleft + height,
        downleft + width + height,
        downleft + width 
    ]
    uv = Vector2{T}[
        Vector2{T}(0, 1),
        Vector2{T}(0, 0),
        Vector2{T}(1, 0),
        Vector2{T}(1, 1)
    ]
    indexes = GLuint[0,1,2,2,3,0]

    normal = normalize(cross(width, height))
    (v, uv, Vector3{T}[normal for i=1:4], indexes)
end

function gencircle(r, x, y, amount)
    slice = (2*pi) / amount
    result = GLfloat[x,y]
    for i = 0:amount-1
        angle = slice * i
        push!(result, Float32(x + r * cos(angle)), Float32(y + r * sin(angle)))
    end
    push!(result, Float32(x + r * cos(0)), Float32(y + r * sin(0)))
    return result
end
function genquadstrip(x::GLfloat, y::GLfloat, spacing::GLfloat, width::GLfloat, height::GLfloat, amount::Int)
    vertices         = Array(GLfloat, amount * 2 * 6)
    for i = 1:amount
        vTemp = createQuad(x + ((width+ spacing) * (i-1)) , y, width, height)
        vertices[(i-1)*6*2 + 1:i*6*2] = vTemp
    end
    return vertices
end
# I just just create a meshtype, but I can't use the one from meshes, as its not parametric, and doesn't have variable vertex attributes
# I deal with it later...
function mergemesh{T}(a::(Vector{Vector3{T}}, Vector{Vector2{T}}, Vector{Vector3{T}}, Vector{GLuint}), 
    (b::(Vector{Vector3{T}}, Vector{Vector2{T}}, Vector{Vector3{T}}, Vector{GLuint}))...)
    v  = a[1]
    uv = a[2]
    n  = a[3]
    i  = a[4]
    for elem in b
        append!(i, elem[4] + length(v))
        append!(v, elem[1])
        append!(uv, elem[2])
        append!(n, elem[3])
    end
    
    return (v, uv, n, i)
end

function gencubenormals{T}(base_edge::Vector3{T}, wx::Vector3{T}, wy::Vector3{T}, hz::Vector3{T})
    mergemesh( 
            genquad(base_edge + hz, wx,wy), # Top
            genquad(base_edge, wy, wx), # Bottom
            genquad(base_edge + wx, wy, hz), # Right
            genquad(base_edge, hz, wy), # Left
            genquad(base_edge, wx, hz), # Back
            genquad(base_edge + wy, hz, wx) #Front
        )

end
function gencube(x,y,z)
    vertices = Float32[
    0.0, 0.0,  z,
     x, 0.0,  z,
     x,  y,  z,
    0.0,  y,  z,
    # back
    0.0, 0.0, 0.0,
     x, 0.0, 0.0,
     x,  y, 0.0,
    0.0,  y, 0.0
    ]
    uv = Float32[
    0.0, 0.0,  1.0,
     1.0, 0.0,  1.0,
     1.0,  1.0,  1.0,
    0.0,  1.0,  1.0,
    # back
    0.0, 0.0, 0.0,
     1.0, 0.0, 0.0,
     1.0,  1.0, 0.0,
    0.0,  1.0, 0.0
    ]
    indexes = GLuint[
     #front
     0, 1, 2,
    2, 3, 0,
    # top
    3, 2, 6,
    6, 7, 3,
    # back
    7, 6, 5,
    5, 4, 7,
    # bottom
    4, 5, 1,
    1, 0, 4,
    # left
    4, 0, 3,
    3, 7, 4,
    # right
    1, 5, 6,
    6, 2, 1]
    return (vertices, uv, indexes)
end
