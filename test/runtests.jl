using GLAbstraction, GeometryTypes, ModernGL, Compat
using GLFW # <- need GLFW for context initialization.. Hopefully replaced by some native initialization
using Base.Test

# initilization,  with GLWindow this reduces to "createwindow("name", w,h)"
GLFW.Init()
GLFW.WindowHint(GLFW.SAMPLES, 4)

@osx_only begin
	GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
	GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
	GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)
	GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
end
window = GLFW.CreateWindow(512,512, "test")
GLFW.MakeContextCurrent(window)
GLFW.ShowWindow(window)

init_glutils()


# Test for creating a GLBuffer with a 1D Julia Array
# You need to supply the cardinality, as it can't be inferred
# indexbuffer is a shortcut for GLBuffer(GLUint[0,1,2,2,3,0], 1, buffertype = GL_ELEMENT_ARRAY_BUFFER)
indexes = indexbuffer(GLuint[0,1,2])
# Test for creating a GLBuffer with a 1D Julia Array of Vectors
#v = Vec2f[Vec2f(0.0, 0.5), Vec2f(0.5, -0.5), Vec2f(-0.5,-0.5)]

v = Vector2{Float32}[Vector2{Float32}(0.0, 0.5), Vector2{Float32}(0.5, -0.5), Vector2{Float32}(-0.5,-0.5)]

verts = GLBuffer(v)
# lets define some uniforms
# uniforms are shader variables, which are supposed to stay the same for an entire draw call

const triangle = RenderObject(
	@compat(Dict(
		:vertex => verts,
		:name_doesnt_matter_for_indexes => indexes
	)),
	TemplateProgram(file"test.vert", file"test.frag"))

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


