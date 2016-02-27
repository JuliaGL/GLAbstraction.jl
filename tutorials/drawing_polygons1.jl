import GLFW
using ModernGL, GeometryTypes
# We're going to use only one feature of GLAbstraction---a slightly
# more "julian" version of glShaderSource. There are many other places
# where it offers simplifications, but in this tutorial we're being
# deliberately low-level.
using GLAbstraction

# Create the window
window = GLFW.CreateWindow(800, 600, "Drawing polygons 1")
GLFW.MakeContextCurrent(window)
# Retain keypress events
GLFW.SetInputMode(window, GLFW.STICKY_KEYS, GL_TRUE)

# Create the Vertex Array Object (VAO) and make it current
# Note that while the tutorial describes this after the attributes (below),
# we need to make vao current before calling glVertexAttribPointer.
# You should also do this before creating any element arrays (see
# drawing_polygons4.jl)
vao = Ref(GLuint(0))
glGenVertexArrays(1, vao)
glBindVertexArray(vao[])

# The vertices of our triangle
vertices = Point2f0[(0, 0.5), (0.5, -0.5), (-0.5, -0.5)] # note Float32

# Create the Vertex Buffer Object (VBO)
vbo = Ref(GLuint(0))   # initial value is irrelevant, just allocate space
glGenBuffers(1, vbo)
glBindBuffer(GL_ARRAY_BUFFER, vbo[])
glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

# The shaders. Here we do everything manually, but life will get
# easier with GLAbstraction. See drawing_polygons5.jl for such an
# implementation.

# The vertex shader
vertex_source = """
#version 150

in vec2 position;

void main()
{
    gl_Position = vec4(position, 0.0, 1.0);
}
"""

# The fragment shader
fragment_source = """
# version 150

out vec4 outColor;

void main()
{
    outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
"""

# Compile the vertex shader
vertex_shader = glCreateShader(GL_VERTEX_SHADER)
glShaderSource(vertex_shader, vertex_source)  # nicer thanks to GLAbstraction
glCompileShader(vertex_shader)
# Check that it compiled correctly
status = Ref(GLint(0))
glGetShaderiv(vertex_shader, GL_COMPILE_STATUS, status)
if status[] != GL_TRUE
    buffer = Array(UInt8, 512)
    glGetShaderInfoLog(vertex_shader, 512, C_NULL, buffer)
    error(bytestring(buffer))
end

# Compile the fragment shader
fragment_shader = glCreateShader(GL_FRAGMENT_SHADER)
glShaderSource(fragment_shader, fragment_source)
glCompileShader(fragment_shader)
# Check that it compiled correctly
status = Ref(GLint(0))
glGetShaderiv(fragment_shader, GL_COMPILE_STATUS, status)
if status[] != GL_TRUE
    buffer = Array(UInt8, 512)
    glGetShaderInfoLog(fragment_shader, 512, C_NULL, buffer)
    error(bytestring(buffer))
end

# Connect the shaders by combining them into a program
shader_program = glCreateProgram()
glAttachShader(shader_program, vertex_shader)
glAttachShader(shader_program, fragment_shader)
glBindFragDataLocation(shader_program, 0, "outColor") # optional

glLinkProgram(shader_program)
glUseProgram(shader_program)

# Link vertex data to attributes
pos_attribute = glGetAttribLocation(shader_program, "position")
glVertexAttribPointer(pos_attribute, length(eltype(vertices)),
                      GL_FLOAT, GL_FALSE, 0, C_NULL)
glEnableVertexAttribArray(pos_attribute)

# Draw while waiting for a close event
while !GLFW.WindowShouldClose(window)
    glDrawArrays(GL_TRIANGLES, 0, length(vertices))
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
    if GLFW.GetKey(window, GLFW.KEY_ESCAPE) == GLFW.PRESS
        GLFW.SetWindowShouldClose(window, true)
    end
end

GLFW.DestroyWindow(window)  # needed if you're running this from the REPL
