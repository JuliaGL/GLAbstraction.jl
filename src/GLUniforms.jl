# Uniforms are OpenGL variables that stay the same for the entirety of a drawcall.
# There are a lot of functions, to upload them, as OpenGL doesn't rely on multiple dispatch.
# here is my approach, to handle all of the uniforms with one function, namely gluniform
# For uniforms, the Vector and Matrix types from ImmutableArrays should be used, as they map the relation almost 1:1

GLSL_COMPATIBLE_NUMBER_TYPES = [GLdouble, GLfloat, GLint, GLuint]

GLSL_PREFIX = [
	GLdouble 	=> "d", 
	GLfloat 	=> "", 
	GLint 		=> "i", 
    GLuint      => "u",
	Uint8       => "",
    Uint16      => "u"
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
	glslVector = "Vec"
	glslMatrix = "Mat"

	imVector = "Vector"
	imMatrix = "Matrix"
	expressions = {}
	for n=1:maxdim, typ in GLSL_COMPATIBLE_NUMBER_TYPES
		glslalias 	= symbol(string(GLSL_PREFIX[typ],glslVector,n)) 
		name 		= symbol(string(imVector, n))
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
        push!(expressions, :(toglsltype_string(x::$imalias) = $(lowercase(string("uniform ", glslalias))))) # method for shader type mapping

	end
	for n=2:maxdim, n2=2:maxdim, typ in [GLdouble, GLfloat]
		glsldim 	= n==n2 ? "$n" : "$(n)x$(n2)"
		glslalias 	= symbol(string(GLSL_PREFIX[typ], glslMatrix, glsldim)) 
		name 		= symbol(string(imMatrix, n,"x",n2))
		imalias 	= :($name {$typ})
		uniformfunc = symbol(string("glUniformMatrix", glsldim, GL_POSTFIX[typ]))

		push!(expressions, :(typealias $glslalias $imalias)) #GLSL alike alias
		push!(expressions, :(gluniform(location::Integer, x::$imalias) = $uniformfunc(location, 1, GL_FALSE, [x]))) # uniform function for single uniforms
		push!(expressions, :(gluniform(location::Integer, x::Vector{$imalias}) = $uniformfunc(location, length(x), GL_FALSE, pointer(x)))) #uniform function for arrays of uniforms
		push!(expressions, :($glslalias(x::Real) = $name(convert($typ, x)))) # Single valued constructor
		push!(expressions, Expr(:export, glslalias))
		#########################################################################
		push!(expressions, :(toglsltype_string(x::$imalias) = $(lowercase(string("uniform ", glslalias))))) # method for shader type mapping
	end
	return esc(Expr(:block, expressions...))
end

@genuniformfunctions 4 

#Some additional uniform functions, not related to Imutable Arrays
gluniform(location::Integer, target::Integer, t::Texture) = gluniform(convert(GLint, location), convert(GLint, target), t)
function gluniform(location::GLint, target::GLint, t::Texture)
    activeTarget = GL_TEXTURE0 + uint32(target)
    glActiveTexture(activeTarget)
    glBindTexture(texturetype(t), t.id)
    gluniform(location, target)
end
gluniform(location::Integer, x::Signal) = gluniform(location, x.value)

gluniform(location::Integer, x::Union(GLubyte, GLushort, GLuint)) = glUniform1ui(location, x)
gluniform(location::Integer, x::Union(GLbyte, GLshort, GLint)) = glUniform1i(location, x)

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
    	error("unsopported Vector length!")
    end
end
glsl_prefix(x::DataType) = GLSL_PREFIX[x]
glsl_prefix{T <: FixedPoint}(x::Type{T}) = GLSL_PREFIX[FixedPointNumbers.rawtype(T)]

toglsltype_string{T, C, D}(t::Texture{T, C, D}) = string("uniform ", glsl_prefix(T),"sampler", D, "D")
toglsltype_string(t::GLfloat)                   = "uniform float"
toglsltype_string(t::GLuint)                    = "uniform uint"
toglsltype_string(t::GLint)                     = "uniform int"
toglsltype_string(t::GLBuffer)                  = "$(get_glsl_in_qualifier_string()) vec$(cardinality(t))"
toglsltype_string(t::Signal)                    = toglsltype_string(t.value)
toglsltype_string(t::StepRange)                 = toglsltype_string(Vec3(first(t), step(t), last(t)))


# Awkwart way of keeping track of all the different type consts and there allowed julia types they represent
# This is needed to validate, that you upload the correct types to a shader
const UNIFORM_TYPE_ENUM_DICT = [

    GL_FLOAT        => [GLfloat, Vec1],
    GL_FLOAT_VEC2   => [Vec2],
    GL_FLOAT_VEC3   => [Vec3],
    GL_FLOAT_VEC4   => [Vec4],

    GL_UNSIGNED_INT      => [GLuint, GLushort, GLubyte, Unsigned, uVec1],
    GL_UNSIGNED_INT_VEC2 => [uVec2],
    GL_UNSIGNED_INT_VEC3 => [uVec3],
    GL_UNSIGNED_INT_VEC4 => [uVec4],

    GL_INT          => [GLint, GLshort, GLbyte, Integer, iVec1],
    GL_INT_VEC2     => [iVec2],
    GL_INT_VEC3     => [iVec3],
    GL_INT_VEC4     => [iVec4],

    GL_BOOL         => [GLint, Integer, iVec1, Bool],
    GL_BOOL_VEC2    => [iVec2],
    GL_BOOL_VEC3    => [iVec3],
    GL_BOOL_VEC4    => [iVec4],

    GL_FLOAT_MAT2   => [Mat2],
    GL_FLOAT_MAT3   => [Mat3],
    GL_FLOAT_MAT4   => [Mat4],

    GL_FLOAT_MAT2x3 => [Mat2x3],
    GL_FLOAT_MAT2x4 => [Mat2x4],

    GL_FLOAT_MAT3x2 => [Mat3x2],
    GL_FLOAT_MAT3x4 => [Mat3x4],

    GL_FLOAT_MAT4x3 => [Mat4x3],
    GL_FLOAT_MAT4x2 => [Mat4x2],


    GL_SAMPLER_1D   => [Texture{GLfloat,1,1}, Texture{GLfloat,2,1}, Texture{GLfloat,3,1}, Texture{GLfloat,4,1},
                        Texture{GLubyte,1,1}, Texture{GLubyte,2,1}, Texture{GLubyte,3,1}, Texture{GLubyte,4,1}],
    GL_SAMPLER_2D   => [Texture{GLfloat,1,2}, Texture{GLfloat,2,2}, Texture{GLfloat,3,2}, Texture{GLfloat,4,2},
                        Texture{GLubyte,1,2}, Texture{GLubyte,2,2}, Texture{GLubyte,3,2}, Texture{GLubyte,4,2}],
    GL_SAMPLER_3D   => [Texture{GLfloat,1,3}, Texture{GLfloat,2,3}, Texture{GLfloat,3,3}, Texture{GLfloat,4,3},
                        Texture{GLubyte,1,3}, Texture{GLubyte,2,3}, Texture{GLubyte,3,3}, Texture{GLubyte,4,3}],

    GL_UNSIGNED_INT_SAMPLER_1D  => [Texture{GLuint,1,1}, Texture{GLuint,2,1}, Texture{GLuint,3,1}, Texture{GLuint,4,1},
                                    Texture{GLushort,1,1}, Texture{GLushort,2,1}, Texture{GLushort,3,1}, Texture{GLushort,4,1},
                                    Texture{GLubyte,1,1}, Texture{GLubyte,2,1}, Texture{GLubyte,3,1}, Texture{GLubyte,4,1}],

    GL_UNSIGNED_INT_SAMPLER_2D  => [Texture{GLuint,1,2}, Texture{GLuint,2,2}, Texture{GLuint,3,2}, Texture{GLuint,4,2}, 
                                    Texture{GLushort,1,2}, Texture{GLushort,2,2}, Texture{GLushort,3,2}, Texture{GLushort,4,2}, 
                                    Texture{GLubyte,1,2}, Texture{GLubyte,2,2}, Texture{GLubyte,3,2}, Texture{GLubyte,4,2}],


    GL_UNSIGNED_INT_SAMPLER_3D  => [Texture{GLuint,1,3}, Texture{GLuint,2,3}, Texture{GLuint,3,3}, Texture{GLint,4,3},
                                    Texture{GLushort,1,3}, Texture{GLushort,2,3}, Texture{GLushort,3,3}, Texture{GLushort,4,3},
                                    Texture{GLubyte,1,3}, Texture{GLubyte,2,3}, Texture{GLubyte,3,3}, Texture{GLubyte,4,3}],

    GL_INT_SAMPLER_1D   => [Texture{GLint,1,1}, Texture{GLint,2,1}, Texture{GLint,3,1}, Texture{GLint,4,1},
                            Texture{GLshort,1,1}, Texture{GLshort,2,1}, Texture{GLshort,3,1}, Texture{GLshort,4,1},
                            Texture{GLbyte,1,1}, Texture{GLbyte,2,1}, Texture{GLbyte,3,1}, Texture{GLbyte,4,1}],

    GL_INT_SAMPLER_2D   => [Texture{GLint,1,2}, Texture{GLint,2,2}, Texture{GLint,3,2}, Texture{GLint,4,2}, 
                            Texture{GLshort,1,2}, Texture{GLshort,2,2}, Texture{GLshort,3,2}, Texture{GLshort,4,2},
                            Texture{GLbyte,1,2}, Texture{GLbyte,2,2}, Texture{GLbyte,3,2}, Texture{GLbyte,4,2}],

    GL_INT_SAMPLER_3D   => [Texture{GLint,1,3}, Texture{GLint,2,3}, Texture{GLint,3,3}, Texture{GLint,4,3},
                            Texture{GLshort,1,3}, Texture{GLshort,2,3}, Texture{GLshort,3,3}, Texture{GLshort,4,3},
                            Texture{GLbyte,1,3}, Texture{GLbyte,2,3}, Texture{GLbyte,3,3}, Texture{GLbyte,4,3}],
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
function is_correct_uniform_type{T <: FixedPoint, N, D}(targetuniform::GLenum, tocheck::Texture{T, N, D})
    return true
end
function uniform_type(targetuniform::GLenum)
    if haskey(UNIFORM_TYPE_ENUM_DICT, targetuniform)
        return UNIFORM_TYPE_ENUM_DICT[targetuniform]
    else
        error("Unrecognized Uniform Enum. Enum found: ", GLENUM(targetuniform).name)
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
function attribute_name_type(program::GLuint)
    uniformLength   = glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES)
    if uniformLength == 0
        return ()
    else
        nametypelist = ntuple(uniformLength, i -> glGetActiveAttrib(program, i-1)[1:2]) # take size and name
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


export gluniform, toglsltype_string

