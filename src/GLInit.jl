const INIT_FUNCTION_LIST = Function[]


export init_after_context_creation, init_glutils, get_glsl_version_string, get_glsl_in_qualifier_string, get_glsl_out_qualifier_string

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
global GLSL_VARYING_QUALIFIER = ""

function createcontextinfo(dict)
	global GLSL_VERSION, GLSL_VARYING_QUALIFIER
	glsl = split(bytestring(glGetString(GL_SHADING_LANGUAGE_VERSION)), ['.', ' '])
	if length(glsl) >= 2
		glsl = VersionNumber(int(glsl[1]), int(glsl[2])) 
		if glsl.major == 1 && glsl.minor <= 2
			warn("OpenGL Shading Language (GLSL) version $glsl may be too low. Consider updating your graphics driver.")
		end
		GLSL_VERSION = string(glsl.major) * rpad(string(glsl.minor),2,"0")
		if glsl.major >= 1 && glsl.minor > 20
			GLSL_VARYING_QUALIFIER = "in"
		else
			GLSL_VARYING_QUALIFIER = "varying"
		end
	else
		error("Unexpected version number string. Please report this bug! Version string: $(glsl)")
	end

	glv = split(bytestring(glGetString(GL_VERSION)), ['.', ' '])
	if length(glv) >= 2
		glv = VersionNumber(int(glv[1]), int(glv[2]))
		if glv.major < 3
			warn("OpenGL version $glv may be too low. Consider updating your graphics driver.")
		end
	else
		error("Unexpected version number string. Please report this bug! Version string: $(glsl)")
	end
	dict[:glsl_version] 	= glsl
	dict[:gl_version] 		= glv
	dict[:gl_vendor] 		= bytestring(glGetString(GL_VENDOR))
	dict[:gl_renderer] 		= bytestring(glGetString(GL_RENDERER))
	n = GLint[0]
	glGetIntegerv(GL_NUM_EXTENSIONS, n)
	test 	= [ bytestring(glGetStringi(GL_EXTENSIONS, i)) for i = 0:(n[1]-1) ]
end
function get_glsl_version_string()
	if isempty(GLSL_VERSION)
		error("couldn't get GLSL version, GLUTils not initialized, or context not created?")
	end
	return "#version $(GLSL_VERSION)\n"
end

get_glsl_out_qualifier_string() = GLSL_VARYING_QUALIFIER == "in" ? "out" : GLSL_VARYING_QUALIFIER
get_glsl_in_qualifier_string() = GLSL_VARYING_QUALIFIER