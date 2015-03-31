const INIT_FUNCTION_LIST = Function[]


function init_after_context_creation(f::Function)
	push!(INIT_FUNCTION_LIST, f)
end

function init_glutils()
	createcontextinfo(OPENGL_CONTEXT)
	for elem in INIT_FUNCTION_LIST
		elem()
	end
end


global const OPENGL_CONTEXT 	= Dict{Symbol, Any}()
global GLSL_VERSION 			= ""
global GLSL_VARYING_QUALIFIER 	= ""

function createcontextinfo(dict)
	global GLSL_VERSION, GLSL_VARYING_QUALIFIER
	glsl = split(bytestring(glGetString(GL_SHADING_LANGUAGE_VERSION)), ['.', ' '])
	if length(glsl) >= 2
		glsl = VersionNumber(parse(Int, glsl[1]), parse(Int, glsl[2])) 
		if glsl.major == 1 && glsl.minor <= 2
			error("OpenGL shading Language version too low. Try updating graphic driver!")
		end
		GLSL_VERSION = string(glsl.major) * rpad(string(glsl.minor),2,"0")
		if glsl.major >= 1 
			GLSL_VARYING_QUALIFIER = "in"
		else
			GLSL_VARYING_QUALIFIER = "varying"
		end
	else
		error("Unexpected version number string. Please report this bug! Version string: $(glsl)")
	end

	glv = split(bytestring(glGetString(GL_VERSION)), ['.', ' '])
	if length(glv) >= 2
		glv = VersionNumber(parse(Int, glv[1]), parse(Int, glv[2])) 
		if glv.major < 3
			error("OpenGL version too low. Try updating graphic driver!")
		end
	else
		error("Unexpected version number string. Please report this bug! Version string: $(glsl)")
	end
	dict[:glsl_version] 	= glsl
	dict[:gl_version] 		= glv
	dict[:gl_vendor] 		= bytestring(glGetString(GL_VENDOR))
	dict[:gl_renderer] 		= bytestring(glGetString(GL_RENDERER))
	dict[:maxtexturesize]   = glGetIntegerv(GL_MAX_TEXTURE_SIZE)
	
	n 	 = glGetIntegerv(GL_NUM_EXTENSIONS)
	println(n)
	#test = [glGetStringi(GL_EXTENSIONS, i) for i = 0:(n[1]-1)]

end
function glsl_version_string()
	isempty(GLSL_VERSION) && error("couldn't get GLSL version, GLUTils not initialized, or context not created?")
		
	return "#version $(GLSL_VERSION)\n"
end

glsl_out_qualifier_string() = GLSL_VARYING_QUALIFIER == "in" ? "out" : GLSL_VARYING_QUALIFIER
glsl_in_qualifier_string() 	= GLSL_VARYING_QUALIFIER

maxtexturesize() = OPENGL_CONTEXT[:maxtexturesize]