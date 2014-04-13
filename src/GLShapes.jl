
#Rectangle{T <: Real}(Array{T, 1}; color::GLColor = GLColor(0,0,0,1), texture=Texture(), boder = 0f0) =

function Rectangle(x::Real, y::Real, width::Real, height::Real; 
        color::GLColor = GLColor(0,0,0), border::Float32 = 0.0f0, texture::Union(Texture, ASCIIString) = Texture())   
    if isa(texture, ASCIIString)
        texture = Texture(texture)
    end
    Rectangle(float32(x), float32(y), float32(width), float32(height), color, border, texture)
end
function Rectangle(t::Union(Texture, ASCIIString))

    if isa(t, ASCIIString)
        t = Texture(t)
    end
    Rectangle(0f0, 0f0, float32(t.width), float32(t.height), color=GLColor(0,0,0,0), border=0f0, texture=t)
end

# #in developement
# immutable Polygon{T} <: Shape
#     points::Array{T, 1}
#     boundingBox::Rectangle
#     gl::RenderStyle
#     function Polygon(polygon::Array{T, 1}, color::GLColor, border::Float32, texture::Texture)
#         @assert length(polygon) % 2 == 0
#         boundingBox = Rectangle(-Inf32, -Inf32, Inf32, Inf32)
#         for i=1:length(polygon) - 1
#             x = polygon[i]
#             y = polygon[i + 1]
#             if x < boundingBox.width
#                 boundingBox.width = x
#             elseif x > boundingBox.x
#                 boundingBox.x = x
#             end
#             if y < boundingBox.height
#                 boundingBox.height = y
#             elseif y > boundingBox.y
#                 boundingBox.y = y
#             end
#         end
#         #gl = RenderStyle(color, border, texture, GLVertexArray(["position" => polygon], flatshader, primitiveMode = GL_TRIANGLE_FAN))
#         #new(polygon, boundingBox, gl)
#     end
# end


# function inside(polygon::Polygon, x::Real, y::Real)
#     a = polygon.points
#     c = false
#     i = length(a) - 1
#     for (x1, y1) in a
#         (x0, y0) =  a[i % length(a) + 1]
#         if (y1 < y) != (y0 > y) &&
#             (x < (x0-x1) * (y-y1) / (y0-y1) + x1)
#             c = ~c
#         end 
#         i += 1
#     end
#     return c
# end

function inside(circle::Circle, x::Real, y::Real)
    xD = abs(circle.x - x) - circle.r 
    yD = abs(circle.y - y) - circle.r
    xD <= 0 && yD <= 0
end

function inside(rect::Rectangle, x::Real, y::Real)
    rect.x <= x && rect.y <= y && rect.x + rect.w >= x && rect.y + rect.h >= y 
end

function createQuad{T <: Real}(x::T, y::T, width::T, height::T)
    v = T[
    x, y,
    x, y + height,
    x + width,  y,
    x + width,  y,
    x, y + height,
    x+ width, y + height]
end

function createQuadUV()
    v = float32([
    0, 1,
    0, 0,
    1, 1,
    1, 1,
    0, 0,
    1, 0])
end

function createCircle(r, x, y, amount)
    slice = (2*pi) / amount
    result = float32([x,y])
    for i = 0:amount-1
        angle = slice * i
        push!(result, float32(x + r * cos(angle)), float32(y + r * sin(angle)))
    end
    push!(result, float32(x + r * cos(0)), float32(y + r * sin(0)))
    return result
end
function createQuadStrip(x::GLfloat, y::GLfloat, spacing::GLfloat, width::GLfloat, height::GLfloat, amount::Int)
    vertices         = Array(GLfloat, amount * 2 * 6)
    for i = 1:amount
        vTemp = createQuad(x + ((width+ spacing) * (i-1)) , y, width, height)
        vertices[(i-1)*6*2 + 1:i*6*2] = vTemp
    end
    return vertices
end
render(shape::Rectangle) = render(shape, GLOBAL_ORTHOGONAL_CAM)
function render(shape::Rectangle, cam::Camera)
    glDisable(GL_DEPTH_TEST)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    vertArray = RECTANGLE_VERT_ARRAY

    glUniform1f(glGetUniformLocation(vertArray.program.id, "textureOn"), 0.0f0)
    render(shape.style)
    render("mvp", 
        cam.viewProjMat * float32([shape.w 0 0 shape.x ; 0 shape.h 0 shape.y ; 0 0 1 0 ; 0 0 0 1]),
        vertArray.program.id)
    render(vertArray)
end

function initShapes()
    flatShader              = GLProgram(rootFolder*"shader/flatShader")
    RECTANGLE_VERT_ARRAY    = GLVertexArray(["position" => createQuad(0f0, 0f0, 1f0, 1f0), "uv" => createQuadUV()], flatShader, primitiveMode = GL_TRIANGLES)
end
initAfterContextCreation(initShapes)

export createQuad, createUV, createCircle, createQuadStrip
