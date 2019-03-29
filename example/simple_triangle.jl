using ModernGL, GLWindow, GLAbstraction, GLFW, GeometryTypes

const window = GLWindow.create_glcontext("Example", resolution=(512, 512), debugging=true)


const vsh = vert"""
{{GLSL_VERSION}}
in vec2 position;

void main(){
    gl_Position = vec4(position, 0, 1.0);
}
"""

const fsh = frag"""
{{GLSL_VERSION}}
out vec4 outColor;

void main() {
    outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
"""

const triangle = std_renderobject(
    Dict{Symbol, Any}(
        :position => Buffer(Point2f0[(0.0, 0.5), (0.5, -0.5), (-0.5,-0.5)]),
    ),
    LazyShader(vsh, fsh)
)

glClearColor(0, 0, 0, 1)

while isopen(window)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    render(triangle)
    swapbuffers(window)
    poll_glfw()
end
GLFW.DestroyWindow(window)
