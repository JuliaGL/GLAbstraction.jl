using GLVisualize, GeometryTypes, Colors, GLAbstraction
w,r=glscreen()
function plot(m)
    srand(17)
    x = Context[visualize(rand(Point2f0, 4)*150, :lines) for _=1:15]
    view(visualize(x), method=:orthographic_pixel)
end
plot(5)
r()
