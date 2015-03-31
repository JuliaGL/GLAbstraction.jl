# Uniforms are OpenGL variables that stay the same for the entirety of a drawcall.
# There are a lot of functions, to upload them, as OpenGL doesn't rely on multiple dispatch.
# here is my approach, to handle all of the uniforms with one function, namely gluniform
# For uniforms, the Vector and Matrix types from ImmutableArrays should be used, as they map the relation almost 1:1

GLSL_COMPATIBLE_NUMBER_TYPES = [GLdouble, GLfloat, GLint, GLuint]

GLSL_PREFIX = Dict(
	GLdouble 	=> "d", 
	GLfloat 	=> "", 
	GLint 		=> "i", 
    GLuint      => "u",
    Uint8       => "u",
    Uint16      => "u"
)

GL_POSTFIX = Dict(
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
    
	for n=2:maxdim, typ in GLSL_COMPATIBLE_NUMBER_TYPES
		glslalias 	= symbol(string(GLSL_PREFIX[typ],glslVector,n)) 
		name 		= symbol(string(imVector, n))
		imalias 	= :($name {$typ})
		uniformfunc = symbol(string("glUniform", n, GL_POSTFIX[typ]))

		push!(expressions, :(typealias $glslalias $imalias)) # glsl alike type alias
		push!(expressions, Expr(:export, glslalias))

		#########################################################################
        push!(expressions, :(toglsltype_string(x::Type{$imalias}) = $(lowercase(string("uniform ", glslalias))))) # method for shader type mapping
        push!(expressions, :(toglsltype_string(x::$imalias) 	  = $(lowercase(string("uniform ", glslalias))))) # method for shader type mapping
	end
	for n=2:maxdim, n2=2:maxdim, typ in [GLdouble, GLfloat]
		glsldim 	= n==n2 ? "$n" : "$(n)x$(n2)"
		glslalias 	= symbol(string(GLSL_PREFIX[typ], glslMatrix, glsldim)) 
		name 		= symbol(string(imMatrix, n,"x",n2))
		imalias 	= :($name {$typ})
		uniformfunc = symbol(string("glUniformMatrix", glsldim, GL_POSTFIX[typ]))

		push!(expressions, :(typealias $glslalias $imalias)) #GLSL alike alias
		push!(expressions, Expr(:export, glslalias))
		#########################################################################
		push!(expressions, :(toglsltype_string(x::$imalias) = $(lowercase(string("uniform ", glslalias))))) # method for shader type mapping
	end
	return esc(Expr(:block, expressions...))
end

@genuniformfunctions 4 


function uniformfunc(typ::DataType, dims::(Int,))
    func = symbol(string("glUniform", first(dims), GL_POSTFIX[typ]))
    
end
function uniformfunc(typ::DataType, dims::(Int, Int))
    M,N = dims
    func = symbol(string("glUniformMatrix", M==N ? "$M":"$(M)x$(N)", GL_POSTFIX[typ]))
end

function gluniform{FSA <: FixedArray}(location::Integer, x::FSA)
    x = [x]
    gluniform(location, x)
end
stagedfunction gluniform{FSA <: FixedArray}(location::Integer, x::Vector{FSA})
    func = uniformfunc(eltype(FSA), size(FSA))
    if ndims(FSA) == 2 
        :($func(location, length(x), GL_FALSE, pointer(x)))
    else
        :($func(location, length(x), pointer(x)))
    end
end


#Some additional uniform functions, not related to Imutable Arrays
gluniform(location::Integer, target::Integer, t::Texture) = gluniform(convert(GLint, location), convert(GLint, target), t)
gluniform(location::Integer, target::Integer, t::Signal)  = gluniform(convert(GLint, location), convert(GLint, target), t.value)
function gluniform(location::GLint, target::GLint, t::Texture)
    activeTarget = GL_TEXTURE0 + UInt32(target)
    glActiveTexture(activeTarget)
    glBindTexture(t.texturetype, t.id)
    gluniform(location, target)
end
gluniform(location::Integer, x::Signal)                                  = gluniform(location, x.value)
gluniform(location::Integer, x::Union(GLubyte, GLushort, GLuint)) 		 = glUniform1ui(location, x)
gluniform(location::Integer, x::Union(GLbyte, GLshort, GLint, Bool)) 	 = glUniform1i(location, x)
gluniform(location::Integer, x::GLfloat) 	 							 = glUniform1f(location, x)

#Uniform upload functions for julia arrays...
gluniform(location::GLint, x::Vector{Float32}) 	= glUniform1fv(location, length(x), pointer(x))
gluniform(location::GLint, x::Vector{GLint}) 	= glUniform1iv(location, length(x), pointer(x))
gluniform(location::GLint, x::Vector{GLuint}) 	= glUniform1uiv(location, length(x), pointer(x))


glsl_prefix(x::DataType) = GLSL_PREFIX[x]
glsl_prefix{T <: FixedPoint}(x::Type{T}) = ""

toglsltype_string{T, D}(t::Texture{T, D}) = string("uniform ", glsl_prefix(eltype(T)),"sampler", D, "D")
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




UNIFORM_TYPES = FixedArray

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

is_correct_uniform_type{T}(::Texture{T, 1}, ::GLENUM{:GL_SAMPLER_1D, GLenum}) = is_float_uniform_type(T)
is_correct_uniform_type{T}(::Texture{T, 2}, ::GLENUM{:GL_SAMPLER_2D, GLenum}) = is_float_uniform_type(T)
is_correct_uniform_type{T}(::Texture{T, 3}, ::GLENUM{:GL_SAMPLER_3D, GLenum}) = is_float_uniform_type(T)

is_correct_uniform_type{T}(::Texture{T, 1}, ::GLENUM{:GL_UNSIGNED_INT_SAMPLER_1D, GLenum}) = is_unsigned_uniform_type(T)
is_correct_uniform_type{T}(::Texture{T, 2}, ::GLENUM{:GL_UNSIGNED_INT_SAMPLER_2D, GLenum}) = is_unsigned_uniform_type(T)
is_correct_uniform_type{T}(::Texture{T, 3}, ::GLENUM{:GL_UNSIGNED_INT_SAMPLER_3D, GLenum}) = is_unsigned_uniform_type(T)

is_correct_uniform_type{T}(::Texture{T, 1}, ::GLENUM{:GL_INT_SAMPLER_1D, GLenum}) = is_integer_uniform_type(T)
is_correct_uniform_type{T}(::Texture{T, 2}, ::GLENUM{:GL_INT_SAMPLER_2D, GLenum}) = is_integer_uniform_type(T)
is_correct_uniform_type{T}(::Texture{T, 3}, ::GLENUM{:GL_INT_SAMPLER_3D, GLenum}) = is_integer_uniform_type(T)




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
        return Dict{Symbol, GLenum}()    
    else
        nametypelist = ntuple(uniformLength, i -> glGetActiveUniform(program, i-1)[1:2]) # take size and name
        return Dict{Symbol, GLenum}(nametypelist)
    end
end
function attribute_name_type(program::GLuint)
    uniformLength   = glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES)
    if uniformLength == 0
        return ()
    else
        nametypelist = [begin 
        	name, typ = glGetActiveAttrib(program, i-1) 
        	name => typ 
        	end for i=0:uniformLength-1] # take size and name
        return Dict{Symbol, GLenum}(nametypelist)
    end
end
function istexturesampler(typ::GLenum)
    return (
    	typ == GL_IMAGE_2D ||
        typ == GL_SAMPLER_1D || typ == GL_SAMPLER_2D || typ == GL_SAMPLER_3D ||  
        typ == GL_UNSIGNED_INT_SAMPLER_1D || typ == GL_UNSIGNED_INT_SAMPLER_2D || typ == GL_UNSIGNED_INT_SAMPLER_3D ||
        typ == GL_INT_SAMPLER_1D || typ == GL_INT_SAMPLER_2D || typ == GL_INT_SAMPLER_3D ||
        typ == GL_SAMPLER_1D_ARRAY || typ == GL_SAMPLER_2D_ARRAY ||
        typ == GL_UNSIGNED_INT_SAMPLER_1D_ARRAY || typ == GL_UNSIGNED_INT_SAMPLER_2D_ARRAY ||
        typ == GL_INT_SAMPLER_1D_ARRAY || typ == GL_INT_SAMPLER_2D_ARRAY
    )
end



