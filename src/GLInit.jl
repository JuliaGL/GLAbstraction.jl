function initUtils()
	flatShader              = GLProgram(rootFolder*"shader/flatShader")
	RECTANGLE_VERT_ARRAY    = GLVertexArray(["position" => createQuad(0f0, 0f0, 1f0, 1f0), "uv" => createQuadUV()], flatShader, primitiveMode = GL_TRIANGLES)
end