using ModernGL, GLWindow, GLUtil


const window = createWindow(:Example, 512, 512)


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
	[:position => GLBuffer(GLfloat[0.0, 0.5, 0.5, -0.5, -0.5,-0.5], 2),], 
	GLProgram(vsh, fsh, "simpleshader"))

global t = 0

function test(x::RenderObject)
	global t
	t += 1
	glClearColor(0.0, 0.0, 0.5 * (1 + sin(t * 0.02)), 1.0)
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

	programID = x.vertexArray.program.id
	glUseProgram(programID)
	render(x.uniforms)
	glBindVertexArray(x.vertexArray.id)
	glDrawArrays(GL_TRIANGLES, 0, x.vertexArray.length)
end

glDisplay(:triangle, FuncWithArgs(test, (triangle,)))

renderloop(window)