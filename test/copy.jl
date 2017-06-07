using GLAbstraction, GLWindow, StaticArrays
using Base.Test

window = create_glcontext("test", visible = false, debugging = true)

@testset "copy! GLBuffer -> Array" begin
    x = Float32[1, 2, 3, 4, 5]
    xgpu = GLBuffer(x);
    y = zeros(Float32, 5)

    copy!(y, 1, xgpu, 1, 5)

    @test y == x
    y[:] = 0f0
    copy!(y, 3, xgpu, 1, 3)
    @test y == Float32[0, 0, 1, 2, 3]
    y[:] = 0f0
    copy!(y, 3, xgpu, 2, 3)

    @test y == Float32[0, 0, 2, 3, 4]

    @test_throws BoundsError copy!(y, 3, xgpu, 4, 10)
    @test_throws ArgumentError copy!(y, 3, xgpu, 4, -2)
end


@testset "copy! Array -> GLBuffer" begin
    x = Float32[1, 2, 3, 4, 5]
    y = zeros(Float32, 5)
    ygpu = GLBuffer(y);
    tmp = Vector{Float32}(5)

    copy!(ygpu, 1, x, 1, 5)

    copy!(tmp, 1, ygpu, 1, 5) # transfer to main memory
    copy!(ygpu, 1, y, 1, 5) # restore buffer

    @test tmp == x


    copy!(ygpu, 3, x, 1, 3)

    copy!(tmp, 1, ygpu, 1, 5) # transfer to main memory
    copy!(ygpu, 1, y, 1, 5) # restore buffer

    @test tmp == Float32[0, 0, 1, 2, 3]

    copy!(ygpu, 3, x, 2, 3)
    copy!(tmp, 1, ygpu, 1, 5) # transfer to main memory
    copy!(ygpu, 1, y, 1, 5) # restore buffer

    @test tmp == Float32[0, 0, 2, 3, 4]

    @test_throws BoundsError copy!(ygpu, 3, x, 4, 10)
    @test_throws ArgumentError copy!(ygpu, 3, x, 4, -2)
end


@testset "copy! GLBuffer -> GLBuffer" begin
    x = Float32[1, 2, 3, 4, 5]
    y = zeros(Float32, 5)
    xgpu = GLBuffer(x);
    ygpu = GLBuffer(y);
    tmp = Vector{Float32}(5)

    copy!(ygpu, 1, xgpu, 1, 5)

    copy!(tmp, 1, ygpu, 1, 5) # transfer to main memory
    copy!(ygpu, 1, y, 1, 5) # restore buffer

    @test tmp == x


    copy!(ygpu, 3, xgpu, 1, 3)

    copy!(tmp, 1, ygpu, 1, 5) # transfer to main memory
    copy!(ygpu, 1, y, 1, 5) # restore buffer

    @test tmp == Float32[0, 0, 1, 2, 3]

    copy!(ygpu, 3, xgpu, 2, 3)
    copy!(tmp, 1, ygpu, 1, 5) # transfer to main memory
    copy!(ygpu, 1, y, 1, 5) # restore buffer

    @test tmp == Float32[0, 0, 2, 3, 4]

    @test_throws BoundsError copy!(ygpu, 3, xgpu, 4, 10)
    @test_throws ArgumentError copy!(ygpu, 3, xgpu, 4, -2)
end


crange(start, stop) = CartesianRange(CartesianIndex(start), CartesianIndex(stop))


@testset "copy! Texture -> Array" begin
    x = Float32[1, 2, 3, 4, 5]
    tmp = zeros(Float32, 5)
    xgpu = Texture(x);

    copy!(tmp, xgpu)
    @test tmp == x

    toosmall = Vector{Float32}(1)
    @test_throws ArgumentError copy!(toosmall, xgpu)

    x = SVector{3, Float32}[(1,1,77), (2,2,3), (4,4,4), (3,3,3)]
    tmp = zeros(SVector{3, Float32}, 4)
    xgpu = Texture(x);

    copy!(tmp, xgpu)
    @test tmp == x

    x = rand(Float32, 23, 27)
    tmp = similar(x)
    xgpu = Texture(x);
    copy!(tmp, xgpu)

    @test tmp == x

    x = rand(Float32, 23, 27, 33)
    tmp = similar(x)
    xgpu = Texture(x)
    copy!(tmp, xgpu)

    @test tmp == x

end


@testset "copy! Array -> Texture" begin
    x = Float32[1, 2, 3, 4, 5]
    y =
    tmp = Vector{Float32}(5)
    ygpu = Texture(y);
    full = crange(1, 5)
    copy!(ygpu, full, x, full)

    copy!(tmp, ygpu) # transfer to main memory
    copy!(ygpu, full, zeros(Float32, 5), full) # restore buffer

    @test tmp == x

    copy!(ygpu, crange(3, 5), x, crange(1, 5))
    tmp[:] = 0f0
    copy!(tmp, ygpu) # transfer to main memory
    copy!(ygpu, full, y, full) # restore buffer
    @test tmp == Float32[0, 0, 1, 2, 3]

    copy!(ygpu, full, zeros(Float32, 5), full) # restore buffer
    copy!(ygpu, crange(1, 3), x, crange(3, 5))
    copy!(tmp, ygpu) # transfer to main memory
    @test tmp == Float32[3, 4, 5, 0, 0]

    @test_throws BoundsError copy!(ygpu, crange(1, 7), x, crange(3, 5))
    @test_throws BoundsError copy!(ygpu, crange(1, 2), x, crange(-1, 5))

    y2d = rand(Float32, 23, 18)
    y2dgpu = Texture(zeros(Float32, 23, 18));
    tmp = similar(y2d)
    full = crange((1, 1), (23, 18))
    copy!(y2dgpu, full, y2d, full)

    copy!(tmp, y2dgpu) # transfer to main memory
    @test tmp == y2d
    for i = 1:3
        dims = ntuple(x-> rand(5:10), i)
        y2d = rand(Float32, dims)
        y2dgpu = Texture(zeros(Float32, dims));
        tmp = zeros(Float32, dims)
        y2dcpu = zeros(Float32, dims)
        start = ntuple(i) do x
            rand(1:dims[x])
        end
        stop = ntuple(i) do x
            s = start[x]
            s + rand(0:(dims[x] - s))
        end
        off = crange(start, stop)
        copy!(y2dgpu, off, y2d, off)
        copy!(y2dcpu, off, y2d, off)
        copy!(tmp, y2dgpu)
        @testset "$i D copies" begin
            @test tmp == y2dcpu
        end
    end

end

@testset "copy! Texture -> Texture" begin
    dims = (23, 34)
    x = rand(Float32, dims)
    tmp = zeros(Float32, dims)

    xgpu = Texture(x);
    ygpu = Texture(tmp);

    copy!(ygpu, crange((1, 1), dims), xgpu, crange((1, 1), dims));
    copy!(tmp, ygpu)
    @test tmp == x

    tmp2 = zeros(Float32, dims)
    copy!(ygpu, crange((1, 1), dims), tmp2, crange((1, 1), dims)); # reset ygpu

    copy!(ygpu, crange((4, 2), (21, 9)), xgpu, crange((1, 27), (18, 34)));
    copy!(tmp2, crange((4, 2), (21, 9)), x,    crange((1, 27), (18, 34)));
    copy!(tmp, ygpu)
    @test tmp == tmp2

    @test_throws BoundsError copy!(ygpu, crange((4, 77), (21, 9)), xgpu, crange((1, 27), (18, 34)));

end
