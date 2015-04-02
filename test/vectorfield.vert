{{GLSL_VERSION}}
{{GLSL_EXTENSIONS}}

in vec3 vertex;
in vec3 normal_vector; // normal might not be an uniform, whereas the other will be allways uniforms

struct Cube{
    vec3 min; 
    vec3 max;   
} boundingbox;

uniform vec2 color_range; 

uniform sampler3D vectorfield;
uniform sampler1D colormap;

uniform mat4 modelmatrix;
uniform mat4 projection, view;

uniform vec3 light_position;


out vec3 N;
out vec3 V;
out vec3 L;

out vec4 vert_color;



vec3 stretch(vec3 uv, vec3 from, vec3 to)
 {
   return from + (uv * (to - from));
 }
vec2 stretch(vec2 uv, vec2 from, vec2 to)
 {
   return from + (uv * (to - from));
 }
 float stretch(float uv, float from, float to)
 {
   return from + (uv * (to - from));
 }

const vec3 up = vec3(0,0,1);

mat4 rotation(vec3 direction)
{
    mat4 viewMatrix = mat4(1.0);

    if(direction == up)
    {
        return viewMatrix;
    }
    viewMatrix[0] = vec4(normalize(direction), 0);
    viewMatrix[1] = vec4(normalize(cross(up, viewMatrix[0].xyz)), 0);
    viewMatrix[2] = vec4(normalize(cross(viewMatrix[0].xyz, viewMatrix[1].xyz)), 0);
    
    return viewMatrix;
}
mat4 getmodelmatrix(vec3 xyz, vec3 scale)
{
   return mat4(
      vec4(scale.x, 0, 0, 0),
      vec4(0, scale.y, 0, 0),
      vec4(0, 0, scale.z, 0),
      vec4(xyz, 1));
}
int ind2sub(int dim, int linearindex)
{
    return linearindex;
}
ivec2 ind2sub(ivec2 dim, int linearindex)
{
    return ivec2(linearindex % dim.x, linearindex / dim.x);
}
ivec3 ind2sub(ivec3 dim, int linearindex)
{
    return ivec3(linearindex / (dim.y * dim.z), (linearindex / dim.z) % dim.y, linearindex % dim.z);
}
void render(vec3 vertex, vec3 normal, mat4 model)
{
    mat4 modelview              = view * model;
    mat3 normalmatrix           = mat3(modelview); // shoudl really be done on the cpu
    vec4 position_camspace      = modelview * vec4(vertex,  1);
    vec4 lightposition_camspace = view * vec4(light_position, 1);
    // normal in world space
    N            = normalize(normalmatrix * normal);
    // direction to light
    L            = normalize(lightposition_camspace.xyz - position_camspace.xyz);
    // direction to camera
    V            = -position_camspace.xyz;
    // texture coordinates to fragment shader
    // screen space coordinates of the vertex
    gl_Position  = projection * position_camspace; 
}



void main(){
    ivec3 texdims     = textureSize(vectorfield, 0);
    ivec3 fieldindex  = ind2sub(texdims, gl_InstanceID);
    vec3 uvw          = vec3(fieldindex) / vec3(texdims);
    vec3 vectororigin = stretch(uvw, boundingbox.min, boundingbox.max);
    vec3 vector       = texelFetch(vectorfield, fieldindex, 0).xyz;
    float vlength     = length(vector);
    mat4 rotation_mat = rotation(vector);
    vert_color        = texture(colormap, vlength);
    render(vertex, normal_vector, modelmatrix*getmodelmatrix(vectororigin, vec3(1))*rotation_mat);
}