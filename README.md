# GLAbstraction
A simple library, which makes the use of OpenGL a little bit more convenient and Julian.
If you have any questions, please open an issue.

There are some [tutorials](tutorials/README.md) and [examples](https://github.com/JuliaGL/GLAbstraction.jl/tree/master/example).

### Features

* Some linear algebrae, to do all kinds of transformations.
* All the different glUniform functions are wrapped and the right function is determined via multiple dispatch (works for [FixedSizeArrays](https://github.com/SimonDanisch/FixedSizeArrays.jl), [Colors](https://github.com/JuliaGraphics/Colors.jl) and Real numbers)
* `Buffers` and `Texture` objects are wrapped, with best support for arrays of FixedSizeArrays, Colors and Reals.
* An Array interface for `Buffers` and `Textures`, offering functions like `push!`, `getindex`, `setindex!`, etc for GPU arrays, just like you're used to from Julia Arrays.
* Shader loading is simplified and offers templated shaders and interactive editing of shaders and type/error checks.
* Offers the type `RenderOject`, which helps you preparing the OpenGL state to render data with a shader.
* Event handling with [Reactive](https://github.com/JuliaLang/Reactive.jl)
* Two camera types (PerspectiveCamera and OrthogonalCamera), which can be instantiated with a list of React signals from GLWindow. You can also supply your own signals.
* Some wrappers for often used functions, with embedded error handling and more Julian syntax




### Example:

```julia
using ModernGL, GLWindow, GLAbstraction, GLFW, GeometryTypes

window = GLWindow.create_glcontext("Example", resolution=(512, 512), debugging=true)


const vsh = vert"""
{{GLSL_VERSION}}
in vec2 position;
void main(){
	gl_Position = vec4(position, 0, 1.0);
}
"""
const fsh = frag"""
{{GLSL_VERSION}}
out vec4 outColor;
void main() {
	outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
"""

const triangle = std_renderobject(
	Dict{Symbol, Any}(
        :position => Buffer(Point2f0[(0.0, 0.5), (0.5, -0.5), (-0.5,-0.5)]),
    ),
	LazyShader(vsh, fsh)
)

glClearColor(0, 0, 0, 1)

while isopen(window)
  	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    render(triangle)
  	swapbuffers(window)
  	poll_glfw()
end

```

# Credits

Thanks for all the great [contributions](https://github.com/JuliaGL/GLAbstraction.jl/graphs/contributors)
