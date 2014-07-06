using GLFW, React, ImmutableArrays, ModernGL, GLUtil, GLWindow


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
out vec4 fragment_color;
void main(){
    fragment_color = vec4(0.0);
}
"
vert = "
in vec3 vertex;

uniform mat4 projectionview[10];
uniform vec3 offset;

void main(){


   	gl_Position = projectionview[1] * (vec4(vertex + offset, 1.0));
}
"

flatshader 		  = GLProgram(vert, frag, "vert", "frag")


function settexture(location::GLint, target::GLint, id::GLuint, texturetype::GLenum)
    activeTarget = GL_TEXTURE0 + uint32(target)
    glActiveTexture(activeTarget)
    glBindTexture(texturetype, id)
    glUniform1i(location, target)
end
settexture1D(location::GLint, target::GLint, id::GLuint) = settexture(location, target, id, GL_TEXTURE_1D)
settexture2D(location::GLint, target::GLint, id::GLuint) = settexture(location, target, id, GL_TEXTURE_2D)
settexture3D(location::GLint, target::GLint, id::GLuint) = settexture(location, target, id, GL_TEXTURE_3D)

const UNIFORM_FUNCION_DICT = [

	GL_FLOAT 		=> glUniform1fv,
	GL_FLOAT_VEC2	=> glUniform2fv,
	GL_FLOAT_VEC3	=> glUniform3fv,
	GL_FLOAT_VEC4	=> glUniform4fv,

	GL_INT 			=> glUniform1iv,
	GL_INT_VEC2		=> glUniform2iv,
	GL_INT_VEC3		=> glUniform3iv,
	GL_INT_VEC4		=> glUniform4iv,

	GL_BOOL			=> glUniform1iv,
	GL_BOOL_VEC2	=> glUniform2iv,
	GL_BOOL_VEC3	=> glUniform3iv,
	GL_BOOL_VEC4	=> glUniform4iv,

	GL_FLOAT_MAT2	=> glUniformMatrix2fv,
	GL_FLOAT_MAT3	=> glUniformMatrix3fv,
	GL_FLOAT_MAT4	=> glUniformMatrix4fv,

	GL_FLOAT_MAT2x3	=> glUniformMatrix2x3fv,
	GL_FLOAT_MAT2x4	=> glUniformMatrix2x4fv,

	GL_FLOAT_MAT3x2	=> glUniformMatrix3x2fv,
	GL_FLOAT_MAT3x4	=> glUniformMatrix3x4fv,

	GL_FLOAT_MAT4x3	=> glUniformMatrix4x3fv,
	GL_FLOAT_MAT4x2	=> glUniformMatrix4x2fv,


	GL_SAMPLER_1D	=> settexture1D,
	GL_SAMPLER_2D	=> settexture2D,
	GL_SAMPLER_3D	=> settexture3D,
]
const UNIFORM_SIZE_DICT = [

	"FLOAT" 		=> sizeof(GLfloat),
	"INT" 			=> sizeof(GLint),
	"DOUBLE" 		=> sizeof(GLint),

]
#=
	this function puts together the name of the gl uniform function
	and determines the bit size of the actual uniform
=#
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


function fieldtype(x::Any)
	T = typeof(x)
	types = T.types
	@assert !isempty(types)
	ftype = types[1]
	if any(t -> t!= ftype, types)
		error("field types are not homogenious for: ", T)
	end
	# We can return one field type, 
	# this means we can make a more specific function for this type
	eval(esc( :(fieldtype(x::$T) = $ftype) ))
	return ftype
end
function Base.eltype(x::Any)

end


toglpointer{T <: Real}(x::Array{T}, primitivesize) = convert(Ptr{T}, pointer(x))
function toglpointer{T <: Any}(x::Array{T}, primitivesize)
	elementT = eltype(T)
	convert(Ptr{elementT}, pointer(x))
end

function toglpointer(x::Any, primitivesize)
	if isa(x, Array)
		elementype = eltype(x)
		if isa(elementype, AbstractArray)

		ptr = convert(Ptr{}x
	else
		ptr = [$variablename]
	end
end

#=
	This functions creates 2 function for a Program
	The test functions can be used, to verify the types fed into a program,
	and the upload function can be called to upload all the uniforms to the
	program in the most efficient way.
=#
function createuniformfunction(uniformlist::Tuple, typelist::Tuple)
	uploadfunc 			= {}
	testfunc 			= {}
	functions_size 		= map(uniformfunction_name_with_size, typelist)
	texturetarget_count = 0

	for i=1:length(functions_size)

		uniformfunc 	= functions_size[i][1]
		uniformfunc_sym = symbol(uniformfunc)

		uniformsize 	= functions_size[i][2] 
		variablename 	= uniformlist[i]
		uniformlocation = i-1
		convertpointer = quote
			if isa($variablename, Signal)
				$variablename = $variablename.value
			end

		end
		if contains(uniformfunc, "Matrix")
			tmp = quote 
				$convertpointer
				$(uniformfunc_sym)($uniformlocation, sizeof($variablename) / $uniformsize, GL_FALSE, ptr)
			end
		elseif contains(uniformfunc, "settexture")
			tmp = quote 
				$(uniformfunc_sym)($uniformlocation, $texturetarget_count, $variablename)
			end
			texturetarget_count += 1
		else
			tmp = quote
				$convertpointer
				$(uniformfunc_sym)($uniformlocation, sizeof($variablename) / $uniformsize, ptr)
			end
		end
		testf = quote
			if isa($variablename, Array) || isbits($variablename) 
			else
				error("uniform: ", $variablename, "type: ", typeof($variablename)," is neither an Array nor a bitstype")
			end
		end
		push!(uploadfunc, tmp)
		push!(testfunc, testf)
	end
	ufunc = eval(quote
		function uniformuploadfunction($(uniformlist...))
			$(uploadfunc...)
		end
	end)
	tfunc = eval(quote
		function uniformtestfunction($(uniformlist...))
			$(testfunc...)
		end
	end)
	return (ufunc, tfunc)
end

function uniforms(program::GLuint)
    uniformLength   = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)
    if uniformLength == 0
        return () -> 0
    else
        uniformlist 	= ntuple(uniformLength, i -> glGetActiveUniform(program, i-1)[1])

        typelist 		= ntuple(uniformLength, i -> glGetActiveUniform(program, i-1)[2])
        sizes			= ntuple(uniformLength, i -> glGetActiveUniform(program, i-1))
        println(uniformlist)
        u, t = createuniformfunction(uniformlist, typelist)
        datet = [
        	:offset => Vector3(2f0),
        	:projectionview => [Matrix4x4(2f0)for i=1:10],
        ]
        args = map(x -> datet[x], uniformlist)
        u(args...)
    end
end
println(int(glGetUniformLocation(flatshader.id, "offset")))
uniforms(flatshader.id)