using GLFW, React, ImmutableArrays, ModernGL, GLAbstraction, GLWindow


GLFW.Init()
GLFW.WindowHint(GLFW.SAMPLES, 4)

GLFW.WindowHint(GLFW.OPENGL_DEBUG_CONTEXT, 1)

window = GLFW.CreateWindow(10,10, "lol, ey")
GLFW.MakeContextCurrent(window)

init_glutils()
immutable GLSLVariable
	name::ASCIIString
	location::GLint
	typ::GLenum 
end

frag = "
#version 130
out vec4 fragment_color;
void main(){
    fragment_color = vec4(0.0);
}
"
vert = "
#version 130

in vec3 vertex;

uniform mat4 projectionview[10];
uniform vec3 offset;

void main(){


   	gl_Position = projectionview[1] * (vec4(vertex + offset, 1.0));
}
"

flatshader 		  = GLProgram(vert, frag, "vert", "frag")

flatshader.upload(mat4(1), vec3(1))
println(flatshader)

const UNIFORM_TYPE_ENUM_DICT = [

	GL_FLOAT 		=> [GLfloat, vec1],
	GL_FLOAT_VEC2	=> [vec2],
	GL_FLOAT_VEC3	=> [vec3],
	GL_FLOAT_VEC4	=> [vec4],

	GL_INT 			=> [GLint, Integer, ivec1],
	GL_INT_VEC2		=> [ivec2],
	GL_INT_VEC3		=> [ivec3],
	GL_INT_VEC4		=> [ivec4],

	GL_BOOL			=> [GLint, Integer, ivec1, Bool],
	GL_BOOL_VEC2	=> [ivec2],
	GL_BOOL_VEC3	=> [ivec3],
	GL_BOOL_VEC4	=> [ivec4],

	GL_FLOAT_MAT2	=> [mat2],
	GL_FLOAT_MAT3	=> [mat3],
	GL_FLOAT_MAT4	=> [mat4],

	GL_FLOAT_MAT2x3	=> [mat2x3],
	GL_FLOAT_MAT2x4	=> [mat2x4],

	GL_FLOAT_MAT3x2	=> [mat3x2],
	GL_FLOAT_MAT3x4	=> [mat3x4],

	GL_FLOAT_MAT4x3	=> [mat4x3],
	GL_FLOAT_MAT4x2	=> [mat4x2],


	GL_SAMPLER_1D	=> [Texture{GLfloat,1,1}, Texture{GLfloat,2,1}, Texture{GLfloat,3,1}, Texture{GLfloat,4,1}],
	GL_SAMPLER_2D	=> [Texture{GLfloat,1,2}, Texture{GLfloat,2,2}, Texture{GLfloat,3,2}, Texture{GLfloat,4,2}],
	GL_SAMPLER_3D	=> [Texture{GLfloat,1,3}, Texture{GLfloat,2,3}, Texture{GLfloat,3,3}, Texture{GLfloat,4,3}],

	GL_UNSIGNED_INT_SAMPLER_1D	=> [Texture{GLuint,1,1}, Texture{GLuint,2,1}, Texture{GLuint,3,1}, Texture{GLuint,4,1}],
	GL_UNSIGNED_INT_SAMPLER_2D	=> [Texture{GLuint,1,2}, Texture{GLuint,2,2}, Texture{GLuint,3,2}, Texture{GLuint,4,2}],
	GL_UNSIGNED_INT_SAMPLER_3D	=> [Texture{GLuint,1,3}, Texture{GLuint,2,3}, Texture{GLuint,3,3}, Texture{GLint,4,3}],

	GL_INT_SAMPLER_1D	=> [Texture{GLint,1,1}, Texture{GLint,2,1}, Texture{GLint,3,1}, Texture{GLint,4,1}],
	GL_INT_SAMPLER_2D	=> [Texture{GLint,1,2}, Texture{GLint,2,2}, Texture{GLint,3,2}, Texture{GLint,4,2}],
	GL_INT_SAMPLER_3D	=> [Texture{GLint,1,3}, Texture{GLint,2,3}, Texture{GLint,3,3}, Texture{GLint,4,3}],
]


