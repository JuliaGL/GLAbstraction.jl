@show vec4
@show a = vec4(0)
@show b = vec2(2)
@show c = vec4(b..., 1,2)
@show d = ivec4(b..., 1,2)
@show d = uivec4(b..., 1,2)


@show m  = Matrix4x3(9f0)
@show m2 = mat3(9f0)
@show m2 = mat3(vec3(0), vec3(0), vec3(9))


@show glUniform(int32(1), a)
@show glUniform(int32(1), vec4[a,a])

@show glUniform(int32(1), m)
@show glUniform(int32(1), mat4x3[m, m])