# GLUtil

Utility library for OpenGL.
In example you can find a simple setup of rendering a triangle with GLUtil, and GLWindow.


Some functionality offered by GLUtil:

Example:
```julia
#=
RenderObject is basically an Object that mirrors a shader object with all uniforms and attributes.
You can create a RenderObject via a Dict of the form Dict{Symbol, Any}, where the symbol represents 
a shader variable name and Any needs to be a GLBuffer or GLSL primitive like Vector1-4, Matrix1-4, Float and Int.
The constructor functions of RenderObject will lookup all the uniform locations to shorten render time and will group the GLBuffers
into a vertex Array.
This can then be drawn with: 
=#
render(x::RenderObject)
#Other render functions (which get called by render(cx::RenderObject:
render(:someShaderUniform, 1.0f0, programID) # sets someShaderUniform in program to one
render(:modelviewproj, eye(Float32, 4,4), programID) # sets the modelviewproj to the identity matrix
render(x::VertexArray) #determines if vertex array is indexed, and then renders it correctly to the screen
#=
At some point, I want to introduce the functionality, to define prerender and postrender functions, 
to set-up things like transparency before rendering.
=#
#=
A shader can be read in with GLProgram(filepath/shaderName)
=#
program = GLProgram("flatShader") #This call assumes, that you have two files in your current directory, namely flatShader.frag and flatShader.vert
#To read in shaders from a source string, use this function:
program2 = GLProgram(vertexShaderSource::String, fragmentShaderSource::String, name::String)

```


There are two camera types given in GLUtil, PerspectiveCamera and OrthogonalCamera, which both have an empty constructor with some standard values.
Also there are a few functions to manipulate the camera, like resize, move and rotate.
I'll upload a few examples soon.


#Status
the api will change a lot in the future, so be prepared to accomodate changes...