getnames(check_function::Function) = filter(check_function, uint32(0:65534))

# gets all the names currently boundo to programs
getProgramNames()	  = getnames(glIsProgram)
getShaderNames() 	  = getnames(glIsShader)
getVertexArrayNames() = getnames(glIsVertexArray)

# display info for all active uniforms in a program
function getUniformsInfo(p::GLProgram) 
	result = Dict{Symbol, Any}()
	program = p.id
	# Get uniforms info (not in named blocks)
	activeUnif = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)

	for i=0:activeUnif-1
		index = glGetActiveUniformsiv(program, i, GL_UNIFORM_BLOCK_INDEX)

		if (index == -1)  # if it is a uniform block
			tmp = Dict{Symbol, Any}()
			tmp[:name] 		     = glGetActiveUniformName(program, i)	
			tmp[:uniType] 	   	 = GLENUM(glGetActiveUniformsiv(program, i, GL_UNIFORM_TYPE))

			tmp[:uniSize] 	   	 = glGetActiveUniformsiv(program, i, GL_UNIFORM_SIZE)
			tmp[:uniArrayStride] = glGetActiveUniformsiv(program, i, GL_UNIFORM_ARRAY_STRIDE)

			auxSize = 0
			if (uniArrayStride > 0)
				tmp[:auxSize] = uniArrayStride * uniSize
			else
				tmp[:auxSize] = spGLSLTypeSize[uniType]
			end
			result[symbol("unfifom$i")] = tmp
		end

	end
	# Get named blocks info
	count = glGetProgramiv(program, GL_ACTIVE_UNIFORM_BLOCKS)

	for i=0:count-1 
		tmp = Dict{Symbol, Any}()
		# Get blocks name
		tmp[:name] 	 		 = glGetActiveUniformBlockName(program, i)
		tmp[:dataSize] 		 = glGetActiveUniformBlockiv(program, i, GL_UNIFORM_BLOCK_DATA_SIZE)

		tmp[:index] 	 	 = glGetActiveUniformBlockiv(program, i,  GL_UNIFORM_BLOCK_BINDING)
		tmp[:binding_point]  = glGetIntegeri_v(GL_UNIFORM_BUFFER_BINDING, tmp[:index])

		tmp[:activeUnif]   	 = glGetActiveUniformBlockiv(program, i, GL_UNIFORM_BLOCK_ACTIVE_UNIFORMS)

		indices = zeros(GLint, tmp[:activeUnif])
		glGetActiveUniformBlockiv(program, i, GL_UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES, pointer(indices))
		tmp1 = Dict{Int, Any}()
		for ubindex in indices
			tmp2 = Dict{Symbol, Any}()
			tmp2[:name] 		= glGetActiveUniformName(program, ubindex)
			tmp2[:uniType] 	   = GLENUM(glGetActiveUniformsiv(program, ubindex, GL_UNIFORM_TYPE))
			tmp2[:uniOffset]   = glGetActiveUniformsiv(program, ubindex, GL_UNIFORM_OFFSET)
			tmp2[:uniSize] 	   = glGetActiveUniformsiv(program, ubindex, GL_UNIFORM_SIZE)
			tmp2[:uniMatStride] = glGetActiveUniformsiv(program, ubindex, GL_UNIFORM_MATRIX_STRIDE)
			tmp1[Int(ubindex)] = tmp2
		end
		tmp[:blocks] = tmp1
		result[symbol("unfifom$i")] = tmp
	end
	result
end


# display the values for uniforms in the default block
function getUniformInfo(p::GLProgram, uniName::Symbol) 
	# is it a program ?
	program 				  = p.id
	loc 	  				  = glGetUniformLocation(program, uniName)
	name, typ, uniform_size = glGetActiveUniform(program, loc)
end


# display the values for a uniform in a named block
function getUniformInBlockInfo(p::GLProgram, 
				blockName, 
				uniName) 

	program = p.id

	index = glGetUniformBlockIndex(program, blockName)
	if (index == GL_INVALID_INDEX) 
		println("$uniName is not a valid uniform name in block $blockName")
	end
	bindIndex 		= glGetActiveUniformBlockiv(program, index, GL_UNIFORM_BLOCK_BINDING)
	bufferIndex 	= glGetIntegeri_v(GL_UNIFORM_BUFFER_BINDING, bindIndex)
	uniIndex 		= glGetUniformIndices(program, uniName)
	
	uniType 		= glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_TYPE)
	uniOffset 		= glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_OFFSET)
	uniSize 		= glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_SIZE)
	uniArrayStride 	= glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_ARRAY_STRIDE)
	uniMatStride 	= glGetActiveUniformsiv(program, uniIndex, GL_UNIFORM_MATRIX_STRIDE)
end


# display information for a program's attributes
function getAttributesInfo(p::GLProgram) 

	program = p.id
	# how many attribs?
	activeAttr = glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES)
	# get location and type for each attrib
	for i=0:activeAttr-1
		name, typ, siz = glGetActiveAttrib(program,	i)
		loc = glGetAttribLocation(program, name)
	end
end


# display program's information
function getProgramInfo(p::GLProgram) 
	# check if name is really a program
	program = p.id
	# Get the shader's name
	shaders = glGetAttachedShaders(program)
	for shader in shaders
		info = GLENUM(convert(GLenum, glGetShaderiv(shader, GL_SHADER_TYPE))).name
	end
	# Get program info
	info = glGetProgramiv(program, GL_PROGRAM_SEPARABLE)
	info = glGetProgramiv(program, GL_PROGRAM_BINARY_RETRIEVABLE_HINT)
	info = glGetProgramiv(program, GL_LINK_STATUS)
	info = glGetProgramiv(program, GL_VALIDATE_STATUS)
	info = glGetProgramiv(program, GL_DELETE_STATUS)
	info = glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES)
	info = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)
	info = glGetProgramiv(program, GL_ACTIVE_UNIFORM_BLOCKS)
	info = glGetProgramiv(program, GL_ACTIVE_ATOMIC_COUNTER_BUFFERS)
	info = glGetProgramiv(program, GL_TRANSFORM_FEEDBACK_BUFFER_MODE)
	info = glGetProgramiv(program, GL_TRANSFORM_FEEDBACK_VARYINGS)
end


