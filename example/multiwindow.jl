using GLFW, ModernGL, GLAbstraction, GeometryTypes
# Note: This was written as a quick test for multiwindow support.
# It is not a clean example (yet) of the proper way to do it.

windows = []
robjs = []
vsh = vert"""
{{GLSL_VERSION}}
in vec2 position;
void main(){
    gl_Position = vec4(position, 0, 1.0);
}
"""

fsh = frag"""
{{GLSL_VERSION}}
out vec4 outColor;
void main() {
    outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
"""


robjs = []
for i in 1:3
    name = "Window $i"
    window = if isempty(windows)
        window = GLFW.CreateWindow(640, 480, name)
        GLFW.MakeContextCurrent(window)
        GLAbstraction.new_context()
        robj = std_renderobject(
            Dict{Symbol, Any}(
                :position => GLBuffer(Point2f0[(0.0, 0.5), (0.5, -0.5), (-0.5,-0.5)]),
            ),
            LazyShader(vsh, fsh)
        )
        push!(robjs, robj)
        window
    else
        window = GLFW.CreateWindow(640, 480, name, GLFW.Monitor(C_NULL), first(windows))
        GLFW.MakeContextCurrent(window)
        push!(robjs, rewrap(first(robjs)))
        window
    end


    GLFW.SetMouseButtonCallback(window, (_, button, action, mods) -> begin
        if action == GLFW.PRESS
            println(name)
        end
    end)

    push!(windows, window)
end
GLAbstraction.current_context()
gc() # Force garbage collection so that improper reference management is more apparent via crashes
while !any(GLFW.WindowShouldClose, windows)
    GLFW.PollEvents()
    for (i, window) in enumerate(windows)
        GLFW.MakeContextCurrent(window)
        glViewport(0, 0, 640, 480)
        glClearColor(0, (i-3) / 3, i / 3, 1)
        ModernGL.glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        render(robjs[i])
        GLFW.SwapBuffers(window)
    end
    GLFW.WaitEvents()
end

for window in windows
    GLFW.DestroyWindow(window)
end
