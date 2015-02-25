# Uniforms are OpenGL variables that stay the same for the entirety of a drawcall.
# There are a lot of functions, to upload them, as OpenGL doesn't rely on multiple dispatch.
# here is my approach, to handle all of the uniforms with one function, namely gluniform
# For uniforms, the Vector and Matrix types from ImmutableArrays should be used, as they map the relation almost 1:1

GLSL_COMPATIBLE_NUMBER_TYPES = [GLdouble, GLfloat, GLint, GLuint]

GLSL_PREFIX = @compat Dict(
	GLdouble 	=> "d", 
	GLfloat 	=> "", 
	GLint 		=> "i", 
    GLuint      => "u",
    Uint8       => "u",
    Uint16      => "u"
)

GL_POSTFIX = @compat Dict(
	GLdouble 	=> "dv", 
	GLfloat 	=> "fv", 
	GLint 		=> "iv", 
	GLuint 		=> "uiv"
)

# Generates uniform upload functions for ImmutableArrays.
# Also it defines glsl alike aliases and constructors.
# This probably shouldn't be done in the same function, but its for now the easiest solution.
macro genuniformfunctions(maxdim::Integer)
	glslVector  = "Vec"
	glslMatrix  = "Mat"

	imVector    = "Vector"
	imMatrix    = "Matrix"
	expressions = Any[]
    
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
		push!(expressions, :(gluniform(location::Integer, x::$imalias) 		   = (tmp = [x;] ; $uniformfunc(location, 1, pointer(tmp))))) # uniform function for single uniforms
		push!(expressions, :(gluniform(location::Integer, x::Vector{$imalias}) = $uniformfunc(location, length(x), pointer(x)))) #uniform function for arrays of uniforms
		if n > 1
			push!(expressions, :($glslalias(x::Real) = $name(convert($typ, x)))) # Single valued constructor
		end
		push!(expressions, Expr(:export, glslalias))
		

		#########################################################################
        if n != 1
            push!(expressions, :(toglsltype_string(x::Type{$imalias}) = $(lowercase(string("uniform ", glslalias))))) # method for shader type mapping
            push!(expressions, :(toglsltype_string(x::$imalias) 	  = $(lowercase(string("uniform ", glslalias))))) # method for shader type mapping
        end
	end
	for n=2:maxdim, n2=2:maxdim, typ in [GLdouble, GLfloat]
		glsldim 	= n==n2 ? "$n" : "$(n)x$(n2)"
		glslalias 	= symbol(string(GLSL_PREFIX[typ], glslMatrix, glsldim)) 
		name 		= symbol(string(imMatrix, n,"x",n2))
		imalias 	= :($name {$typ})
		uniformfunc = symbol(string("glUniformMatrix", glsldim, GL_POSTFIX[typ]))

		push!(expressions, :(typealias $glslalias $imalias)) #GLSL alike alias
		push!(expressions, :(gluniform(location::Integer, x::$imalias) = (tmp = [x;] ; $uniformfunc(location, 1, GL_FALSE, pointer(tmp))))) # uniform function for single uniforms
		push!(expressions, :(gluniform(location::Integer, x::Vector{$imalias}) = $uniformfunc(location, length(x), GL_FALSE, pointer(x)))) #uniform function for arrays of uniforms
		push!(expressions, :($glslalias(x::Real) = $name(convert($typ, x)))) # Single valued constructor
		push!(expressions, Expr(:export, glslalias))
		#########################################################################
		push!(expressions, :(toglsltype_string(x::$imalias) = $(lowercase(string("uniform ", glslalias))))) # method for shader type mapping
	end
	return esc(Expr(:block, expressions...))
end

# Extend Vector class a bit
Base.length{T}(::Type{Vector1{T}}) = 1
Base.length{T}(::Type{Vector2{T}}) = 2
Base.length{T}(::Type{Vector3{T}}) = 3
Base.length{T}(::Type{Vector4{T}}) = 4

Base.size{T}(::Type{Matrix4x4{T}}) = (4,4)
Base.size{T}(::Type{Matrix3x3{T}}) = (3,3)
Base.size{T}(::Type{Matrix2x2{T}}) = (2,2)

Base.size{T}(::Type{Matrix2x4{T}}) = (2,4)
Base.size{T}(::Type{Matrix3x4{T}}) = (3,4)

Base.size{T}(::Type{Matrix2x3{T}}) = (2,3)
Base.size{T}(::Type{Matrix4x3{T}}) = (4,3)

Base.size{T}(::Type{Matrix3x2{T}}) = (3,2)
Base.size{T}(::Type{Matrix4x2{T}}) = (4,2)

@genuniformfunctions 4 

