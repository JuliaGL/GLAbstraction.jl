import GLFW
using ModernGL, GeometryTypes, GLAbstraction, Images, FileIO, Reactive

# Load our textures. See "downloads.jl" to get the images.
kitten = load("images/kitten.png")
puppy  = load("images/puppy.png")

# Create the window
window = GLFW.CreateWindow(800, 800, "Transformations 2")
GLFW.MakeContextCurrent(window)
GLFW.SetInputMode(window, GLFW.STICKY_KEYS, GL_TRUE)

vao = glGenVertexArrays()
glBindVertexArray(vao)

# The positions of the vertices in our rectangle
vertex_positions = Point{2,Float32}[(-0.5,  0.5),     # top-left
                                    ( 0.5,  0.5),     # top-right
                                    ( 0.5, -0.5),     # bottom-right
                                    (-0.5, -0.5)]     # bottom-left

# The texture coordinates of each vertex
vertex_texcoords = Vec2f0[(0, 0),
                          (1, 0),
                          (1, 1),
                          (0, 1)]

# Specify how vertices are arranged into faces
elements = Face{3,UInt32,-1}[(0,1,2),          # the first triangle
                             (2,3,0)]          # the second triangle

vertex_shader = vert"""
#version 150

in vec2 position;
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
    gl_Position = proj * view * model * vec4(position, 0.0, 1.0);
}
"""
fragment_shader = load("shaders/puppykitten.frag")

# Define the transformation
model = Signal(rotate(0f0, Vec((0,0,1f0))))
view = lookat(Vec3((1.2f0, 1.2f0, 1.2f0)), Vec3((0f0, 0f0, 0f0)), Vec3((0f0, 0f0, 1f0)))
proj = perspectiveprojection(Float32, 45, 800/600, 1, 10)

# Link everything together, using the corresponding shader variable as
# the Dict key
bufferdict = Dict(:position=>GLBuffer(vertex_positions),
                  :texcoord=>GLBuffer(vertex_texcoords),
                  :texKitten=>Texture(data(kitten)),
                  :texPuppy=>Texture(data(puppy)),
                  :model=>model,
                  :view=>view,
                  :proj=>proj,
                  :indexes=>indexbuffer(elements)) # special for element buffers

ro = std_renderobject(bufferdict,
                      LazyShader(vertex_shader, fragment_shader))

# Do the rendering
glClearColor(0,0,0,1)
while !GLFW.WindowShouldClose(window)
    push!(model, scalematrix((0.75+0.25*sin(5*time()))*Vec3((1,1,1))) * rotationmatrix_z(time()*deg2rad(180)))
    Reactive.run_till_now()
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    render(ro)
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
    if GLFW.GetKey(window, GLFW.KEY_ESCAPE) == GLFW.PRESS
        GLFW.SetWindowShouldClose(window, true)
    end
end

GLFW.DestroyWindow(window)  # needed if you're running this from the REPL
