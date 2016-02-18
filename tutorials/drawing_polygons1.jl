import GLFW
using ModernGL, GeometryTypes

# Create the window
window = GLFW.CreateWindow(1024, 768, "Tutorial 02")
GLFW.MakeContextCurrent(window)

# Retain keypress events
GLFW.SetInputMode(window, GLFW.STICKY_KEYS, GL_TRUE)

# Create the Vertex Array Object (VAO) and make it current
vertexarrayID = Ref(GLuint(0))
glGenVertexArrays(1, vertexarrayID)
glBindVertexArray(vertexarrayID[])

# Define the vertices of the triangle
vertices = Point3f0[(-1,-1,0), (1,-1,0), (0, 1, 1)]

# Create the Vertex Buffer Object (VBO)
vertexbuffer = Ref(GLuint(0))
glGenBuffers(1, vertexbuffer)
glBindBuffer(GL_ARRAY_BUFFER, vertexbuffer[])
glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

# Draw nothing, while waiting for a close event
while GLFW.GetKey(window, GLFW.KEY_ESCAPE) != GLFW.PRESS && !GLFW.WindowShouldClose(window)
    glEnableVertexAttribArray(0)
    glBindBuffer(GL_ARRAY_BUFFER, vertexbuffer[])
    glVertexAttribPointer(0, length(vertices), GL_FLOAT, GL_FALSE, 0, C_NULL)
    glDrawArrays(GL_TRIANGLES, 0, length(vertices))
    glDisableVertexAttribArray(0)
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
end

GLFW.DestroyWindow(window)  # needed if you're running this from the REPL
