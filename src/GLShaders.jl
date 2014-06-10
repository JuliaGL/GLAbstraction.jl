using GLFW, React, ImmutableArrays, ModernGL, GLUtil

function createWindow(name::Symbol, w, h)
	GLFW.WindowHint(GLFW.SAMPLES, 4)
	#GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
	#GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
	#GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)
	#GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)

	window = GLFW.CreateWindow(w, h, string(name))
	GLFW.MakeContextCurrent(window)
end



GLFW.Init()


createWindow(:lol, 10, 10)

cam = OrthogonalCamera()
immutable GLSLVariable
	name::ASCIIString
	location::GLint
	typ::GLenum
end
flatshader = GLProgram("/home/s/.julia/v0.3/GLWindow/src/flatShader")
uniformLength = glGetProgramiv(flatshader.id, GL_ACTIVE_UNIFORMS)
attributeLength = glGetProgramiv(flatshader.id, GL_ACTIVE_ATTRIBUTES)
uniforms = Array(GLUniform, uniformLength)
attributes = Array(GLUniform, attributeLength)

glGetActiveAttrib(programID::GLuint, index::Integer) = GLSLVariable(glGetActiveAttrib(programID, index)...)
glGetActiveUniform(programID::GLuint, index::Integer) = GLSLVariable(glGetActiveAttrib(programID, index)...)

for i::GLint=0:uniformLength-1
	uniforms[i+1] = glGetActiveAttrib(flatshader.id, i)
	println(uniforms[i+1])
end

for i::GLint=0:attributeLength-1
	attributes[i+1] = glGetActiveAttrib(flatshader.id, i)
	println(uniforms[i+1])
end
