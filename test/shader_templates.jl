using GLAbstraction, GLWindow
createwindow("asd", 20,20)
view = Dict("GLSL_VERSION"    => "glsl_version_string()")

source = "
{{GLSL_VERSION}}
{{color_type}} color;
{{tex_type}} tex;
"
attribs = Dict{Symbol, Any}(:color => Vec3(0), :tex=>Texture(rand(Float32, 5,5)))
println(GLAbstraction.template2source(source, attribs, view))