# GLAbstraction
A simple library, which makes the use of OpenGL a little bit more convinient and Julian.


### Features
* Some linear algebrae, to do all kinds of transformations.
* Aliases for ImmutableArrays, which are more GLSL alike (e.g. Vector3{Float32} -> Vec3, Matrix4x4{Float32} -> Mat4)
* All the different glUniform functions are wrapped and the right function is determined via multiple dispatch (just works for ImmutableArrays and Real numbers)
* Buffers and Texture objects are wrapped, with best support for arrays of ImmutableArrays. 
* Shader loading is simplified and offers templated shaders and interactive editing of shaders and type/error checks.
* Offers the type `RenderOject`, which helps you preparing the OpenGL state to render data with a shader. 
* Event handling with [React](https://github.com/shashi/React.jl)
* Two camera types (PerspectiveCamera and OrthogonalCamera), which can be instantiated with a list of React signals from GLWindow. You can also supply your own signals.
* Some wrappers for often used functions, with embedded error handling and more Julian syntax




### Example:
```julia


```



#Status
There is still quite a bit missing.
