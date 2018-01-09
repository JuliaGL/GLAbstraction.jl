using ModernGL, GLWindow, GLAbstraction, GLFW, ColorTypes, Reactive, GeometryTypes
import GLAbstraction: N0f8

const window = create_glcontext("Example")


const vert = vert"""
{{GLSL_VERSION}}

in vec2 vertices;
in vec2 texturecoordinates; // must be this name, because collect_for_gl assumes them

out vec2 f_uv;
void main() {
    f_uv = texturecoordinates;
    gl_Position = vec4(vertices, 0.0, 1.0);
}
"""

# you can also load the shader from a file, which you can then edit in any editor and the changes will show up in your opengl program.
#using FileIO; prrogram = TemplateProgram(load("path_to_frag.frag"), load("path_to_vert.vert"))
const frag = frag"""
{{GLSL_VERSION}}

out vec4 outColor;
uniform sampler2D image;
in vec2 f_uv;

void main() {

    outColor = texture(image, f_uv);
}
"""
program = LazyShader(vert, frag)

tex = Texture([RGBA{N0f8}(x,y,sin(x*pi), 1.0) for x=0:0.1:1., y=0:0.1:1.]) #automatically creates the correct texture
data = merge(Dict(
    :image => tex,
    :primitive => GLUVMesh2D(SimpleRectangle{Float32}(-1,-1,2,2))
)) # Transforms the rectangle into a 2D mesh with uv coordinates and then extracts the buffers for the shader

robj = std_renderobject(data, program) # creates a renderable object from the shader and the data.

glClearColor(0, 0, 0, 1)


while isopen(window)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    render(robj)
    swapbuffers(window)
    poll_glfw()
end
GLFW.DestroyWindow(window)
