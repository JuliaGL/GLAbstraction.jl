# In addition to illustrating transformations, we'll start loading some
# shaders from a file.  We'll also demo using Reactive for animations.
using ModernGL, GeometryTypes, GLAbstraction, GLWindow, Images, FileIO, Reactive

# Load our textures. See "downloads.jl" to get the images.
kitten = load(GLAbstraction.dir("tutorials", "images", "kitten.png"))
puppy  = load(GLAbstraction.dir("tutorials", "images", "puppy.png"))

# Create the window. This sets all the hints and makes the context current.
window = create_glcontext("Transformations 1", resolution=(600,600))

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

uniform mat4 trans;

void main()
{
    Color = color;
    Texcoord = texcoord;
    gl_Position = trans*vec4(position, 0.0, 1.0);
}
"""
fragment_shader = load(joinpath(dirname(@__FILE__), "shaders", "puppykitten.frag"))

# Define the rotation matrix (could also use rotationmatrix_z)
# By wrapping it in a Signal, we can easily update it.
trans = Signal(rotate(0f0, Vec((0,0,1f0))))

# Link everything together, using the corresponding shader variable as
# the Dict key
bufferdict = Dict(:position=>Buffer(vertex_positions),
                  :texcoord=>Buffer(vertex_texcoords),
                  :texKitten=>Texture(kitten'),
                  :texPuppy=>Texture(puppy'),
                  :trans=>trans,
                  :indexes=>indexbuffer(elements)) # special for element buffers

ro = std_renderobject(bufferdict,
                      LazyShader(vertex_shader, fragment_shader))
# Do the rendering
glClearColor(0,0,0,1)
while !GLFW.WindowShouldClose(window)
    push!(trans, rotationmatrix_z(time()*deg2rad(180)))
    Reactive.run_till_now()
    glClear(GL_COLOR_BUFFER_BIT)
    GLAbstraction.render(ro)
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
    if GLFW.GetKey(window, GLFW.KEY_ESCAPE) == GLFW.PRESS
        GLFW.SetWindowShouldClose(window, true)
    end
end

GLFW.DestroyWindow(window)  # needed if you're running this from the REPL
