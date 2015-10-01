using GLAbstraction, GeometryTypes, ModernGL, Compat, FileIO, GLFW
function is_ci()
	get(ENV, "TRAVIS", "") == "true" || get(ENV, "APPVEYOR", "") == "true" || get(ENV, "CI", "") == "true"
end

if !is_ci() # only do test if not CI... this is for automated testing environments which fail for OpenGL stuff, but I'd like to test if at least including works

# initilization,  with GLWindow this reduces to "createwindow("name", w,h)"
GLFW.Init()
GLFW.WindowHint(GLFW.SAMPLES, 4)

GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)
GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)

window = GLFW.CreateWindow(512,512, "test")
GLFW.MakeContextCurrent(window)
GLFW.ShowWindow(window)

# Test for creating a GLBuffer with a 1D Julia Array
# You need to supply the cardinality, as it can't be inferred
# indexbuffer is a shortcut for GLBuffer(GLUInt[0,1,2,2,3,0], 1, buffertype = GL_ELEMENT_ARRAY_BUFFER)
indexes = indexbuffer(GLuint[0,1,2])
# Test for creating a GLBuffer with a 1D Julia Array of Vectors
#v = Vec2f[Vec2f(0.0, 0.5), Vec2f(0.5, -0.5), Vec2f(-0.5,-0.5)]

v = Vec2f0[Vec2f0(0.0, 0.5), Vec2f0(0.5, -0.5), Vec2f0(-0.5,-0.5)]

verts = GLBuffer(v)
# lets define some uniforms
# uniforms are shader variables, which are supposed to stay the same for an entire draw call

const triangle = RenderObject(
	Dict(
		:vertex => verts,
		:name_doesnt_matter_for_indexes => indexes
	),
	TemplateProgram(load("test.vert"), load("test.frag"))
)

postrender!(triangle, render, triangle.vertexarray)

glClearColor(0,0,0,1)
while !GLFW.WindowShouldClose(window)
  	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
	render(triangle)
	GLFW.SwapBuffers(window)
	GLFW.PollEvents()
	sleep(0.01)
end

GLFW.Terminate()

end
