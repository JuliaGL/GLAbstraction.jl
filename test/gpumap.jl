using GLWindow, GLAbstraction, ModernGL, Reactive, GLFW, GeometryTypes

GLFW.Init()

const window = createwindow("Map Test", 512, 512, debugging=true)

kernel = vert"""
float sqrtx2(float z){return sqrt(z-1)*sqrt(z+1);}

uniform float param1;
float kernel(float x, float y){
    return x+y;
}
"""

a = preserve(Signal(Float32[i for i=1:2, j=1:2]))
b = preserve(Signal(Float32[j for i=1:2, j=1:2]))

buff = map(kernel, a,b, param1=23f0)
println(gpu_data(buff))
push!(a, Float32[77 for i=1:2, j=1:2])
println(a)
println("lol: ", gpu_data(buff))