#Some additional uniform functions, not related to Imutable Arrays
gluniform(location::Integer, target::Integer, t::Texture) = gluniform(convert(GLint, location), convert(GLint, target), t)
gluniform(location::Integer, target::Integer, t::Signal)  = gluniform(convert(GLint, location), convert(GLint, target), t.value)
function gluniform(location::GLint, target::GLint, t::Texture)
    activeTarget = GL_TEXTURE0 + uint32(target)
    glActiveTexture(activeTarget)
    glBindTexture(t.texturetype, t.id)
    gluniform(location, target)
end
gluniform(location::Integer, x::Signal) = gluniform(location, x.value)

gluniform(location::Integer, x::Union(GLubyte, GLushort, GLuint)) 		 = glUniform1ui(location, x)
gluniform(location::Integer, x::Union(GLbyte, GLshort, GLint, Bool)) 	 = glUniform1i(location, x)

# Needs to be 
gluniform(location::Integer, x::RGB{Float32}) 		     				 = (tmp = [x;] ; glUniform3fv(location, 1, convert(Ptr{Float32}, pointer(tmp))))
gluniform(location::Integer, x::AlphaColorValue{RGB{Float32}, Float32})  = (tmp = [x;] ; glUniform4fv(location, 1, convert(Ptr{Float32}, pointer(tmp))))

gluniform{T <: AbstractRGB}(location::Integer, x::Vector{T}) 			 = gluniform(location, reinterpret(Vector3{eltype(T)}, x))
gluniform{T <: AbstractAlphaColorValue}(location::Integer, x::Vector{T}) = gluniform(location, reinterpret(Vector4{eltype(T)}, x))

#Uniform upload functions for julia arrays...
gluniform(location::GLint, x::Vector{Float32}) 	= glUniform1fv(location, length(x), pointer(x))
gluniform(location::GLint, x::Vector{GLint}) 	= glUniform1iv(location, length(x), pointer(x))
gluniform(location::GLint, x::Vector{GLuint}) 	= glUniform1uiv(location, length(x), pointer(x))


glsl_prefix(x::DataType) = GLSL_PREFIX[x]
glsl_prefix{T <: FixedPoint}(x::Type{T}) = ""

toglsltype_string{T, C, D}(t::Texture{T, C, D}) = string("uniform ", glsl_prefix(eltype(T)),"sampler", D, "D")
toglsltype_string(t::GLfloat)                   = "uniform float"
toglsltype_string(t::GLuint)                    = "uniform uint"
toglsltype_string(t::GLint)                     = "uniform int"
toglsltype_string(t::Signal)                    = toglsltype_string(t.value)
toglsltype_string(t::StepRange)                 = toglsltype_string(Vec3(first(t), step(t), last(t)))

toglsltype_string(t::AbstractAlphaColorValue)   = toglsltype_string(Vec4)
toglsltype_string(t::AbstractRGB)               = toglsltype_string(Vec3)

function toglsltype_string(t::GLBuffer)          
    typ = cardinality(t) > 1 ? "vec$(cardinality(t))" : "float"
    "$(get_glsl_in_qualifier_string()) $typ"
end



UNIFORM_TYPES = Union(AbstractArray, ColorValue, AbstractAlphaColorValue)

# This is needed to varify, that the correct uniform is uploaded to a shader
# Should partly be integrated into the genuniformfunctions macro
is_correct_uniform_type(a, b) = false

is_unsigned_uniform_type{T}(::Type{T}) = eltype(T) <: Unsigned
is_integer_uniform_type{T}(::Type{T}) = eltype(T) <: Integer 
is_float_uniform_type{T}(::Type{T}) = eltype(T) <: FloatingPoint || eltype(T) <: FixedPoint
is_bool_uniform_type{T}(::Type{T}) = eltype(T) <: Bool || is_integer_uniform_type(T)


is_correct_uniform_type{AnySym}(x::Signal, glenum::GLENUM{AnySym, GLenum}) = is_correct_uniform_type(x.value, glenum)

is_correct_uniform_type(x::Real, ::GLENUM{:GL_BOOL, GLenum})          = is_bool_uniform_type(typeof(x))
is_correct_uniform_type(x::Real, ::GLENUM{:GL_UNSIGNED_INT, GLenum})  = is_unsigned_uniform_type(typeof(x))
is_correct_uniform_type(x::Real, ::GLENUM{:GL_INT, GLenum})           = is_integer_uniform_type(typeof(x))
is_correct_uniform_type(x::Real, ::GLENUM{:GL_FLOAT, GLenum})         = is_float_uniform_type(typeof(x))

is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_BOOL, GLenum})              = is_bool_uniform_type(T) && length(T) == 1
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_BOOL_VEC2, GLenum})         = is_bool_uniform_type(T) && length(T) == 2
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_BOOL_VEC3, GLenum})         = is_bool_uniform_type(T) && length(T) == 3
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_BOOL_VEC4, GLenum})         = is_bool_uniform_type(T) && length(T) == 4


