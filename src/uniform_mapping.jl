using ModernGL, GeometryTypes, FixedSizeArrays, GLAbstraction
const JULIA2GL = Dict{DataType, Symbol}(
	Float32 	=> :FLOAT,
	Float64 	=> :DOUBLE,
	GLint   	=> :INT,
	GLuint   	=> :UNSIGNED_INT,
	GLboolean   => :BOOL
)
# reverse the mapping
const GL2JULIA = [value=>key for (key, value) in JULIA2GL]
uniformtype{T}(x::Type{T}) = symbol(string("GL_", JULIA2GL[T]))
uniformtype{NAME, T}(x::GLENUM{NAME, T})  = symbol(string("GL_", GL2JULIA[NAME]))

function uniformtype(dims::(Int, Int)) 
	M, N = dims 
	ending = M==N ? "$M" : "$Mx$N"
	symbol("MAT"*ending)
end
uniformtype(dims::(Int,)) = "VEC$(first(dims))"

function uniformtype{FSA <: FixedArray}(fsa::FSA)
	elemtype = JULIA2GL[eltype(FSA)]
	name = uniformtype(size(FSA))
	GLENUM(symbol(string("GL_", elemtype,"_", name)))
end
function samplertype(elemtype::DataType, rest::AbstractString)
	ndim = match(r"\dD"m, rest).match # extract 1D, 2D, 3D
	ndim = parse(Int, ndim[1:1])
	contains(rest, "ARRAY") && (ndim += 1) # Array textures have one dimension more

	# Without triangle dispatch it's impossible to build a type, which is always the parent of a concrete Texture type
	# consider Texture{Vector3{Float32}, 2} <: Texture{FixedVector{Float32}, 2} == false
	# so for now I just return a function that returns true if the texture applicable
	return (x::Texture -> eltype(x) <: FixedVector{elemtype} && ndims(x) == ndim)
end
function seperate_eltype{NAME, T}(enum::GLENUM{NAME, T})
	name = string(NAME)[4:end] # remove GL_
	startswith(name, "SAMPLER") && return "", name # Eltype can be left out for SAMPLERs
	elemtype_cutoff = startswith(name, "UNSIGNED") ? 2 : 1 # handle UNSIGNED_INT vs e.g. FLOAT_XXXX
	elemtype_cutoff = matchall(r"_", name)[elemtype_cutoff].offset # get the string offset until the next relevant "_"
	name[1:elemtype_cutoff], name[elemtype_cutoff+2:end]
end

function Base.eltype{NAME, T}(enum::GLENUM{NAME, T})
	elemtype_name, rest = seperate_eltype(enum)
	elemtype_name == "" && return Float32 # For OpenGL no eltype means Float32
	return GL2JULIA[symbol(elemtype_name)]
end
function uniformtype{NAME, T}(enum::GLENUM{NAME, T})
	elemtype = eltype(enum)
	_, name = seperate_eltype(enum)
	startswith(name, "SAMPLER") && return Texture # can't do much better without triangular dispatch
	if startswith(name, "VEC")
		dim = parse(Int, name[4:end])
		return FixedVector{elemtype, dim}
	end
	if startswith(name, "MAT")
		dims = map(d -> parse(Int, d), tuple(split(name[4:end], "x")...)) # transform Mat4x3, Mat4 -> (4,3), (4)
		M,N = length(dims) == 2 ? dims : (dims[1], dims[1])
		return FixedMatrix{elemtype, M,N}
	end
	error("Unkown uniform enum: $NAME")
end
@assert uniformtype(GLENUM(:GL_DOUBLE_VEC4)) 		== FixedVector{Float64, 4}
@assert uniformtype(GLENUM(:GL_FLOAT_VEC3)) 		== FixedVector{Float32, 3}
@assert uniformtype(GLENUM(:GL_UNSIGNED_INT_VEC3)) 	== FixedVector{GLuint, 3}

@assert uniformtype(GLENUM(:GL_FLOAT_MAT2x4)) 		== FixedMatrix{Float32, 2, 4}
@assert uniformtype(GLENUM(:GL_FLOAT_MAT2x3)) 		== FixedMatrix{Float32, 2, 3}
@assert uniformtype(GLENUM(:GL_DOUBLE_MAT4)) 		== FixedMatrix{Float64, 4, 4}
@assert Matrix4x4{Float64} <: uniformtype(GLENUM(:GL_DOUBLE_MAT4))


