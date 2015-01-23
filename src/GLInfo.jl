using ModernGL
getnames(check_function::Function) = filter(check_function, uint32(0:65534))

# gets all the names currently boundo to programs
getProgramNames()	  = getnames(glIsProgram)
getShaderNames() 	  = getnames(glIsShader)
getVertexArrayNames() = getnames(glIsVertexArray)

immutable GLProgram 
	id::GLuint
end
# display info for all active uniforms in a program
function getUniformsInfo(p::GLProgram) 
	program = p.id
	# Get uniforms info (not in named blocks)
	@show activeUnif = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)

	for i=0:activeUnif-1
		@show index = glGetActiveUniformsiv(program, i, GL_UNIFORM_BLOCK_INDEX)
		if (index == -1) 
			@show name 		     = glGetActiveUniformName(program, i)	
			@show uniType 	   	 = glGetActiveUniformsiv(program, i, GL_UNIFORM_TYPE)

			@show uniSize 	   	 = glGetActiveUniformsiv(program, i, GL_UNIFORM_SIZE)
			@show uniArrayStride = glGetActiveUniformsiv(program, i, GL_UNIFORM_ARRAY_STRIDE)

			auxSize = 0
			if (uniArrayStride > 0)
				@show auxSize = uniArrayStride * uniSize
			else
				@show auxSize = spGLSLTypeSize[uniType]
			end
		end
	end
	# Get named blocks info
	@show count = glGetProgramiv(program, GL_ACTIVE_UNIFORM_BLOCKS)

	for i=0:count-1 
		# Get blocks name
		@show name 	 		 = glGetActiveUniformBlockName(program, i)
		@show dataSize 		 = glGetActiveUniformBlockiv(program, i, GL_UNIFORM_BLOCK_DATA_SIZE)

		@show index 	 		 = glGetActiveUniformBlockiv(program, i,  GL_UNIFORM_BLOCK_BINDING)
		@show binding_point 	 = glGetIntegeri_v(GL_UNIFORM_BUFFER_BINDING, index)

		@show activeUnif   	 = glGetActiveUniformBlockiv(program, i, GL_UNIFORM_BLOCK_ACTIVE_UNIFORMS)

		indices = zeros(GLuint, activeUnif)
		glGetActiveUniformBlockiv(program, i, GL_UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES, indices)
		@show indices	
		for ubindex in indices
			@show name 		   = glGetActiveUniformName(program, ubindex)
			@show uniType 	   = glGetActiveUniformsiv(program, ubindex, GL_UNIFORM_TYPE)
			@show uniOffset    = glGetActiveUniformsiv(program, ubindex, GL_UNIFORM_OFFSET)
			@show uniSize 	   = glGetActiveUniformsiv(program, ubindex, GL_UNIFORM_SIZE)
			@show uniMatStride = glGetActiveUniformsiv(program, ubindex, GL_UNIFORM_MATRIX_STRIDE)
		end
	end
end


# display the values for uniforms in the default block
function getUniformInfo(p::GLProgram, uniName::Symbol) 
	# is it a program ?
	@show program 				  = p.id
	@show loc 	  				  = glGetUniformLocation(program, uniName)
	@show name, typ, uniform_size = glGetActiveUniform(program, loc)
end


# display the values for a uniform in a named block
function getUniformInBlockInfo(p::GLProgram, 
				blockName, 
				uniName) 

	program = p.id

	@show index = glGetUniformBlockIndex(program, blockName)
	if (index == GL_INVALID_INDEX) 
		println("$uniName is not a valid uniform name in block $blockName")
	end
	@show bindIndex 		= glGetActiveUniformBlockiv(program, index, GL_UNIFORM_BLOCK_BINDING)
	@show bufferIndex 		= glGetIntegeri_v(GL_UNIFORM_BUFFER_BINDING, bindIndex)
	@show uniIndex 			= glGetUniformIndices(program, uniName)
	
	@show uniType 			= glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_TYPE)
	@show uniOffset 		= glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_OFFSET)
	@show uniSize 			= glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_SIZE)
	@show uniArrayStride 	= glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_ARRAY_STRIDE)
	@show uniMatStride 		= glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_MATRIX_STRIDE)
end


# display information for a program's attributes
function getAttributesInfo(p::GLProgram) 

	program = p.id
	# how many attribs?
	@show activeAttr = glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES)
	# get location and type for each attrib
	for i=0:activeAttr-1
		@show name, typ, siz = glGetActiveAttrib(program,	i)
		@show loc = glGetAttribLocation(program, name)
	end
