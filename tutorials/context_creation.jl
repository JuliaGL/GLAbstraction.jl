import GLFW
using ModernGL

# Create the window
window = GLFW.CreateWindow(1024, 768, "Tutorial 01")
GLFW.MakeContextCurrent(window)

# Retain keypress events until the next call to GLFW.GetKey, even if
# the key has been released in the meantime
GLFW.SetInputMode(window, GLFW.STICKY_KEYS, GL_TRUE)

# Draw nothing, while waiting for a close event
while GLFW.GetKey(window, GLFW.KEY_ESCAPE) != GLFW.PRESS && !GLFW.WindowShouldClose(window)
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
end

GLFW.DestroyWindow(window)  # needed if you're running this from the REPL
