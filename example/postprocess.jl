function fullscreenquad(unused...)
    uv = (0f0, 1f0)
    if (Transpiler.gli.gl_VertexID & 1) != 0
        uv = (1f0, 0f0)
    end
    frag_uv = uv .* 2f0
    pos2d = uv .* 4f0
    pos2d = pos2d .- 1f0
    position = (pos2d[1], pos2d[2], 0f0, 1f0)
    position, frag_uv
end
using Transpiler, GeometryTypes
s, m, n = Transpiler.kernel_source(fullscreenquad, ())
println(s)
source, ret = Transpiler.emit_vertex_shader(fullscreenquad, ())
write(STDOUT, source)
Transpiler.isintrinsic(Transpiler.GLMethod((+, (NTuple{2, Float32}, NTuple{2, Float32}))))
