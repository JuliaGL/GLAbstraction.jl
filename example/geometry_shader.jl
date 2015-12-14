using GLAbstraction, GLWindow, GeometryTypes, ColorTypes, GLFW, Reactive, ModernGL
const vert = vert"""
{{GLSL_VERSION}}
in vec2 pos;

out vec4 v_color;
out vec3 g_position;

uniform mat4 projectionview;
void main() {
    g_position = vec3(pos, 0.0);
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

layout(lines_adjacency) in;
layout(points, max_vertices = 4) out;
uniform mat4 projectionview;
in vec3 g_position[];

void main(void)
{
  // get the four vertices passed to the shader:
  vec3 p0 = g_position[0];   // start of previous segment

  gl_Position = projectionview*vec4(g_position[0], 1);
  EmitVertex();

  gl_Position = projectionview*vec4(g_position[1], 1);
  EmitVertex();

  gl_Position = projectionview*vec4(g_position[2], 1);
  EmitVertex();

  gl_Position = projectionview*vec4(g_position[3], 1);
  EmitVertex();


  EndPrimitive();
}
"""
GLFW.Init()
const window = createwindow("Geometry Shader", 512, 512)

cam = PerspectiveCamera(window.inputs, Vec3f0(1), Vec3f0(0))

const b = Point2f0[(0,0),(0.0, 0.3)]

data = Dict{Symbol, Any}(
    :pos => GLBuffer(b),
    :indexbuffer => indexbuffer(GLint[0,0,1,1]),
    :projectionview => cam.projectionview
)
program = GLAbstraction.LazyShader(vert, geom, frag)
robj = std_renderobject(data, program, Signal(AABB(Vec3f0(0), Vec3f0(1))), GL_LINE_STRIP_ADJACENCY)


glClearColor(0,0,0,1)
while !GLFW.WindowShouldClose(window.nativewindow)
    yield()
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    render(robj)
    GLFW.SwapBuffers(window.nativewindow)
    GLFW.PollEvents()
    sleep(0.01)
end
GLFW.Terminate()
