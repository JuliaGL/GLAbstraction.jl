using ModernGL, GLPlot, GLAbstraction, GLWindow, GLFW

window = createwindow("test", 1000, 800, windowhints=[(GLFW.SAMPLES, 4), (GLFW.DEPTH_BITS, 16), (GLFW.STENCIL_BITS, 16)])
const cam = Cam(window.inputs, Vec3(2.0, 0, 0))

const sourcedir = Pkg.dir()*"/GLPlot/src/"
const shaderdir = sourcedir*"shader/"

shader = TemplateProgram(shaderdir*"standard.vert", shaderdir*"phongblinn.frag")

const vertexes, uv, normals, indexes = gencubenormals(Vec3(0,0,0), Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0,0,1))

obj = RenderObject([
	:vertex         => GLBuffer(vertexes),
	:index          => indexbuffer(indexes),
	:normal  		=> GLBuffer(normals),
	:projection     => cam.projection,
	:view           => cam.view,
	:normalmatrix   => cam.normalmatrix,
	:light_position => Vec3(20, 20, -20)
], shader)

prerender!(obj, glEnable, GL_DEPTH_TEST)
postrender!(obj, render, obj.vertexarray)




glStencilFunc(GL_ALWAYS, 1, 0xFF);
glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
glStencilMask(0xFF);

glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
glDepthMask(GL_FALSE);


glClearColor(1,1,1,1)
while !GLFW.WindowShouldClose(window.glfwWindow)
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)




  render(obj)



  yield() # this is needed for react to work
  GLFW.SwapBuffers(window.glfwWindow)
  GLFW.PollEvents()
end
GLFW.Terminate()
