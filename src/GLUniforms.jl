# Uniforms are OpenGL variables that stay the same for the entirety of a drawcall.
# There are a lot of functions, to upload them, as OpenGL doesn't rely on multiple dispatch
# here is my approach, to handle all of the uniforms with one function, namely gluniform
# For uniforms, the vector and matrix types from ImmutableArrays should be used, as they map the relation almost 1:1
GLSL_COMPATIBLE_NUMBER_TYPES = [GLdouble, GLfloat, GLint, GLuint]

GLSL_PREFIX = [
	GLdouble 	=> "d", 
	GLfloat 	=> "", 
	GLint 		=> "i", 
	GLuint 		=> "ui"
]

GL_POSTFIX = [
	GLdouble 	=> "dv", 
	GLfloat 	=> "fv", 
	GLint 		=> "iv", 
	GLuint 		=> "uiv"
]

# Generates uniform upload functions for ImmutableArrays.
# Also it defines glsl alike aliases and constructors.
# This probably shouldn't be done in the same function, but its for now the easiest solution.
macro genuniformfunctions(maxdim::Integer)
	glslvector = "vec"
	glslmatrix = "mat"

	imvector = "Vector"
	immatrix = "Matrix"
	expressions = {}
	for n=1:maxdim, typ in GLSL_COMPATIBLE_NUMBER_TYPES
		glslalias 	= symbol(string(GLSL_PREFIX[typ],glslvector,n)) 
		name 		= symbol(string(imvector, n))
		imalias 	= :($name {$typ})
		uniformfunc = symbol(string("glUniform", n, GL_POSTFIX[typ]))
		if n == 1 # define also single valued uniform functions
			uniformfunc = symbol(string("glUniform", n, chop(GL_POSTFIX[typ])))
			push!(expressions, :(gluniform(location::GLint, x::$typ) = $uniformfunc(location, x)))
		end
		push!(expressions, :(typealias $glslalias $imalias)) # glsl alike type alias
		push!(expressions, :(gluniform(location::Integer, x::$imalias) = $uniformfunc(location, 1, [x]))) # uniform function for single uniforms
		push!(expressions, :(gluniform(location::Integer, x::Vector{$imalias}) = $uniformfunc(location, length(x), pointer(x)))) #uniform function for arrays of uniforms
		if n > 1
			push!(expressions, :($glslalias(x::Real) = $name(convert($typ, x)))) # Single valued constructor
		end
		push!(expressions, Expr(:export, glslalias))
		

		#########################################################################
		push!(expressions, :(toglsl(x::$imalias) = $(string(glslalias)))) # method for shader type mapping

	end
	for n=2:maxdim, n2=2:maxdim, typ in [GLdouble, GLfloat]
		glsldim 	= n==n2 ? "$n" : "$(n)x$(n2)"
		glslalias 	= symbol(string(GLSL_PREFIX[typ], glslmatrix, glsldim)) 
		name 		= symbol(string(immatrix, n,"x",n2))
		imalias 	= :($name {$typ})
		uniformfunc = symbol(string("glUniformMatrix", glsldim, GL_POSTFIX[typ]))

		push!(expressions, :(typealias $glslalias $imalias)) #GLSL alike alias
		push!(expressions, :(gluniform(location::Integer, x::$imalias) = $uniformfunc(location, 1, GL_FALSE, [x]))) # uniform function for single uniforms
		push!(expressions, :(gluniform(location::Integer, x::Vector{$imalias}) = $uniformfunc(location, length(x), GL_FALSE, pointer(x)))) #uniform function for arrays of uniforms
		push!(expressions, :($glslalias(x::Real) = $name(convert($typ, x)))) # Single valued constructor
		push!(expressions, Expr(:export, glslalias))
		#########################################################################
		push!(expressions, :(toglsl(x::$imalias) = $(string(glslalias)))) # method for shader type mapping
	end
	return esc(Expr(:block, expressions...))
end

@genuniformfunctions 4 

gluniform(location::Integer, target::Integer, t::Texture) = gluniform(convert(GLint, location), convert(GLint, target), t)
function gluniform(location::GLint, target::GLint, t::Texture)
    activeTarget = GL_TEXTURE0 + uint32(target)
    glActiveTexture(activeTarget)
    glBindTexture(texturetype(t), t.id)
    gluniform(location, target)
end
gluniform(location::Integer, x::Signal) = gluniform(location, x.value)
#Uniform upload functions for julia arrays...
function gluniform{T <: Union(GLSL_COMPATIBLE_NUMBER_TYPES...)}(location::GLint, x::Vector{T})
    d = length(x)
    if d == 1
    	gluniform(location, Vector1(x...))
    elseif d == 2
    	gluniform(location, Vector2(x...))
    elseif d == 3
    	gluniform(location, Vector3(x...))
    elseif d == 3
    	gluniform(location, Vector4(x...))
    else  
    	error("unsopported vector length!")
    end
end


toglsl{T, C, D}(t::Texture{T, C, D}) = string(GLSL_PREFIX[T],"sampler", D, "D")
toglsl(t::GLfloat) = "float"
toglsl(t::GLuint) = "uint"
toglsl(t::GLint) = "int"




