
function isinside(circle::Circle, x::Real, y::Real)
    xD = abs(circle.x - x) - circle.r 
    yD = abs(circle.y - y) - circle.r
    xD <= 0 && yD <= 0
end

function isinside(rect::Rectangle, x::Real, y::Real)
    rect.x <= x && rect.y <= y && rect.x + rect.w >= x && rect.y + rect.h >= y 
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
