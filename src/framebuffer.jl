gl_color_attachment(i) = GLuint(GL_COLOR_ATTACHMENT0 + i)

@enum DepthFormat depth16 depth24 depth32 depth32f
@enum DepthStencilFormat depth_stencil32 depth_stencil40

gl_internal_format(d::DepthFormat)        = d == depth32f ? GL_DEPTH_COMPONENT32F : GLuint(GL_DEPTH_COMPONENT16 + Int(d))
gl_internal_format(d::DepthStencilFormat) = d == depth_stencil32 ? GL_DEPTH24_STENCIL8 : GL_DEPTH32F_STENCIL8

#TODO talk about Contexts!
"""
Holds the id, format and attachment of an OpenGL RenderBuffer.
RenderBuffers cannot be read by Shaders.
"""
struct RenderBuffer
    id        ::GLuint
    format    ::GLenum
    attachment::GLenum
    # context ::GLContext
    function RenderBuffer(format::GLenum, attachment::GLenum, dimensions)
        @assert length(dimensions) == 2
        id = glGenRenderbuffers(format, attachment, dimensions)
        new(id, format, attachment)
    end
end

"Creates a `RenderBuffer` with purpose for the `depth` component of a `FrameBuffer`."
function RenderBuffer(depth_format::Union{DepthFormat, DepthStencilFormat}, dimensions)
    if typeof(depth_format) == DepthFormat
        return RenderBuffer(gl_internal_format(depth_format), GL_DEPTH_ATTACHMENT, dimensions)
    elseif typeof(depth_format) == DepthStencilFormat
        return RenderBuffer(gl_internal_format(depth_format), GL_DEPTH_STENCIL_ATTACHMENT, dimensions)
    else
        error("depth format not recognized.")
    end
end

function bind(b::RenderBuffer)
    glBindRenderbuffer(GL_RENDERBUFFER, b.id)
end

function Base.resize!(b::RenderBuffer, dimensions) 
    bind(b)
    glRenderbufferStorage(GL_RENDERBUFFER, b.format, dimensions...)
end


"""
A FrameBuffer holds all the data related to the usual OpenGL FrameBufferObjects. 
The `textures` field gets mappend to the different possible GL_COLOR_ATTACHMENTs, which is bound by GL_MAX_COLOR_ATTACHMENTS. 
"""
struct FrameBuffer{N}
    id       ::GLuint
    textures ::NTuple{N, Texture}
    depth    ::RenderBuffer
end
function FrameBuffer(fb_size, texture_types, depth_format = depth_stencil32)
    dimensions = tuple(fb_size...)
    
    framebuffer = glGenFramebuffers()
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer)
   
    if length(texture_types) > glGetIntegerv(GL_MAX_COLOR_ATTACHMENTS) 
        error("The length of texture types exceeds the maximum amount of framebuffer color attachments!") 
    end

    textures = Texture[]
    for (i, tex_type) in enumerate(texture_types)
        texture = Texture(tex_type, dimensions, minfilter=:nearest, x_repeat=:clamp_to_edge) 
        attach2_framebuffer(texture, gl_color_attachment(i))
        push!(textures, texture)
    end

    #i think you can actually also just use  a texture for depth... 
    depth = RenderBuffer(depth_format, dimensions)
    @assert glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE

    glBindFramebuffer(GL_FRAMEBUFFER, 0)

    return FrameBuffer{length(textures)}(framebuffer, tuple(textures...), depth)
end

function attach2_framebuffer(t::Texture{T, 2}, attachment) where T
    glFramebufferTexture2D(GL_FRAMEBUFFER, attachment, GL_TEXTURE_2D, t.id, 0)
end

Base.size(fb::FrameBuffer) = size(fb.textures[1]) # it's guaranteed that they all have the same size

function Base.resize!(fb::FrameBuffer, dimensions)
    ws = dimensions[1], dimensions[2]
    if ws != size(fb) && all(x -> x > 0, dimensions)
        dimensions = tuple(dimensions...)
        for texture in fb.textures
            resize_nocopy!(texture, dimensions)
        end
        resize!(fb.depth, dimensions)
    end
    nothing
end
