## For this tutorial, we start making use of GLAbstraction and GLWindow
import GLFW
using ModernGL, GeometryTypes, GLAbstraction, GLWindow

# Create the window. create_glcontext is essentially a wrapper for
# GLFW.CreateWindow, GLFW.MakeContextCurrent, and GLFW.ShowWindow, but
# you can supply hints as well.
window = create_glcontext("Tutorial 02b",
                          resolution=(1024,768),
                          windowhints=[(GLFW.SAMPLES, 4)]) # use 4x antialiasing

# Dark blue background
glClearColor(0.0f0, 0.0f0, 0.4f0, 0.0f0);

# Retain keypress events
GLFW.SetInputMode(window, GLFW.STICKY_KEYS, GL_TRUE)

# Define the vertices of the triangle
vertices = Point3f0[(-1,-1,0), (1,-1,0), (0, 1, 1)]

# Define the shaders. Note that we don't specify the location (that
# will be handled by the Dict below)
vertexshader = vert"""
#version 330 core

in vec3 vertexPosition_modelspace;

void main(){
  gl_Position.xyz = vertexPosition_modelspace;
  gl_Position.w = 1.0;
}
"""

fragmentshader = frag"""
#version 330 core
out vec3 color;
void main(){
  color = vec3(1,0,0);
}
"""

# Assemble the shaders into a program
prog = TemplateProgram(vertexshader, fragmentshader)

# Create the Vertex Array Object, linking it to our shader variables
bufferdict = Dict(:vertexPosition_modelspace=>GLBuffer(vertices))
vao = GLVertexArray(bufferdict, prog)

# Bind the VAO and program
glUseProgram(prog.id)
glBindVertexArray(vao.id)

# Draw until we receive a close event
while GLFW.GetKey(window, GLFW.KEY_ESCAPE) != GLFW.PRESS && isopen(window)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    render(vao, GL_TRIANGLES)
    
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
end

# Clean up
glBindVertexArray(0)
GLAbstraction.empty_shader_cache!()

GLFW.DestroyWindow(window)  # needed if you're running this from the REPL
