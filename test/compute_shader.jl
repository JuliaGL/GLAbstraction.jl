using GLWindow, GLAbstraction, ModernGL, Reactive
const window = createwindow("Compute Shader", 512, 512, debugging=true)

# In order to write to a texture, we have to introduce it as image2D.
# local_size_x/y/z layout variables define the work group size.
# gl_GlobalInvocationID is a uvec3 variable giving the global ID of the thread,
# gl_LocalInvocationID is the local index within the work group, and
# gl_WorkGroupID is the work group's index
const shader = comp"""
    #version 430
    uniform float roll;
    uniform image2D destTex;
    layout (local_size_x = 16, local_size_y = 16) in;
    void main() {
        ivec2 storePos = ivec2(gl_GlobalInvocationID.xy);
        float localCoef = length(vec2(ivec2(gl_LocalInvocationID.xy)-8)/8.0);
        float globalCoef = sin(float(gl_WorkGroupID.x+gl_WorkGroupID.y)*0.1 + roll)*0.5;
        imageStore(destTex, storePos, vec4(1.0-globalCoef*localCoef, 0.0, 0.0, 0.0));
    }
"""

const tex_vert = vert"""
    {{GLSL_VERSION}}

    in vec2 vertex;
    in vec2 uv;

    out vec2 uv_frag;

    uniform mat4 projectionview;
    void main(){
      uv_frag = uv;
      gl_Position = projectionview * vec4(vertex, 0, 1);
    }
"""
const tex_frag = frag"""
    {{GLSL_VERSION}}

    in vec2 uv_frag;
    out vec4 frag_color;

    {{image_type}} image;

    void main(){
        float c = texture(image, uv_frag).x;
        frag_color = vec4(c, 1.0, 1.0, 1.0);
    }
"""
# mostly taken from glvisualize
function visualize{T}(img::Texture{T, 2}, cam)
  w, h = size(img)
  texparams = [
     (GL_TEXTURE_MIN_FILTER, GL_NEAREST),
    (GL_TEXTURE_MAG_FILTER, GL_NEAREST),
    (GL_TEXTURE_WRAP_S,  GL_CLAMP_TO_EDGE),
    (GL_TEXTURE_WRAP_T,  GL_CLAMP_TO_EDGE)
  ]

  v, uv, indexes = genquad(0f0, 0f0, Float32(w), Float32(h))
  v_buffer       = GLBuffer(v)
  uv_buffer      = GLBuffer(uv)
  i_buffer       = indexbuffer(indexes)

  data = Dict(
    :vertex           => v_buffer,
    :index            => i_buffer,
    :uv               => uv_buffer,
    :image            => img,
    :projectionview   => cam.projectionview,
  )

  textureshader = TemplateProgram([tex_frag, tex_vert], attributes=data)
  obj           = RenderObject(data, Input(textureshader))

  prerender!(obj, glDisable, GL_DEPTH_TEST, enabletransparency, glDisable, GL_CULL_FACE)
  postrender!(obj, render, obj.vertexarray)
  obj
end

prg = TemplateProgram([shader;])

i = 0f0
const roll = lift(Float32, every(0.1)) do x
    global i
    i+=0.01f0
end
const tex = Texture(Float32, [512, 512])
glBindImageTexture(0, tex.id, 0, GL_FALSE, 0, GL_WRITE_ONLY, tex.internalformat);

const data = Dict(
    :roll => roll,
    :destTex => tex,
)
const ro = RenderObject(data, Input(prg))
postrender!(ro, glDispatchCompute, div(512,16), div(512,16), 1) # 512^2 threads in blocks of 16^2

texobj = visualize(tex, window.orthographiccam)

glClearColor(0,0,0,1)
frame = 0f0
while !GLFW.WindowShouldClose(window.nativewindow)

    yield()
    render(ro)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    render(texobj)
    GLFW.SwapBuffers(window.nativewindow)
    GLFW.PollEvents()
    sleep(0.01)
end
GLFW.Terminate()
