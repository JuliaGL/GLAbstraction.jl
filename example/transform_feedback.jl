using GLWindow, GLAbstraction, ModernGL, Reactive, GLFW, GeometryTypes

GLFW.Init()

const window = createwindow("Transform Feedback", 512, 512, debugging=true)
# In order to write to a texture, we have to introduce it as image2D.
# local_size_x/y/z layout variables define the work group size.
# gl_GlobalInvocationID is a uvec3 variable giving the global ID of the thread,
# gl_LocalInvocationID is the local index within the work group, and
# gl_WorkGroupID is the work group's index
const shader = vert"""
{{GLSL_VERSION}}

{{arg1_type}} arg1;
{{arg2_type}} arg2;

{{out1_type}} out1;

{{KERNEL}}

void main() {
    out1 = kernel(arg1, arg2);
}
"""
kernel = vert"""
float sqrtx2(float z){return sqrt(z-1)*sqrt(z+1);}
float kernel(float x, float y){
    return (x+x + sqrtx2(x+x));
}
"""

ro, outbuffer = map(kernel, Float32[i for i=1:10])

render(ro)

println(gpu_data(outbuffer))


GLFW.Terminate()