end


# display program's information
function getProgramInfo(p::GLProgram) 
	# check if name is really a program
	@show program = p.id
	# Get the shader's name
	@show shaders = glGetAttachedShaders(program)
	for shader in shaders
		@show info = GLENUM(convert(GLenum, glGetShaderiv(shader, GL_SHADER_TYPE))).name
	end
	# Get program info
	@show info = glGetProgramiv(program, GL_PROGRAM_SEPARABLE)
	@show info = glGetProgramiv(program, GL_PROGRAM_BINARY_RETRIEVABLE_HINT)
	@show info = glGetProgramiv(program, GL_LINK_STATUS)
	@show info = glGetProgramiv(program, GL_VALIDATE_STATUS)
	@show info = glGetProgramiv(program, GL_DELETE_STATUS)
	@show info = glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES)
	@show info = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)
	@show info = glGetProgramiv(program, GL_ACTIVE_UNIFORM_BLOCKS)
	@show info = glGetProgramiv(program, GL_ACTIVE_ATOMIC_COUNTER_BUFFERS)
	@show info = glGetProgramiv(program, GL_TRANSFORM_FEEDBACK_BUFFER_MODE)
	@show info = glGetProgramiv(program, GL_TRANSFORM_FEEDBACK_VARYINGS)
end




using GLAbstraction, GLWindow, Reactive

window = createwindow("asd", 700,700, debugging=false)


cam = PerspectiveCamera(window.inputs, Vec3(1,0,0), Vec3(0))
vert = " 
#version 430
uniform Camera{
	mat4 projection; 
	mat4 view;
};
struct Mesh
{
  vec3 vertex;
  vec3 normal;
  vec2 uv;
};

in Mesh vertex;

void main() {
	gl_Position = projection * view * vec4(vertex, 1.0);
}
"

frag = "
#version 430
out vec4 frag_color;
void main() {

frag_color = vec4(1.0,0.0, 1.0, 1.0);
}
"


v, uvw, idx = gencube(1f0,1f0,1f0)
indexes 	= indexbuffer(idx)
verts 		= GLBuffer(v,3)

vertexShaderID   = GLAbstraction.readshader(vert, GL_VERTEX_SHADER, "vertpath")
println(GLAbstraction.getinfolog(vertexShaderID))
@show GLAbstraction.isvalidshader(vertexShaderID)
fragmentShaderID = GLAbstraction.readshader(frag, GL_FRAGMENT_SHADER, "fragpath")
@show GLAbstraction.isvalidshader(fragmentShaderID)



p = glCreateProgram()
@assert p > 0
glAttachShader(p, vertexShaderID)
glAttachShader(p, fragmentShaderID)

glLinkProgram(p)

glDeleteShader(vertexShaderID) # Can be deleted, as they will still be linked to Program and released after program gets released
glDeleteShader(fragmentShaderID)

getProgramInfo(GLProgram(p))
getAttributesInfo(GLProgram(p))

getUniformsInfo(GLProgram(p))




const vbo = GLVertexArray(
	Dict{Symbol, GLBuffer}(
		:vertex => verts,
		:name_doesnt_matter_for_indexes => indexes
	), p
	)

immutable Cam
	projection::Mat4
	view::Mat4
end

bindingPoint 	= 1
myFloats 		= Mat4[cam.projection.value, cam.view.value] 
blockIndex 		= glGetUniformBlockIndex(p, "Camera")
#glGetActiveUniformsiv(p,1,[blockIndex], GL_UNIFORM_TYPE)
@assert blockIndex != GL_INVALID_INDEX "shiit not a valid index"
glUniformBlockBinding(p, blockIndex, bindingPoint)

buffer = GLuint[0]
glGenBuffers(1, buffer)
glBindBuffer(GL_UNIFORM_BUFFER, buffer[1])

glBufferData(GL_UNIFORM_BUFFER, sizeof(myFloats), myFloats, GL_DYNAMIC_DRAW)
glBindBufferBase(GL_UNIFORM_BUFFER, bindingPoint, buffer[1])

lift(cam.projection, cam.view) do projection, view
	myFloats 		= [Cam(projection, view)]
	glBindBuffer(GL_UNIFORM_BUFFER, buffer[1])
	glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(myFloats), myFloats)
end




glClearColor(0,0,0,1)
while window.inputs[:open].value
  	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
	render(vbo)
	GLFW.SwapBuffers(window.nativewindow)
	GLFW.PollEvents()
	sleep(0.01)
end
GLFW.Terminate()
