using GLVisualize, GLAbstraction, GLWindow, GeometryTypes, Colors
using Reactive
w = glscreen()
@async renderloop(w)


function GLAbstraction.translationmatrix(b)
    const_lift(b) do b
        m = minimum(b)
        w = widths(b)
        T = eltype(w)
        # make code work also for N == 2
        w3 = ndims(w) > 2 ?  w[3] : one(T)
        m3 = ndims(m) > 2 ? m[3] : zero(T)

        Mat4f0( # always return float32 matrix
            (w[1], 0   , 0 , 0),
            (0   , w[2], 0 , 0),
            (0   , 0   , w3, 0),
            (m[1], m[2], m3, 1),
        )
    end
end

layout(b, composable...) =  layout(b, composable)
function layout(b, composables::Union{Tuple, Vector})
    trans = translationmatrix(b)
    map(composables) do composable
        GLAbstraction.transform!(composable, trans)
        composable
    end
end

area_trans = translationmatrix(w.area)
empty!(w)
view(layout(w.area, visualize(SimpleRectangle(0f0,0f0,1f0,1f0)))..., camera=:fixed_pixel)
area_trans

function subwin(N, i, frame)
    hframe = frame/2.
    n = (1.0/N)
    y = ((i-1) * n) + hframe
    SimpleRectangle{Float32}(hframe,y,1-frame,n-frame)
end
areas = [subwin(10, i, 0.05) for i=1:10]
pos = map(x-> Point2f0(x.x, x.y), areas)
scale = map(x-> Vec2f0(x.w, x.h), areas)
view(layout(w.area, visualize((Rectangle, pos), scale=scale, color=RGBA{Float32}(1,1,1,1)))..., camera=:fixed_pixel)
pop!(w.renderlist[1])


# p[i] is the column of the queen on ith row (must be a permutation of 0 until n)
