using GLAbstraction, GLWindow, GeometryTypes, ColorTypes, GLFW, Reactive, ModernGL
const vert = vert"""
{{GLSL_VERSION}}
in vec2 pos;

out vec4 v_color;
uniform mat4 projectionview;
void main() {
    gl_Position = projectionview*vec4(pos, 0.0, 1.0);
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


void main(void)
{
  // get the four vertices passed to the shader:
  vec4 p0 = gl_in[0].gl_Position;   // start of previous segment

  gl_Position = gl_in[0].gl_Position + vec4(-0.01, -0.01, 0, 0);
  EmitVertex();

  gl_Position = gl_in[0].gl_Position + vec4(-0.01, 0.01, 0, 0);
  EmitVertex();

  gl_Position = gl_in[0].gl_Position + vec4(0.01, -0.01, 0, 0);
  EmitVertex();

  gl_Position = gl_in[0].gl_Position + vec4(0.1, 0.01, 0, 0);
  EmitVertex();



  EndPrimitive();
}
"""
GLFW.Init()
const window = createwindow("Geometry Shader", 512, 512)

cam = PerspectiveCamera(window.inputs, Vec3f0(1), Vec3f0(0))

const b = Point2f0[Point2f0(i/30, rand()) for i=1:64]

data = Dict{Symbol, Any}(
    :pos => GLBuffer(b),
    :projectionview => cam.projectionview
)
program = TemplateProgram(vert, geom, frag)
robj = std_renderobject(data, Input(program), Input(AABB(Vec3f0(0), Vec3f0(1))), GL_POINTS)


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
