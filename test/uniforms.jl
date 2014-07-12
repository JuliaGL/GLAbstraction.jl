a = vec4(0)
b = vec2(2)
c = vec4(b..., 1,2)
d = ivec4(b..., 1,2)
d = uivec4(b..., 1,2)


m  = Matrix4x3(9f0)
m2 = mat3(9f0)
m2 = mat3(vec3(0), vec3(0), vec3(9))


gluniform(int32(1), a)
gluniform(int32(1), vec4[a,a])
gluniform(int32(1), m)
gluniform(int32(1), mat4x3[m, m])