# Here, we illustrate a more "julian" implementation that leverages
# some of the advantages of GLAbstraction
import GLFW
using ModernGL, GeometryTypes, GLAbstraction

# Create the window
window = GLFW.CreateWindow(800, 600, "Drawing polygons 5")
GLFW.MakeContextCurrent(window)
# Retain keypress events
GLFW.SetInputMode(window, GLFW.STICKY_KEYS, GL_TRUE)

# A slightly-simplified VAO generator call
vao = glGenVertexArrays()
glBindVertexArray(vao)

# The positions of the vertices in our rectangle
vertex_positions = Point{2,Float32}[(-0.5, -0.5),     # bottom-left
                                    ( 0.5, -0.5),     # bottom-right
                                    ( 0.0,  0.5)]     # top-center

# The grayscale value assigned to each vertex
vertex_gray = Float32[0.2,                     # bottom-left
                      0.9,                     # bottom-right
                      0.5]                     # top-center

# The vertex shader---note the `vert` in front of """
vertex_shader = vert"""
#version 150

in vec2 position;
in float gray;

out float Gray;

void main()
{
    Gray = gray;
    gl_Position = vec4(position, 0.0, 1.0);
}
"""

# The fragment shader
fragment_shader = frag"""
# version 150

in float Gray;

out vec4 outColor;

void main()
{
    outColor = vec4(Gray, Gray, Gray, 1.0);
}
"""

# Link everything together, using the corresponding shader variable as
# the Dict key
bufferdict = Dict(:position=>GLBuffer(vertex_positions),
                  :gray=>GLBuffer(vertex_gray))

ro = std_renderobject(bufferdict,
                      LazyShader(vertex_shader, fragment_shader))

# Draw until we receive a close event
while !GLFW.WindowShouldClose(window)
    render(ro)
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
    if GLFW.GetKey(window, GLFW.KEY_ESCAPE) == GLFW.PRESS
        GLFW.SetWindowShouldClose(window, true)
    end
end

GLFW.DestroyWindow(window)  # needed if you're running this from the REPL
