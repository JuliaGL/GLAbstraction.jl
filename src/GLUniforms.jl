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
		push!(expressions, :(gluniform(location::GLint, x::$imalias) = $uniformfunc(location, 1, [x]))) # uniform function for single uniforms
		push!(expressions, :(gluniform(location::GLint, x::Vector{$imalias}) = $uniformfunc(location, length(x), pointer(x)))) #uniform function for arrays of uniforms
		push!(expressions, :($glslalias(x::Real) = $name(convert($typ, x)))) # Single valued constructor
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
		push!(expressions, :(gluniform(location::GLint, x::$imalias) = $uniformfunc(location, 1, GL_FALSE, [x]))) # uniform function for single uniforms
		push!(expressions, :(gluniform(location::GLint, x::Vector{$imalias}) = $uniformfunc(location, length(x), GL_FALSE, pointer(x)))) #uniform function for arrays of uniforms
		push!(expressions, :($glslalias(x::Real) = $name(convert($typ, x)))) # Single valued constructor
		push!(expressions, Expr(:export, glslalias))
		#########################################################################
		push!(expressions, :(toglsl(x::$imalias) = $(string(glslalias)))) # method for shader type mapping
	end
	return esc(Expr(:block, expressions...))
end

@genuniformfunctions 4 

function gluniform(location::GLint, target::GLint, t::Texture)
    activeTarget = GL_TEXTURE0 + uint32(target)
    glActiveTexture(activeTarget)
    glBindTexture(texturetype(t), t.id)
    gluniform(location, target)
end
toglsl{T, C, D}(t::Texture{T, C, D}) = string(GLSL_PREFIX[T],"sampler", D, "D")

toglsl(t::GLfloat) = "float"
toglsl(t::GLuint) = "uint"
toglsl(t::GLint) = "int"

gluniform(location::GLint, x::Signal) = gluniform(location, x.value)

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



export gluniform, toglsl








#=
function genuniformfunctions(maxdim::Integer)
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

		@eval typealias $glslalias $imalias # glsl alike type alias
		@eval gluniform(location::GLint, x::$imalias) = $uniformfunc(location, 1, [x]) # uniform function for single uniforms
		@eval gluniform(location::GLint, x::Vector{$imalias}) = $uniformfunc(location, length(x), pointer(x)) #uniform function for arrays of uniforms
		@eval $glslalias(x::Real) = $name(convert($typ, x)) # Single valued constructor
		

		#########################################################################
		@eval toglsl(x::$imalias) = $(string(glslalias)) # method for shader type mapping

	end
	for n=2:maxdim, n2=2:maxdim, typ in [GLdouble, GLfloat]
		glsldim 	= n==n2 ? "$n" : "$(n)x$(n2)"
		glslalias 	= symbol(string(GLSL_PREFIX[typ], glslmatrix, glsldim)) 
		name 		= symbol(string(immatrix, n,"x",n2))
		imalias 	= :($name {$typ})
		uniformfunc = symbol(string("glUniformMatrix", glsldim, GL_POSTFIX[typ]))

		@eval typealias $glslalias $imalias #GLSL alike alias
		@eval gluniform(location::GLint, x::$imalias) = $uniformfunc(location, 1, GL_FALSE, [x]) # uniform function for single uniforms
		@eval gluniform(location::GLint, x::Vector{$imalias}) = $uniformfunc(location, length(x), GL_FALSE, pointer(x)) #uniform function for arrays of uniforms
		@eval $glslalias(x::Real) = $name(convert($typ, x)) # Single valued constructor
		#########################################################################
		@eval toglsl(x::$imalias) = $(string(glslalias)) # method for shader type mapping
	end
end
=#