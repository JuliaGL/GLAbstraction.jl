using ModernGL, GLWindow, GLAbstraction, GLFW


const window = createwindow("Example", 512, 512)


const vsh = """
#version 130
in vec2 position;
 
void main() {
	gl_Position = vec4(position, 0.0, 1.0);
}
"""
 
const fsh = """
#version 130
out vec4 outColor;
 
void main() {
	outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
"""

const triangle = RenderObject(
	[:position => GLBuffer(GLfloat[0.0, 0.5, 0.5, -0.5, -0.5,-0.5], 2)], 
	GLProgram(vsh, fsh, "vert", "frag"))
postrender!(triangle, render, triangle.vertexarray)
glClearColor(0, 0, 0, 1)


while !GLFW.WindowShouldClose(window.glfwWindow)

  	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

	render(triangle)
  	
  	GLFW.SwapBuffers(window.glfwWindow)
  	GLFW.PollEvents()
end
GLFW.Terminate()