is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_UNSIGNED_INT, GLenum})      = is_unsigned_uniform_type(T) && length(T) == 1
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_UNSIGNED_INT_VEC2, GLenum}) = is_unsigned_uniform_type(T) && length(T) == 2
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_UNSIGNED_INT_VEC3, GLenum}) = is_unsigned_uniform_type(T) && length(T) == 3
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_UNSIGNED_INT_VEC4, GLenum}) = is_unsigned_uniform_type(T) && length(T) == 4

is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_INT, GLenum})               = is_integer_uniform_type(T) && length(T) == 1
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_INT_VEC2, GLenum})          = is_integer_uniform_type(T) && length(T) == 2
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_INT_VEC3, GLenum}) = is_integer_uniform_type(T) && length(T) == 3
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_INT_VEC4, GLenum}) = is_integer_uniform_type(T) && length(T) == 4

is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT, GLenum})      = is_float_uniform_type(T) && length(T) == 1
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_VEC2, GLenum}) = is_float_uniform_type(T) && length(T) == 2
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_VEC3, GLenum}) = is_float_uniform_type(T) && length(T) == 3
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_VEC4, GLenum}) = is_float_uniform_type(T) && length(T) == 4

is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT2, GLenum}) = is_float_uniform_type(T) && size(T) == (2,2)
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT3, GLenum}) = is_float_uniform_type(T) && size(T) == (3,3)
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT4, GLenum}) = is_float_uniform_type(T) && size(T) == (4,4)

is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT3x2, GLenum}) = is_float_uniform_type(T) && size(T) == (3,2)
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT4x2, GLenum}) = is_float_uniform_type(T) && size(T) == (4,2)

is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT2x3, GLenum}) = is_float_uniform_type(T) && size(T) == (2,3)
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT4x3, GLenum}) = is_float_uniform_type(T) && size(T) == (4,3)

is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT2x3, GLenum}) = is_float_uniform_type(T) && size(T) == (2,3)
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT4x3, GLenum}) = is_float_uniform_type(T) && size(T) == (4,3)

is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT2x4, GLenum}) = is_float_uniform_type(T) && size(T) == (2,4)
is_correct_uniform_type{T <: UNIFORM_TYPES}(::T, ::GLENUM{:GL_FLOAT_MAT3x4, GLenum}) = is_float_uniform_type(T) && size(T) == (3,4)

is_correct_uniform_type{T, C}(::Texture{T, C, 1}, ::GLENUM{:GL_SAMPLER_1D, GLenum}) = is_float_uniform_type(T)
is_correct_uniform_type{T, C}(::Texture{T, C, 2}, ::GLENUM{:GL_SAMPLER_2D, GLenum}) = is_float_uniform_type(T)
is_correct_uniform_type{T, C}(::Texture{T, C, 3}, ::GLENUM{:GL_SAMPLER_3D, GLenum}) = is_float_uniform_type(T)

is_correct_uniform_type{T, C}(::Texture{T, C, 1}, ::GLENUM{:GL_UNSIGNED_INT_SAMPLER_1D, GLenum}) = is_unsigned_uniform_type(T)
is_correct_uniform_type{T, C}(::Texture{T, C, 2}, ::GLENUM{:GL_UNSIGNED_INT_SAMPLER_2D, GLenum}) = is_unsigned_uniform_type(T)
is_correct_uniform_type{T, C}(::Texture{T, C, 3}, ::GLENUM{:GL_UNSIGNED_INT_SAMPLER_3D, GLenum}) = is_unsigned_uniform_type(T)

is_correct_uniform_type{T, C}(::Texture{T, C, 1}, ::GLENUM{:GL_INT_SAMPLER_1D, GLenum}) = is_integer_uniform_type(T)
is_correct_uniform_type{T, C}(::Texture{T, C, 2}, ::GLENUM{:GL_INT_SAMPLER_2D, GLenum}) = is_integer_uniform_type(T)
is_correct_uniform_type{T, C}(::Texture{T, C, 3}, ::GLENUM{:GL_INT_SAMPLER_3D, GLenum}) = is_integer_uniform_type(T)




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
        typ == GL_INT_SAMPLER_1D || typ == GL_INT_SAMPLER_2D || typ == GL_INT_SAMPLER_3D ||
        typ == GL_SAMPLER_1D_ARRAY || typ == GL_SAMPLER_2D_ARRAY ||
        typ == GL_UNSIGNED_INT_SAMPLER_1D_ARRAY || typ == GL_UNSIGNED_INT_SAMPLER_2D_ARRAY ||
        typ == GL_INT_SAMPLER_1D_ARRAY || typ == GL_INT_SAMPLER_2D_ARRAY
    )
end



