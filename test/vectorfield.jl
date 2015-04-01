using GLAbstraction, GLWindow, ModernGL, GeometryTypes, ColorTypes, FixedPointNumbers

rgbaU8(r,g,b,a) = RGBA{Ufixed8}(r,g,b,a)

const window = createwindow("Vectorfield", 1024, 1024, debugging=false)

const parameters = [
    (GL_TEXTURE_MIN_FILTER, GL_NEAREST),
    (GL_TEXTURE_MAG_FILTER, GL_NEAREST),
    (GL_TEXTURE_WRAP_S,  GL_CLAMP_TO_EDGE),
    (GL_TEXTURE_WRAP_T,  GL_CLAMP_TO_EDGE),
    (GL_TEXTURE_WRAP_R,  GL_CLAMP_TO_EDGE),
  ]



function toopengl(
            vectorfield::Array{Vector3{Float32}, 3}; 
            xrange=(-1,1), yrange=(-1,1), zrange=(-1,1), colorrange=(-1,1),
            lightposition=Vec3(20, 20, -20), camera=window.perspectivecam, colormap=RGBA{Ufixed8}[rgbaU8(1,0,0,1), rgbaU8(1,1,0,1), rgbaU8(0,1,0,1)], rest...)

  const cubez = gencubenormals(Vec3(0), Vec3(0.009, 0, 0), Vec3(0,0.009, 0), Vec3(0,0,0.09))

  data = merge(Dict(
    :vectorfield    => Texture(vectorfield, parameters=parameters),

    :cube_from      => Vec3(first(xrange), first(yrange), first(zrange)),
    :cube_to        => Vec3(last(xrange),  last(yrange),  last(zrange)),
    :color_range    => Vec2(first(colorrange), last(colorrange)),
    :colormap       => Texture(colormap),
    :projection     => camera.projection,
    :view           => camera.view,
    :normalmatrix   => camera.normalmatrix,
    :light_position => lightposition,
    :modelmatrix    => eye(Mat4),
    :vertex         => GLBuffer(cubez[1]),
    :index          => indexbuffer(cubez[4]),
    :normal_vector  => GLBuffer(cubez[3])

  ), Dict{Symbol, Any}(rest))
  # Depending on what the is, additional values have to be calculated
  program = TemplateProgram(file"vectorfield.vert", file"vectorfield.frag", attributes=data)

  obj     = instancedobject(data, length(vectorfield), program, GL_TRIANGLES)
  prerender!(obj, glEnable, GL_DEPTH_TEST, glDepthFunc, GL_LEQUAL, glDisable, GL_CULL_FACE, enabletransparency)
  obj
end
function funcy(x,y,z)
    Vec3(sin(x),cos(y),sin(z))
end

N = 20
directions  = Vec3[funcy(4x/N,4y/N,4z/N) for x=1:N,y=1:N, z=1:N]
vectorfiledRO  = toopengl(directions)


while !GLFW.WindowShouldClose(window.nativewindow)

    yield()
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    render(vectorfiledRO)
    GLFW.SwapBuffers(window.nativewindow)
    GLFW.PollEvents()
    
end
GLFW.Terminate()
