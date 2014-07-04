using GLFW, React, ImmutableArrays, ModernGL, GLUtil, GLWindow


GLFW.Init()
GLFW.WindowHint(GLFW.SAMPLES, 4)

GLFW.WindowHint(GLFW.OPENGL_DEBUG_CONTEXT, 1)

window = GLFW.CreateWindow(10,10, "lol, ey")
GLFW.MakeContextCurrent(window)


cam = OrthogonalCamera()
immutable GLSLVariable
	name::ASCIIString
	location::GLint
	typ::GLenum
end


flatshader 		  = GLProgram("/home/s/.julia/v0.3/GLPlot/src/volumeShader")
uniformLength 	= glGetProgramiv(flatshader.id, GL_ACTIVE_UNIFORMS)
attributeLength = glGetProgramiv(flatshader.id, GL_ACTIVE_ATTRIBUTES)

uniforms 		= Array(GLSLVariable, uniformLength)

if uniformLength > 0
	for i::GLint=0:uniformLength-1
		uniforms[i+1] = GLSLVariable(glGetActiveUniform(flatshader.id, i)...)
		println(uniforms[i+1])
	end
end
if attributeLength > 0
	attributes 		= Array(GLSLVariable, attributeLength)
	for i::GLint=0:attributeLength-1
		attributes[i+1] = GLSLVariable(glGetActiveAttrib(flatshader.id, i)...)
		println(attributes[i+1])
	end
end