function is_correct_uniform_type{T <: Real}(targetuniform::GLenum, tocheck::Vector{T})
	shouldbe = uniform_type(targetuniform)
	return in(shouldbe, T)
end
function uniform_type(targetuniform::GLenum)
	if haskey(UNIFORM_TYPE_ENUM_DICT, targetuniform)
		UNIFORM_TYPE_ENUM_DICT[targetuniform]
	else
		error("Unrecognized Unifom Enum. Enum found: ", GLENUM(targetuniform).name)
	end
end





#=
	This functions creates a uniform upload function for a Program
	which can be used to upload uniforms in the most efficient wayt
	the function will look like:
	function upload(uniform1, uniform2, uniform3)
		gluniform(1, uniform1) # inlined uniform location
		gluniform(2, uniform2)
		gluniform(3, 0, uniform3) #if a uniform is a texture, texture targets are inlined as well
		#this is supposed to be a lot faster than iterating through an array and caling the right functions
		#with the right locations and texture targets
	end

=#
function createuniformfunction(uniformlist::Tuple, typelist::Tuple)
	uploadfunc 			= {}
	texturetarget 		= 0

	for i=1:length(uniformlist)

		variablename 	= uniformlist[i]
		uniformtype 	= typelist[i]
		uniformlocation = convert(GLint, i-1)

		if uniformtype == GL_SAMPLER_1D || uniformtype == GL_SAMPLER_2D || uniformtype == GL_SAMPLER_3D
			push!(uploadfunc, :(gluniform($uniformlocation, $texturetarget, $variablename)))
			texturetarget += 1
		else
			push!(uploadfunc, :(gluniform($uniformlocation, $variablename)))
		end

	end
	return eval(quote
		function uniformuploadfunction($(uniformlist...))
			$(uploadfunc...)
		end
	end)
end





#=
		push!(testfunc, begin 
			if !is_correct_uniform_type($uniformtype, $variablename)
				name = $(string(variablename))
				typ = typeof($variablename)
				supposedtype = $(uniform_type(uniformtype))
				error(name * " doesn't have the right type. Required: " *supposedtype * " found: " * typ)
			end
		end)
		=#


#=
	this function puts together the name of the gl uniform function
	and determines the bit size of the actual uniform
=#
#=

function uniformfunction_name_with_size(typ::GLenum)
	name = string(GLENUM(typ).name)[4:end]
	elemtype = split(name, "_")
	if elemtype[1] == "SAMPLER"

		if contains(elemtype[2], "1")
			return ("settexture1D", 1)
		elseif contains(elemtype[2], "2")
			return ("settexture2D", 2)
		elseif contains(elemtype[2], "3")
			return ("settexture3D", 3)
		else
			error(name, " not supported yet")
		end

	else
		#unsigned ints need extra treatmend
		if elemtype[1] == "UNSIGNED"
			elemtype = ["U"*elemtype[2], elemtype[3]]
		end
		matrix = ""
		if length(elemtype) == 1
			mdim = 1
			dim = "1"
		elseif length(elemtype) == 2
			dim = elemtype[2]
			if contains(dim, "MAT")
				matrix = "Matrix"
				dim = replace(dim, "MAT", "")
				mdim = map(int, split(dim, "x"))
			elseif contains(dim, "VEC")
				dim = replace(dim, "VEC", "")
				mdim = [int(dim)]
			else
				error(name, " not supported yet")
			end
		end
		if elemtype[1] == "UINT"
			elsize = sizeof(GLuint)
			postfix = "uiv"
		elseif elemtype[1] == "INT"
			elsize = sizeof(GLint)
			postfix = "iv"
		elseif elemtype[1] == "FLOAT"
			elsize = sizeof(GLfloat)
			postfix = "fv"
		elseif elemtype[1] == "DOUBLE"
			elsize = sizeof(GLdouble)
			postfix = "dv"
		else
			error(name, " not supported yet")
		end
		uniformfunc = "glUniform" * matrix * dim * postfix
		return (uniformfunc, elsize * prod(mdim))
	end

end

=#