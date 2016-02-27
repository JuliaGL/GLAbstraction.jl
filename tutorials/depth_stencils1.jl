import GLFW
using ModernGL, GeometryTypes, GLAbstraction, Images, FileIO

# Load our textures. See "downloads.jl" to get the images.
kitten = load("images/kitten.png")
puppy  = load("images/puppy.png")

# Create the window
window = GLFW.CreateWindow(800, 800, "Depth and stencils 1")
GLFW.MakeContextCurrent(window)
GLFW.SetInputMode(window, GLFW.STICKY_KEYS, GL_TRUE)

vao = glGenVertexArrays()
glBindVertexArray(vao)

# The cube. This could be more efficiently represented using indexes,
# but the tutorial doesn't do it that way.
vertex_positions = Vec3f0[
    (-0.5f0, -0.5f0, -0.5f0),
    ( 0.5f0, -0.5f0, -0.5f0),
    ( 0.5f0,  0.5f0, -0.5f0),
    ( 0.5f0,  0.5f0, -0.5f0),
    (-0.5f0,  0.5f0, -0.5f0),
    (-0.5f0, -0.5f0, -0.5f0),

    (-0.5f0, -0.5f0,  0.5f0),
    ( 0.5f0, -0.5f0,  0.5f0),
    ( 0.5f0,  0.5f0,  0.5f0),
    ( 0.5f0,  0.5f0,  0.5f0),
    (-0.5f0,  0.5f0,  0.5f0),
    (-0.5f0, -0.5f0,  0.5f0),

    (-0.5f0,  0.5f0,  0.5f0),
    (-0.5f0,  0.5f0, -0.5f0),
    (-0.5f0, -0.5f0, -0.5f0),
    (-0.5f0, -0.5f0, -0.5f0),
    (-0.5f0, -0.5f0,  0.5f0),
    (-0.5f0,  0.5f0,  0.5f0),

    ( 0.5f0,  0.5f0,  0.5f0),
    ( 0.5f0,  0.5f0, -0.5f0),
    ( 0.5f0, -0.5f0, -0.5f0),
    ( 0.5f0, -0.5f0, -0.5f0),
    ( 0.5f0, -0.5f0,  0.5f0),
    ( 0.5f0,  0.5f0,  0.5f0),

    (-0.5f0, -0.5f0, -0.5f0),
    ( 0.5f0, -0.5f0, -0.5f0),
    ( 0.5f0, -0.5f0,  0.5f0),
    ( 0.5f0, -0.5f0,  0.5f0),
    (-0.5f0, -0.5f0,  0.5f0),
    (-0.5f0, -0.5f0, -0.5f0),

    (-0.5f0,  0.5f0, -0.5f0),
    ( 0.5f0,  0.5f0, -0.5f0),
    ( 0.5f0,  0.5f0,  0.5f0),
    ( 0.5f0,  0.5f0,  0.5f0),
    (-0.5f0,  0.5f0,  0.5f0),
    (-0.5f0,  0.5f0, -0.5f0),
]

vertex_texcoords = Vec2f0[
                          (0.0f0, 0.0f0),
                          (1.0f0, 0.0f0),
                          (1.0f0, 1.0f0),
                          (1.0f0, 1.0f0),
                          (0.0f0, 1.0f0),
                          (0.0f0, 0.0f0),

                          (0.0f0, 0.0f0),
                          (1.0f0, 0.0f0),
                          (1.0f0, 1.0f0),
                          (1.0f0, 1.0f0),
                          (0.0f0, 1.0f0),
                          (0.0f0, 0.0f0),

                          (1.0f0, 0.0f0),
                          (1.0f0, 1.0f0),
                          (0.0f0, 1.0f0),
                          (0.0f0, 1.0f0),
                          (0.0f0, 0.0f0),
                          (1.0f0, 0.0f0),

                          (1.0f0, 0.0f0),
                          (1.0f0, 1.0f0),
                          (0.0f0, 1.0f0),
                          (0.0f0, 1.0f0),
                          (0.0f0, 0.0f0),
                          (1.0f0, 0.0f0),

                          (0.0f0, 1.0f0),
                          (1.0f0, 1.0f0),
                          (1.0f0, 0.0f0),
                          (1.0f0, 0.0f0),
                          (0.0f0, 0.0f0),
                          (0.0f0, 1.0f0),

                          (0.0f0, 1.0f0),
                          (1.0f0, 1.0f0),
                          (1.0f0, 0.0f0),
                          (1.0f0, 0.0f0),
                          (0.0f0, 0.0f0),
                          (0.0f0, 1.0f0)]

vertex_colors = fill(Vec3f0(1,1,1), 36)

vertex_shader = vert"""
#version 150

in vec3 position;
in vec3 color;
in vec2 texcoord;

out vec3 Color;
out vec2 Texcoord;

uniform mat4 model;
uniform mat4 view;
uniform mat4 proj;

void main()
{
    Color = color;
    Texcoord = texcoord;
    gl_Position = proj * view * model * vec4(position, 1.0);
}
"""
fragment_shader = load("shaders/puppykitten_color.frag")

model = eye(Mat{4,4,Float32})
view = lookat(Vec3((1.2f0, 1.2f0, 1.2f0)), Vec3((0f0, 0f0, 0f0)), Vec3((0f0, 0f0, 1f0)))
proj = perspectiveprojection(Float32, 45, 800/600, 1, 10)

# Link everything together, using the corresponding shader variable as
# the Dict key
bufferdict = Dict(:position=>GLBuffer(vertex_positions),
                  :texcoord=>GLBuffer(vertex_texcoords),
                  :color=>GLBuffer(vertex_colors),
                  :texKitten=>Texture(data(kitten)),
                  :texPuppy=>Texture(data(puppy)),
                  :model=>model,
                  :view=>view,
                  :proj=>proj)

ro = std_renderobject(bufferdict,
                      LazyShader(vertex_shader, fragment_shader))

# Do the rendering: note that GLAbstraction automatically sets GL_DEPTH_TEST
glClearColor(0,0,0,1)
while !GLFW.WindowShouldClose(window)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    render(ro)
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
    if GLFW.GetKey(window, GLFW.KEY_ESCAPE) == GLFW.PRESS
        GLFW.SetWindowShouldClose(window, true)
    end
end

GLFW.DestroyWindow(window)  # needed if you're running this from the REPL
