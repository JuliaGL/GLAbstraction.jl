const Vec2 = Vec{2, Float32}
const Vec3 = Vec{3, Float32}
const Vec4 = Vec{4, Float32}

const iVec2 = Vec{2, Cint}
const iVec3 = Vec{3, Cint}
const iVec4 = Vec{4, Cint}

const uVec2 = Vec{2, Cuint}
const uVec3 = Vec{3, Cuint}
const uVec4 = Vec{4, Cuint}

function test_textures()
    N = 100

    t1 = Texture(RGBA{N0f8}, (512,10), minfilter=:nearest, x_repeat=:clamp_to_edge)
    t2 = Texture(Vec{2, GLushort}, (77,91), minfilter=:nearest, x_repeat=:clamp_to_edge)


    intensity2Di = Texture(Cint[0 for i=1:N, j=1:N])
    intensity2Dui = Texture(Cuint[0 for i=1:N, j=1:N])

    rg2Df = Texture([Vec2(0) for i=1:N, j=1:N])
    rg2Di = Texture([iVec2(0) for i=1:N, j=1:N])
    rg2Dui = Texture([uVec2(0f0) for i=1:N, j=1:N])

    rgb2Df = Texture([Vec3(0) for i=1:N, j=1:N])
    rgb2Di = Texture([iVec3(0) for i=1:N, j=1:N])
    rgb2Dui = Texture([uVec3(0f0) for i=1:N, j=1:N])

    rgba2Df = Texture([Vec4(0) for i=1:N, j=1:N])
    rgba2Di = Texture([iVec4(0) for i=1:N, j=1:N])
    rgba2Dui = Texture([uVec4(0f0) for i=1:N, j=1:N])


    z = Vec4[Vec4(0f0) for j=1:N, i=1:N]
    arraytexture = Texture(z)

    @test toglsltype_string(rg2Df) == "uniform sampler2D"
    @test toglsltype_string(rgb2Df) == "uniform sampler2D"
    @test toglsltype_string(rgba2Df) == "uniform sampler2D"

    @test ndims(rgba2Df) == 2
    @test eltype(rgba2Df) == Vec4
end

test_textures()
