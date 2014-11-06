using GLAbstraction, GLWindow, ModernGL
immutable Vec3 <: AbstractFixedVector{Float32, 3}
    x::Float32
    y::Float32
    z::Float32
end
Vec3() = Vec3(0f0,0f0,0f0)
Base.length(::Type{Vec3}) = 3
Base.eltype(::Type{Vec3}) = Float32
createwindow("test", 2,2)
tdata = [Vec3() Vec3(); Vec3() Vec3()]
test_assert = [Vec3(33,0,0) Vec3(55,55,0); Vec3(44,44,0) Vec3(33,77,77)]
a = copy(tdata)
b = Texture(copy(tdata), keepinram=true)

setindex1D!(a, 33, 1, 1)
setindex1D!(a, 33, 2, 1)
setindex1D!(a, 33, 3, 1)
setindex1D!(a, 33, 4, 1)
setindex1D!(a, [44,44], 2, 1:2)
setindex1D!(a, [55,55], 3, 1:2)
setindex1D!(a, [77,77], 4, 2:3)


setindex1D!(b, 33, 1, 1)
setindex1D!(b, 33, 2, 1)
setindex1D!(b, 33, 3, 1)
setindex1D!(b, 33, 4, 1)
setindex1D!(b, [44,44], 2, 1:2)
setindex1D!(b, [55,55], 3, 1:2)
setindex1D!(b, [77,77], 4, 2:3)

result = Array(Vec3, b.dims...)
glBindTexture(b.texturetype, b.id)
glGetTexImage(b.texturetype, 0, b.format, b.pixeltype, result)

println(a)
println(result)
println(b.data)

println(test_assert)
@assert a == result
@assert b.data == result
@assert test_assert == result

test_data = zeros(Float32, 5,5)
a = Texture(copy(test_data), keepinram=true)

a[1] = 66f0
a[2] = 57f0
a[3] = 77f0
a[end-1] = 66f0
a[end-2] = 57f0
a[end-3] = 77f0

a[1,3] = 784f0
a[3,2] = 999f0

test_data[1] = 66f0
test_data[2] = 57f0
test_data[3] = 77f0
test_data[end-1] = 66f0
test_data[end-2] = 57f0
test_data[end-3] = 77f0

test_data[1,3] = 784f0
test_data[3,2] = 999f0

result = Array(Float32, a.dims...)
glBindTexture(a.texturetype, a.id)
glGetTexImage(a.texturetype, 0, a.format, a.pixeltype, result)
println(a.data)
println("---------------------")
println(result)
println("---------------------")
println(test_data)
@assert a.data == result
@assert a.data == test_data


test_data = rand(Float32, 5,5)
a = Texture(copy(test_data), keepinram=true)

test_data[1:4,5] = Float32[0,1,2,3]
test_data[5,1:4] = Float32[0,1,2,3]

test_data[2:5,3:5] = eye(Float32, 4, 3)
test_data[1:end,1:2] = eye(Float32, 5, 2)

a[1:4,5] = Float32[0,1,2,3]
a[5,1:4] = Float32[0,1,2,3]

a[2:5,3:5] = eye(Float32, 4, 3)
a[1:end,1:2] = eye(Float32, 5, 2)




result = Array(Float32, a.dims...)
glBindTexture(a.texturetype, a.id)
glGetTexImage(a.texturetype, 0, a.format, a.pixeltype, result)
println(a.data)
println("---------------------")
println(result)
println("---------------------")
println(test_data)
@assert a.data == result
@assert a.data == test_data