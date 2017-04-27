using ModernGL, GLWindow, GLAbstraction, GLFW, GeometryTypes
using GLAbstraction, GLWindow, ModernGL, GeometryTypes
using GLAbstraction: compile_shader

function compile_program(shaders...)
    program = GLAbstraction.createprogram()
    glUseProgram(program)
    #attach new ones
    foreach(shaders) do shader
        glAttachShader(program, shader.id)
    end

    #link program
    glLinkProgram(program)
    if !GLAbstraction.islinked(program)
        error(
            "program $program not linked. Error in: \n",
            join(map(x-> string(x.name), shaders), " or "), "\n", GLAbstraction.getinfolog(program)
        )
    end
    program
end


vert = """
#version 450
layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;

layout (std140) uniform Scene{
    mat4 view;
    vec4 color;
} scene;

out vec4 frag_color;

void main(){
    frag_color = vec4(scene.color.r, normal);
    gl_Position = scene.view * vec4(position, 0, 1.0);
}
"""

frag = """
#version 450
layout (location = 0) out vec4 outColor;
in vec4 frag_color;

void main() {
    outColor = frag_color;
}
"""
window = GLWindow.create_glcontext("Example", resolution = (512, 512), debugging = true)

vertshader = compile_shader(Vector{UInt8}(vert), GL_VERTEX_SHADER, :vertexshader)
fragshader = compile_shader(Vector{UInt8}(frag), GL_FRAGMENT_SHADER, :fragshader)
program = compile_program(vertshader, fragshader)

catmesh = normalmesh(load(Pkg.dir("GLVisualize", "assets", "cat.obj")))
vbo = VertexArray(catmesh, 0)

uniform_array = UniformBuffer((eye(Mat4f0), Vec4f0(1, 1, 0, 1)))
buff = uniform_array.buffer

glClearColor(0, 0, 0, 1)

sceneidx = glGetUniformBlockIndex(program, "Scene")
glUniformBlockBinding(program, sceneidx, 0)
glBindBufferBase(GL_UNIFORM_BUFFER, 0, uniform_array.buffer.id)

glUseProgram(program)
glBindVertexArray(vbo.id)

while isopen(window)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glDrawArrays(GL_TRIANGLES, 0, 3)
    swapbuffers(window)
    poll_glfw()
end
GLFW.DestroyWindow(window)
