using ModernGL, GeometryTypes, GLAbstraction, GLWindow, Images, FileIO

# Load our textures. See "downloads.jl" to get the images.
kitten = load(Pkg.dir("GLAbstraction", "tutorials", "images", "kitten.png"))
puppy  = load(Pkg.dir("GLAbstraction", "tutorials", "images", "puppy.png"))

windowhints = [
    (GLFW.SAMPLES,      4),
    (GLFW.DEPTH_BITS,   32),

    (GLFW.ALPHA_BITS,   8),
    (GLFW.RED_BITS,     8),
    (GLFW.GREEN_BITS,   8),
    (GLFW.BLUE_BITS,    8),

    (GLFW.STENCIL_BITS, 8),
    (GLFW.AUX_BUFFERS,  0)
]


# Create the window. This sets all the hints and makes the context current.
window = create_glcontext("Depth and stencils 2", resolution=(600,600), windowhints=windowhints)

vao = glGenVertexArrays()
glBindVertexArray(vao)

# The cube. This could be more efficiently represented using indexes,
# but the tutorial doesn't do it that way.
vertex_positions = Vec3f0[
    # The cube
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
    (-0.5f0,  0.5f0, -0.5f0)]

floor_positions = Vec3f0[
    # The floor
    (-1.0f0, -1.0f0, -0.5f0),
    ( 1.0f0, -1.0f0, -0.5f0),
    ( 1.0f0,  1.0f0, -0.5f0),
    ( 1.0f0,  1.0f0, -0.5f0),
    (-1.0f0,  1.0f0, -0.5f0),
    (-1.0f0, -1.0f0, -0.5f0)
]

vertex_texcoords = Vec2f0[
                          # The cube
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

floor_texcoords = Vec2f0[
                          # The floor
                          (0.0f0, 0.0f0),
                          (1.0f0, 0.0f0),
                          (1.0f0, 1.0f0),
                          (1.0f0, 1.0f0),
                          (0.0f0, 1.0f0),
                          (0.0f0, 0.0f0)]

vertex_colors = fill(Vec3f0(1,1,1), 36)
floor_colors = fill(Vec3f0(0,0,0),6)

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

model1 = eye(Mat{4,4,Float32})
view = lookat(Vec3((1.2f0, 1.2f0, 1.2f0)), Vec3((0f0, 0f0, 0f0)), Vec3((0f0, 0f0, 1f0)))
proj = perspectiveprojection(Float32, 60, 600/600, 1, 10)

# Link everything together, using the corresponding shader variable as
# the Dict key
bufferdict_cube = Dict(:position=>GLBuffer(vertex_positions),
                       :texcoord=>GLBuffer(vertex_texcoords),
                       :color=>GLBuffer(vertex_colors),
                       :texKitten=>Texture(data(kitten)),
                       :texPuppy=>Texture(data(puppy)),
                       :model=>model1,
                       :view=>view,
                       :proj=>proj)

ro_cube = std_renderobject(bufferdict_cube,
                           LazyShader(vertex_shader, fragment_shader))

bufferdict_floor = Dict(:position=>GLBuffer(floor_positions),
                        :texcoord=>GLBuffer(floor_texcoords),
                        :color=>GLBuffer(floor_colors),
                        :texKitten=>Texture(data(kitten)), # with different shaders, wouldn't need these here
                        :texPuppy=>Texture(data(puppy)),
                        :model=>model1,
                        :view=>view,
                        :proj=>proj)

ro_floor = std_renderobject(bufferdict_floor,
                            LazyShader(vertex_shader, fragment_shader))


# Do the rendering: note that GLAbstraction automatically sets GL_DEPTH_TEST
glClearColor(0,0,0,1)
while !GLFW.WindowShouldClose(window)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    render([ro_cube, ro_floor])
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
    if GLFW.GetKey(window, GLFW.KEY_ESCAPE) == GLFW.PRESS
        GLFW.SetWindowShouldClose(window, true)
    end
end

GLFW.DestroyWindow(window)  # needed if you're running this from the REPL
