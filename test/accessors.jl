using GLAbstraction,GLVisualize, GLWindow, ModernGL, GeometryTypes, AbstractGPUArray, FixedPointNumbers
using Base.Test

a = GLVisualize.GLSpriteStyle[GLVisualize.GLSpriteStyle(i,0) for i=1:20]
tgpua = texture_buffer(a)
a[1:10] = GLVisualize.GLSpriteStyle[GLVisualize.GLSpriteStyle(77, 0) for i=1:10]
tgpua[1:10] = GLVisualize.GLSpriteStyle[GLVisualize.GLSpriteStyle(77, 0) for i=1:10]
println(a)
println(gpu_data(tgpua))



const TEST_1D = Any[]
const TEST_2D = Any[]

const N = 21 # some prime number to make things nasty
# Generate some data
push!(TEST_1D, rand(Float32, N*N))
push!(TEST_1D, rand(Int32, N*N))
push!(TEST_1D, Point3{Float32}[rand(Point3{Float32}) for i=1:N*N])
push!(TEST_1D, Point4{Ufixed8}[rand(Point4{Float32}) for i=1:N*N])
push!(TEST_1D, Point4{Int8}[rand(Point4{Int8}) for i=1:N*N])
#push!(TEST_1D, Point3{Uint8}[rand(Point3{Uint8}) for i=1:N*N]) #unaligned

push!(TEST_2D, rand(Float32, N,N))
push!(TEST_2D, rand(Int32, N,N))
push!(TEST_2D, Point3{Float32}[rand(Point3{Float32}) for i=1:N,j=1:N])
push!(TEST_2D, Point4{Ufixed8}[rand(Point4{Float32}) for i=1:N,j=1:N])
push!(TEST_2D, Point4{Int8}[rand(Point4{Int8}) for i=1:N,j=1:N])
#push!(TEST_2D, Point3{Uint8}[rand(Point3{Uint8}) for i=1:N,j=1:N]) #unaligned


test_data = Dict(
	TEST_1D 	=> map(Texture, TEST_1D),
	TEST_1D 	=> map(texture_buffer, TEST_1D),
	TEST_1D 	=> map(GLBuffer, TEST_1D),
	TEST_2D		=> map(Texture, TEST_2D)
)

function test()
	for (origins, gpu_arrays) in test_data
		from_gpu = map(gpu_data, gpu_arrays)
		@test from_gpu == origins
		for (origin, gpu_array) in zip(origins, gpu_arrays)
			if ndims(gpu_array) == 1
				newdata 		= copy(origin[11:20])
				origin[1:10] 	= newdata
					gpu_array[1:10] = newdata
				@test origin == gpu_data(gpu_array)
			end
		end
	end
end

test()

