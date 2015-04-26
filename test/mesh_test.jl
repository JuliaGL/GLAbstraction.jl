using GLWindow, GLAbstraction, GLFW, ModernGL, ImmutableArrays, WavefrontObj, FixedPointNumbers, Images, Color, Reactive
using GLPlot #toopengl 
# window creation
window = createwindow("OBJ-Viewer", 1000, 1000, debugging = false)
cam = PerspectiveCamera(window.inputs, Vec3(2,2,0.5), Vec3(0.0))

# render objects creation
shader = TemplateProgram(Pkg.dir("GLPlot", "src", "shader", "standard.vert"), Pkg.dir("GLPlot", "src", "shader", "phongblinn.frag"))
RGBAU8 = AlphaColorValue{RGB{Ufixed8}, Ufixed8}
Color.rgba(r::Real, g::Real, b::Real, a::Real)    = AlphaColorValue(RGB{Float32}(r,g,b), Float32(a))
rgbaU8(r::Real, g::Real, b::Real, a::Real)  = AlphaColorValue(RGB{Ufixed8}(r,g,b), ufixed8(a))
#GLPlot.toopengl{T <: AbstractRGB}(colorinput::Input{T}) = toopengl(lift(x->AlphaColorValue(x, one(T)), RGBA{T}, colorinput))
tohsva(rgba)     = AlphaColorValue(convert(HSV, rgba.c), rgba.alpha)
torgba(hsva)     = AlphaColorValue(convert(RGB, hsva.c), hsva.alpha)
tohsva(h,s,v,a)  = AlphaColorValue(HSV(Float32(h), Float32(s), Float32(v)), Float32(a))
Base.convert{T <: AbstractAlphaColorValue}(typ::Type{T}, x::AbstractAlphaColorValue) = AlphaColorValue(convert(RGB{eltype(typ)}, x.c), convert(eltype(typ), x.alpha))
    

function unitGeometry{T}(geometry::Vector{Vector3{T}}) 
    assert(!isempty(geometry))

    xmin = typemax(T)
    ymin = typemax(T)
    zmin = typemax(T)

    xmax = typemin(T)
    ymax = typemin(T)
    zmax = typemin(T)

    for vertex in geometry
        xmin = min(xmin, vertex[1])
        ymin = min(ymin, vertex[2])
        zmin = min(zmin, vertex[3])

        xmax = max(xmax, vertex[1])
        ymax = max(ymax, vertex[2])
        zmax = max(zmax, vertex[3])
    end

    xmiddle = xmin + (xmax - xmin) / 2;
    ymiddle = ymin + (ymax - ymin) / 2;
    zmiddle = zmin + (zmax - zmin) / 2;
    scale = 2 / max(xmax - xmin, ymax - ymin, zmax - zmin);

    result = similar(geometry)

    for i = 1:length(result)
        result[i] = Vector3{T}((geometry[i][1] - xmiddle) * scale,
                               (geometry[i][2] - ymiddle) * scale,
                               (geometry[i][3] - zmiddle) * scale
                    );
    end

    return result
end


objpath = "Butterfly/Butterfly.obj"

assets_path = "Butterfly/"

obj = readObjFile(objpath, faceindextype=GLuint, vertextype=Float32, compute_normals = false, triangulate = false)
computeNormals!(obj, smooth_normals = true, override = false)
triangulate!(obj)

# center geometry
obj.vertices = unitGeometry(obj.vertices)

# load mtl files if present
materials = WavefrontMtlMaterial{Float32}[]

for mtllib in obj.mtllibs
    materials = [materials, readMtlFile( assets_path*mtllib, colortype=Float32 )] 
end




render_objects = RenderObject[]

compiled_materials = Dict()

const light         = Vec3[Vec3(1.0,1.0,1.0), Vec3(0.1,0.1,0.1), Vec3(0.9,0.9,0.9), Vec3(20.0,20.0,20.0)] 
const material      = Vec3[Vec3(1.0,1.0,1.0), Vec3(1.0,1.0,1.0), Vec3(1.0,1.0,1.0), Vec3(1.0,1.0,1.0)]
const tmaterial      = Vec4[Vec4(1.0,1.0,1.0,1.0), Vec4(1.0,1.0,1.0,1.0), Vec4(1.0,1.0,1.0,1.0), Vec4(1.0,1.0,1.0,1.0)]
const tmaterialused  = GLint[-1,-1,-1,-1]

for material_name in collect(keys(obj.materials))

    (vs, nvs, uvs, fcs) = compileMaterial(obj, material_name)

    # hack: invert normals for glabstraction
    nvs = -nvs

    # holding global references seems necessary here
    # compiled_materials[material_name] = (vs, nvs, uvs, fcs, lines)
    data = [
        :vertex          => GLBuffer(vs),
        :normal          => GLBuffer(nvs),
        :uv              => GLBuffer(uvs),
        :indexes         => indexbuffer(fcs),
        :view            => cam.view,
        :projection      => cam.projection,
        :normalmatrix    => cam.normalmatrix,
        :eyeposition     => cam.eyeposition,
        :model           => eye(Mat4),
        :material        => material,
        :light           => light,
        :textures_used   => tmaterialused,
    ]
    
    # search for a material with the given name
    texture_array = Any[]
    for mtl in materials
        if mtl.name == material_name
            data[:material]             = Vec3[mtl.diffuse, mtl.ambient, mtl.specular, Vec3(mtl.specular_exponent)]
            println(data[:material])
            if mtl.diffuse_texture != "" 
                data[:textures_used][1] = length(texture_array) # insert texture array index
                push!(texture_array, imread(assets_path*"Texture/"*mtl.diffuse_texture).data)
            end
            if mtl.ambient_texture != "" 
                data[:textures_used][2] = length(texture_array) # insert texture array index
                push!(texture_array, imread(assets_path*"Texture/"*mtl.ambient_texture).data)
            end
            if mtl.specular_texture != "" 
                data[:textures_used][3] = length(texture_array) # insert texture array index
                push!(texture_array, imread(assets_path*"Texture/"*mtl.specular_texture).data)
            end
            #=
            if mtl.bump_texture != "" 
                data[:textures_used] = true
                data[:tmaterialused][1] = 0 # insert texture array index
                push!(texture_array, imread(assets_path*mtl.diffuse_texture).data)
            end
            =#
            break
        end
    end 

    if !isempty(texture_array)
        data[:textures_used] = true
        data[:texture_maps] = Texture(convert(Vector{Matrix{eltype(first(texture_array))}}, texture_array))
    else
        data[:texture_maps] = Texture(Matrix{RGBA{Ufixed8}}[fill(rgbaU8(0,0,0,0), 1,1)])
    end

    ro = RenderObject(data, shader)

    postrender!(ro, render, ro.vertexarray)
    #postrender!(ro, render, ro.vertexarray, GL_LINES)  

    push!(render_objects, ro)
end

# OpenGL setup
glClearColor(0.2,0.2,0.2,1)
glDisable(GL_CULL_FACE)
glEnable(GL_DEPTH_TEST)

lift(window.inputs[:framebuffer_size]) do wh
    glViewport(0,0,wh...)
end
# Loop until the user closes the window
while !GLFW.WindowShouldClose(window.nativewindow)

  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

  # render materials separately
  for ro in render_objects
    render(ro)
  end

  yield() # this is needed for react to work

  GLFW.SwapBuffers(window.nativewindow)
  GLFW.PollEvents()
end

GLFW.Terminate()