@assert uniformtype(GLENUM(:GL_SAMPLER_1D_SHADOW)) 		== Texture

#=
@assert :GL_FLOAT == uniformtype(Float32)
:GL_FLOAT_VEC2
:GL_FLOAT_VEC3 
:GL_FLOAT_VEC4
:GL_DOUBLE 
:GL_DOUBLE_VEC2 
:GL_DOUBLE_VEC3 
:GL_DOUBLE_VEC4
:GL_INT 
:GL_INT_VEC2
:GL_INT_VEC3
:GL_INT_VEC4
:GL_UNSIGNED_INT 
:GL_UNSIGNED_INT_VEC2
:GL_UNSIGNED_INT_VEC3
:GL_UNSIGNED_INT_VEC4
:GL_BOOL
:GL_BOOL_VEC2
:GL_BOOL_VEC3
:GL_BOOL_VEC4 
:GL_FLOAT_MAT2   
:GL_FLOAT_MAT3   
:GL_FLOAT_MAT4   
:GL_FLOAT_MAT2x3 
:GL_FLOAT_MAT2x4 
:GL_FLOAT_MAT3x2
:GL_FLOAT_MAT3x4 
:GL_FLOAT_MAT4x2 
:GL_FLOAT_MAT4x3 
:GL_DOUBLE_MAT2  dmat2
:GL_DOUBLE_MAT3  dmat3
GL_DOUBLE_MAT4  dmat4
GL_DOUBLE_MAT2x3    dmat2x3
GL_DOUBLE_MAT2x4    dmat2x4
GL_DOUBLE_MAT3x2    dmat3x2
GL_DOUBLE_MAT3x4    dmat3x4
GL_DOUBLE_MAT4x2    dmat4x2
GL_DOUBLE_MAT4x3    dmat4x3
GL_SAMPLER_1D   sampler1D
GL_SAMPLER_2D   sampler2D
GL_SAMPLER_3D   sampler3D
GL_SAMPLER_CUBE samplerCube
GL_SAMPLER_1D_SHADOW    sampler1DShadow
GL_SAMPLER_2D_SHADOW    sampler2DShadow
GL_SAMPLER_1D_ARRAY sampler1DArray
GL_SAMPLER_2D_ARRAY sampler2DArray
GL_SAMPLER_1D_ARRAY_SHADOW  sampler1DArrayShadow
GL_SAMPLER_2D_ARRAY_SHADOW  sampler2DArrayShadow
GL_SAMPLER_2D_MULTISAMPLE   sampler2DMS
GL_SAMPLER_2D_MULTISAMPLE_ARRAY sampler2DMSArray
GL_SAMPLER_CUBE_SHADOW  samplerCubeShadow
GL_SAMPLER_BUFFER   samplerBuffer
GL_SAMPLER_2D_RECT  sampler2DRect
GL_SAMPLER_2D_RECT_SHADOW   sampler2DRectShadow
GL_INT_SAMPLER_1D   isampler1D
GL_INT_SAMPLER_2D   isampler2D
GL_INT_SAMPLER_3D   isampler3D
GL_INT_SAMPLER_CUBE isamplerCube
GL_INT_SAMPLER_1D_ARRAY isampler1DArray
GL_INT_SAMPLER_2D_ARRAY isampler2DArray
GL_INT_SAMPLER_2D_MULTISAMPLE   isampler2DMS
GL_INT_SAMPLER_2D_MULTISAMPLE_ARRAY isampler2DMSArray
GL_INT_SAMPLER_BUFFER   isamplerBuffer
GL_INT_SAMPLER_2D_RECT  isampler2DRect
GL_UNSIGNED_INT_SAMPLER_1D  usampler1D
GL_UNSIGNED_INT_SAMPLER_2D  usampler2D
GL_UNSIGNED_INT_SAMPLER_3D  usampler3D
GL_UNSIGNED_INT_SAMPLER_CUBE    usamplerCube
GL_UNSIGNED_INT_SAMPLER_1D_ARRAY    usampler2DArray
GL_UNSIGNED_INT_SAMPLER_2D_ARRAY    usampler2DArray
GL_UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE  usampler2DMS
GL_UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE_ARRAY    usampler2DMSArray
GL_UNSIGNED_INT_SAMPLER_BUFFER  usamplerBuffer
GL_UNSIGNED_INT_SAMPLER_2D_RECT
=#