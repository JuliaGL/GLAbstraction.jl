using ModernGL, GeometryTypes, GLAbstraction, GLWindow, Images, FileIO
import GLAbstraction: StandardPostrender
# Load our textures. See "downloads.jl" to get the images.
kitten = load(GLAbstraction.dir("tutorials", "images", "kitten.png"))
puppy  = load(GLAbstraction.dir("tutorials", "images", "puppy.png"))

windowhints = [(GLFW.DEPTH_BITS, 32), (GLFW.STENCIL_BITS, 8)]
window = create_glcontext("Depth and stencils 2",
                          resolution=(600,600),
                          windowhints=windowhints)

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

uniform vec3 overrideColor;
uniform mat4 model;
uniform mat4 view;
uniform mat4 proj;

void main()
{
    Color = overrideColor * color;
    Texcoord = texcoord;
    gl_Position = proj * view * model * vec4(position, 1.0);
}
"""
fragment_shader = load(joinpath(dirname(@__FILE__), "shaders", "puppykitten_color.frag"))

model1 = eye(Mat{4,4,Float32})
model2 = translationmatrix_z(-1f0) * scalematrix(Vec3f0(1,1,-1))
view = lookat(Vec3f0((2.5, 2.5, 2)), Vec3f0((0, 0, 0)), Vec3f0((0, 0, 1)))
proj = perspectiveprojection(Float32, 45, 600/600, 1, 10)


## Now render the distinct objects. Rather than always using std_renderobject,
## here we control the settings manually.
# The cube
bufferdict_cube = Dict(:position=>Buffer(vertex_positions),
                       :texcoord=>Buffer(vertex_texcoords),
                       :color=>Buffer(vertex_colors),
                       :texKitten=>Texture(data(kitten)),
                       :texPuppy=>Texture(data(puppy)),
                       :overrideColor=>Vec3f0((1,1,1)),
                       :model=>model1,
                       :view=>view,
                       :proj=>proj)

pre = () -> glDisable(GL_STENCIL_TEST)
ro_cube = RenderObject(
    bufferdict_cube,
    LazyShader(vertex_shader, fragment_shader),
     pre, nothing, AABB(Vec3f0(0), Vec3f0(1)), nothing
)
ro_cube.postrenderfunction = StandardPostrender(ro_cube.vertexarray, GL_TRIANGLES)

# The floor. This is drawn without writing to the depth buffer, but we
# write stencil values.
bufferdict_floor = Dict(:position=>Buffer(floor_positions),
                        :texcoord=>Buffer(floor_texcoords),
                        :color=>Buffer(floor_colors),
                        :texKitten=>Texture(data(kitten)), # with different shaders, wouldn't need these here
                        :texPuppy=>Texture(data(puppy)),
                        :overrideColor=>Vec3f0((1,1,1)),
                        :model=>model1,
                        :view=>view,
                        :proj=>proj)

function prerender()
    glDepthMask(GL_FALSE)                  # don't write to depth buffer
    glEnable(GL_STENCIL_TEST)              # use stencils
    glStencilMask(0xff)                    # do write to stencil buffer
    glStencilFunc(GL_ALWAYS, 1, 0xff)      # all pass
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)  # replace stencil value
    glClear(GL_STENCIL_BUFFER_BIT)         # start with empty buffer
end
ro_floor = RenderObject(
    bufferdict_floor,
    LazyShader(vertex_shader, fragment_shader),
    prerender, nothing, AABB(Vec3f0(0), Vec3f0(1)), nothing
)
ro_floor.postrenderfunction = StandardPostrender(ro_floor.vertexarray, GL_TRIANGLES)

# The cube reflection
bufferdict_refl = Dict(:position=>Buffer(vertex_positions),
                       :texcoord=>Buffer(vertex_texcoords),
                       :color=>Buffer(vertex_colors),
                       :texKitten=>Texture(data(kitten)),
                       :texPuppy=>Texture(data(puppy)),
                       :overrideColor=>Vec3f0((0.3,0.3,0.3)),
                       :model=>model2,
                       :view=>view,
                       :proj=>proj)

pre = () -> begin
    glStencilFunc(GL_EQUAL, 1, 0xff)
    glStencilMask(0x00)
end

ro_refl = RenderObject(
   bufferdict_refl,
   LazyShader(vertex_shader, fragment_shader),
   pre, nothing, AABB(Vec3f0(0), Vec3f0(1)), nothing
)
ro_refl.postrenderfunction = StandardPostrender(ro_refl.vertexarray, GL_TRIANGLES)


glClearColor(1,1,1,1) # make the background white, so we can see the floor
glClearStencil(0)     # clear the stencil buffer with 0

while !GLFW.WindowShouldClose(window)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    GLAbstraction.render(ro_cube)
    GLAbstraction.render(ro_floor)
    GLAbstraction.render(ro_refl)

    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
    if GLFW.GetKey(window, GLFW.KEY_ESCAPE) == GLFW.PRESS
        GLFW.SetWindowShouldClose(window, true)
    end
end
GLFW.DestroyWindow(window)  # needed if you're running this from the REPL
