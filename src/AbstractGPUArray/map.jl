Base.map{T}(s::Shader, A::Array{T}, B::Array{T}; kw_args...) = map(s, vec(A), vec(B); kw_args...)
Base.map{T}(s::Shader, A::Vector{T}, B::Vector{T}; kw_args...) = map(s, GLBuffer(A, usage=GL_STATIC_DRAW), GLBuffer(B, usage=GL_STATIC_DRAW); kw_args...)
function Base.map{T}(s::Shader, A::GLBuffer{T}, B::GLBuffer{T}; kw_args...)
    length(A) != length(B) && throw(DimensionMismacht("Arrays need to be of same length for map: $(length(A)) != $(length(B))"))
    outbuffer = GLBuffer(zeros(T, length(A)), usage=GL_STATIC_READ)
    data      = merge(Dict{Symbol, Any}(
        :arg1 => A,
        :arg2 => B,
        :out1 => outbuffer,
    ), Dict{Symbol, Any}(kw_args))
    prg = TemplateProgram(
        load(joinpath(dirname(@__FILE__), "map.vert")),
        transformfeedbacklocations=[(:out1, GL_INTERLEAVED_ATTRIBS)],
        attributes=data,
        view=Dict(
            "KERNEL" => bytestring(s.source),
            "out1_type" => string("out ", toglsltype_string(outbuffer)[3:end])# terrible workaround for not having a way to differentiate between in and out (toglsltype_string returns "in ...")
        )
    )
    ro = RenderObject(data, prg)
    postrender!(ro,
        glEnable, GL_RASTERIZER_DISCARD,
        glBindVertexArray, ro.vertexarray.id,
        glBindBufferBase, GL_TRANSFORM_FEEDBACK_BUFFER, 0, outbuffer.id,
        glBeginTransformFeedback, GL_POINTS,
        glDrawArrays, GL_POINTS, 0, length(outbuffer),
        glEndTransformFeedback,
        glFlush
    )
    ro, outbuffer
end
function Base.map(s::Shader, A::Signal, B::Signal; kw_args...)
    gla, glb =  GLBuffer(vec(value(A)), usage=GL_STATIC_DRAW), GLBuffer(vec(value(B)), usage=GL_STATIC_DRAW)
    ro, outbuff = map(s, gla, glb)
    preserve(const_lift(A,B) do a,b
        update!(gla, vec(a))
        update!(glb, vec(b))
        render(ro)
    end)
    outbuff
end
