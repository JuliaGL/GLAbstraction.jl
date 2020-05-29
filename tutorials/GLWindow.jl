"""
GLWindow was/is a package by Simon Danisch et al that wrapped some functionality of
GLFW. I think it's obsoleted now? This little module reimplements only those parts
required to get the tutorials working again.

https://github.com/JuliaGL/GLWindow.jl

"""
module GLWindow

import GLFW

using ModernGL: GL_TRUE

export create_glcontext

# A more comprehensive setting of GLFW window hints. Setting all
# window hints reduces platform variance.
const window_hints = [
    (GLFW.SAMPLES,      4),
    (GLFW.DEPTH_BITS,   0),

    (GLFW.ALPHA_BITS,   8),
    (GLFW.RED_BITS,     8),
    (GLFW.GREEN_BITS,   8),
    (GLFW.BLUE_BITS,    8),
    (GLFW.STENCIL_BITS, 0),
    (GLFW.AUX_BUFFERS,  0),
    (GLFW.CONTEXT_VERSION_MAJOR, 3),# minimum OpenGL v. 3
    (GLFW.CONTEXT_VERSION_MINOR, 0),# minimum OpenGL v. 3.0
    (GLFW.OPENGL_PROFILE, GLFW.OPENGL_ANY_PROFILE),
    (GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE),
]

function create_glcontext(title; resolution)
    for (key, value) in window_hints
        GLFW.WindowHint(key, value)
    end
    window = GLFW.CreateWindow(resolution..., title)
    GLFW.MakeContextCurrent(window)
    return window
end

end
