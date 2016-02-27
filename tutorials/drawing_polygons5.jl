# Here, we illustrate a more "julian" implementation that leverages
# some of the advantages of GLAbstraction
# Note: if you re-run this in the same session, call
#    GLAbstraction.empty_shader_cache!()
# first
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
vertex_positions = Point{2,Float32}[(-0.5,  0.5),     # top-left
                                    ( 0.5,  0.5),     # top-right
                                    ( 0.5, -0.5),     # bottom-right
                                    (-0.5, -0.5)]     # bottom-left

# The colors assigned to each vertex
vertex_colors = Vec3f0[(1, 0, 0),                     # top-left
                       (0, 1, 0),                     # top-right
                       (0, 0, 1),                     # bottom-right
                       (1, 1, 1)]                     # bottom-left

# Specify how vertices are arranged into faces
# Face{N,T,O} type specifies a face with N vertices, with index type
# T (you should choose UInt32), and index-offset O. If you're
# specifying faces in terms of julia's 1-based indexing, you should set
# O=0. (If you instead number the vertices starting with 0, set
# O=-1.)
elements = Face{3,UInt32,-1}[(0,1,2),          # the first triangle
                             (2,3,0)]          # the second triangle

# The vertex shader---note the `vert` in front of """
vertex_shader = vert"""
#version 150

in vec2 position;
in vec3 color;

out vec3 Color;

void main()
{
    Color = color;
    gl_Position = vec4(position, 0.0, 1.0);
}
"""

# The fragment shader
fragment_shader = frag"""
# version 150

in vec3 Color;

out vec4 outColor;

void main()
{
    outColor = vec4(Color, 1.0);
}
"""

# Link everything together, using the corresponding shader variable as
# the Dict key
bufferdict = Dict(:position=>GLBuffer(vertex_positions),
                  :color=>GLBuffer(vertex_colors),
                  :indexes=>indexbuffer(elements)) # special for element buffers

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
