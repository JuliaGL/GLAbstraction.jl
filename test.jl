using GLVisualize, GeometryTypes, Colors, GLAbstraction, ModernGL
w,r=glscreen()
function plot(m)
    srand(17)
    x = Context[visualize(rand(Point2f0, 4)*150, :lines) for _=1:15]
    view(visualize(x), method=:orthographic_pixel)
end

#plot(5)
function plot2(N)
    points = [Point2f0(offset, sin(offset/80)*100) for offset=linspace(0,1000, 4*N)]
    indices = [range(i,4) for i=1:4:(4*N)]
    robj   = visualize(points, :lines, indices=indices)
    view(visualize((Circle(Point2f0(0), 5f0), points)), method=:orthographic_pixel)
    view(robj, method=:orthographic_pixel)
end
plot2(3)
r()
