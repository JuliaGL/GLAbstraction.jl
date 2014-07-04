const INIT_FUNCTION_LIST = Function[]


export init_after_context_creation, init_glutils, get_glsl_version_string

function init_after_context_creation(f::Function)
	push!(INIT_FUNCTION_LIST, f)
end

function init_glutils()
	createcontextinfo(OPENGL_CONTEXT)
	for elem in INIT_FUNCTION_LIST
		elem()
	end
end


global const OPENGL_CONTEXT = (Symbol => Any)[]
global GLSL_VERSION = ""

function createcontextinfo(dict)
	global GLSL_VERSION
	glsl = split(bytestring(glGetString(GL_SHADING_LANGUAGE_VERSION)), ['.', ' '])
	if length(glsl) >= 2
		glsl = VersionNumber(int(glsl[1]), int(glsl[2])) 
		GLSL_VERSION = string(glsl.major) * rpad(string(glsl.minor),2,"0")
	else
		error("Unexpected version number string. Please report this bug! Version string: $(glsl)")
	end

	glv = split(bytestring(glGetString(GL_VERSION)), ['.', ' '])
	if length(glv) >= 2
		glv = VersionNumber(int(glv[1]), int(glv[2])) 
	else
		error("Unexpected version number string. Please report this bug! Version string: $(glsl)")
	end
	dict[:glsl_version] 	= glsl
	dict[:gl_version] 		= glv
	dict[:gl_vendor] 		= bytestring(glGetString(GL_VENDOR))
	dict[:gl_renderer] 		= bytestring(glGetString(GL_RENDERER))
	#dict[:gl_extensions] 	= split(bytestring(glGetString(GL_EXTENSIONS)))
end
function get_glsl_version_string()
	if isempty(GLSL_VERSION)
		error("couldn't get GLSL version, GLUTils not initialized, or context not created?")
	end
	return "#version $(GLSL_VERSION)\n"
end