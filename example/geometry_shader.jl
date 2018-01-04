using GLAbstraction, GLWindow, GeometryTypes, ColorTypes, GLFW, Reactive, ModernGL

const vert = vert"""
{{GLSL_VERSION}}
in vec2 pos;
out vec2 g_position;

void main() {
    g_position = pos;
}
"""

const frag = frag"""
{{GLSL_VERSION}}

out vec4 outColor;

void main() {
    outColor = vec4(1,0,0,1);
}
"""

const geom = geom"""

{{GLSL_VERSION}}

layout(points) in;
layout(triangle_strip, max_vertices = 4) out;
in vec2 g_position[];

void main(void)
{
  // get the four vertices passed to the shader:
  vec2 p0 = g_position[0];   // start of previous segment

  gl_Position = vec4(p0, 0, 1);
  EmitVertex();

  gl_Position = vec4(p0+vec2(0,0.1), 0, 1);
  EmitVertex();

  gl_Position = vec4(p0+vec2(0.1,0), 0, 1);
  EmitVertex();

  gl_Position = vec4(p0+vec2(0.1), 0, 1);
  EmitVertex();


  EndPrimitive();
}
"""

const window = GLWindow.create_glcontext("Geometry Shader")

const b = Point2f0[(-0.5,0),(0.0, 0.0),(0.4, 0.3)]

data = Dict{Symbol, Any}(
    :pos => Buffer(b),
)

program = GLAbstraction.LazyShader(vert, geom, frag)
robj = std_renderobject(data, program, Signal(AABB(Vec3f0(0), Vec3f0(1))), GL_POINTS)

glClearColor(0,0,0,1)
glClearColor(0, 0, 0, 1)


while isopen(window)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    render(robj)
    swapbuffers(window)
    poll_glfw()
end
GLFW.DestroyWindow(window)