const UNIFORM_TYPE_ENUM_DICT = [

    GL_FLOAT        => [GLfloat, vec1],
    GL_FLOAT_VEC2   => [vec2],
    GL_FLOAT_VEC3   => [vec3],
    GL_FLOAT_VEC4   => [vec4],

    GL_INT          => [GLint, Integer, ivec1],
    GL_INT_VEC2     => [ivec2],
    GL_INT_VEC3     => [ivec3],
    GL_INT_VEC4     => [ivec4],

    GL_BOOL         => [GLint, Integer, ivec1, Bool],
    GL_BOOL_VEC2    => [ivec2],
    GL_BOOL_VEC3    => [ivec3],
    GL_BOOL_VEC4    => [ivec4],

    GL_FLOAT_MAT2   => [mat2],
    GL_FLOAT_MAT3   => [mat3],
    GL_FLOAT_MAT4   => [mat4],

    GL_FLOAT_MAT2x3 => [mat2x3],
    GL_FLOAT_MAT2x4 => [mat2x4],

    GL_FLOAT_MAT3x2 => [mat3x2],
    GL_FLOAT_MAT3x4 => [mat3x4],

    GL_FLOAT_MAT4x3 => [mat4x3],
    GL_FLOAT_MAT4x2 => [mat4x2],


    GL_SAMPLER_1D   => [Texture{GLfloat,1,1}, Texture{GLfloat,2,1}, Texture{GLfloat,3,1}, Texture{GLfloat,4,1}],
    GL_SAMPLER_2D   => [Texture{GLfloat,1,2}, Texture{GLfloat,2,2}, Texture{GLfloat,3,2}, Texture{GLfloat,4,2}],
    GL_SAMPLER_3D   => [Texture{GLfloat,1,3}, Texture{GLfloat,2,3}, Texture{GLfloat,3,3}, Texture{GLfloat,4,3}],

    GL_UNSIGNED_INT_SAMPLER_1D  => [Texture{GLuint,1,1}, Texture{GLuint,2,1}, Texture{GLuint,3,1}, Texture{GLuint,4,1}],
    GL_UNSIGNED_INT_SAMPLER_2D  => [Texture{GLuint,1,2}, Texture{GLuint,2,2}, Texture{GLuint,3,2}, Texture{GLuint,4,2}],
    GL_UNSIGNED_INT_SAMPLER_3D  => [Texture{GLuint,1,3}, Texture{GLuint,2,3}, Texture{GLuint,3,3}, Texture{GLint,4,3}],

    GL_INT_SAMPLER_1D   => [Texture{GLint,1,1}, Texture{GLint,2,1}, Texture{GLint,3,1}, Texture{GLint,4,1}],
    GL_INT_SAMPLER_2D   => [Texture{GLint,1,2}, Texture{GLint,2,2}, Texture{GLint,3,2}, Texture{GLint,4,2}],
    GL_INT_SAMPLER_3D   => [Texture{GLint,1,3}, Texture{GLint,2,3}, Texture{GLint,3,3}, Texture{GLint,4,3}],
]

function is_correct_uniform_type{T <: Real}(targetuniform::GLenum, tocheck::T)
    shouldbe = uniform_type(targetuniform)
    return in(T, shouldbe)
end
function is_correct_uniform_type{T <: Real}(targetuniform::GLenum, tocheck::AbstractArray{T})
    shouldbe = uniform_type(targetuniform)
    return in(typeof(tocheck), shouldbe)
end
function is_correct_uniform_type{T <: Real}(targetuniform::GLenum, tocheck::Vector{T})
    shouldbe = uniform_type(targetuniform)
    return in(T, shouldbe)
end
is_correct_uniform_type(targetuniform::GLenum, tocheck::Signal) = is_correct_uniform_type(targetuniform, tocheck.value)

function is_correct_uniform_type(targetuniform::GLenum, tocheck::Texture)
    shouldbe = uniform_type(targetuniform)
    
    return in(typeof(tocheck), shouldbe)
end
function uniform_type(targetuniform::GLenum)
    if haskey(UNIFORM_TYPE_ENUM_DICT, targetuniform)
        UNIFORM_TYPE_ENUM_DICT[targetuniform]
    else
        error("Unrecognized Unifom Enum. Enum found: ", GLENUM(targetuniform).name)
    end
end

function uniform_name_type(program::GLuint)
    uniformLength   = glGetProgramiv(program, GL_ACTIVE_UNIFORMS)
    if uniformLength == 0
        return ()
    else
        nametypelist = ntuple(uniformLength, i -> glGetActiveUniform(program, i-1)[1:2]) # take size and name
        return nametypelist
    end
end

function istexturesampler(typ::GLenum)
    return (
        typ == GL_SAMPLER_1D || typ == GL_SAMPLER_2D || typ == GL_SAMPLER_3D ||  
        typ == GL_UNSIGNED_INT_SAMPLER_1D || typ == GL_UNSIGNED_INT_SAMPLER_2D || typ == GL_UNSIGNED_INT_SAMPLER_3D ||
        typ == GL_INT_SAMPLER_1D || typ == GL_INT_SAMPLER_2D || typ == GL_INT_SAMPLER_3D
    )
end


export gluniform, toglsl

