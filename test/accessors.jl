using GLAbstraction, GLWindow, ModernGL
immutable Vec3 <: AbstractFixedVector{Float32, 3}
    x::Float32
    y::Float32
    z::Float32
end
Vec3() = Vec3(0f0,0f0,0f0)
Base.length(::Type{Vec3}) = 3
Base.eltype(::Type{Vec3}) = Float32
createwindow("asd", 2,2)
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

