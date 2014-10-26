immutable Vec3 <: AbstractFixedVector{Int, 3}
    x::Int
    y::Int
    z::Int
end
Vec3() = Vec3(0,0,0)
Base.length(::Type{Vec3}) = 3
Base.eltype(::Type{Vec3}) = Int

a = [Vec3() Vec3(); Vec3() Vec3()]
setindex1D!(a, [33,33], 2, 1:1)
println(a)