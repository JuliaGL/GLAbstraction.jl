gl_color_attachment(i) = GLuint(GL_COLOR_ATTACHMENT0 + i)

abstract type DepthFormat end

struct Depth{DT} <: DepthFormat
    depth::DT
end

# TODO maybe we should implement this as a 32 bit wide primitive type
# and overload getproperty (getfield on 0.7) to implement depthstencil.depth with masking
# since you almost always want to have depthstencil.depth::Float32
struct DepthStencil{DT, ST} <: DepthFormat
    depth::DT
    stencil::ST
end
#0.7: Base.getproperty(x::DepthStencil, field::Symbol) = field == :depth ? Float32(x.depth) : x.stencil #I actually do want to support v0.6 for now

"""
Float24 storage type for depth
"""
primitive type Float24 <: AbstractFloat 24 end

gl_internal_format(::Type{Depth{Float32}}) = GL_DEPTH_COMPONENT32F
gl_internal_format(::Type{DepthStencil{Float24, N0f8}}) = GL_DEPTH24_STENCIL8

function gl_internal_format(::T) where T
    error("$T doesn't have a valid mapping to an OpenGL internal format enum. Please use DepthStencil/Depth/Color, or overload `gl_internal_format(x::$T)`
    to return the correct OpenGL format enum.
    ")
end

gl_attachment(::Type{<:Depth}) = GL_DEPTH_ATTACHMENT
gl_attachment(::Type{<:DepthStencil}) = GL_DEPTH_STENCIL_ATTACHMENT
function gl_attachment(::T) where T
    error("$T doesn't have a valid mapping to an OpenGL attachment enum. Please use DepthStencil/Depth, or overload `gl_attachment(x::$T)`
    to return the correct OpenGL depth attachment.
    ")
end
#TODO talk about Contexts!
"""
Holds the id, format and attachment of an OpenGL RenderBuffer.
RenderBuffers cannot be read by Shaders.
"""
struct RenderBuffer
    id        ::GLuint
    format    ::GLenum
    attachment::GLenum
    context   ::AbstractContext
    function RenderBuffer(format::GLenum, attachment::GLenum, dimensions)
        @assert length(dimensions) == 2
        id = glGenRenderbuffers(format, attachment, dimensions)
        new(id, format, attachment, current_context())
    end
end

"Creates a `RenderBuffer` with purpose for the `depth` component of a `FrameBuffer`."
function RenderBuffer(depth_format, dimensions)
    return RenderBuffer(gl_internal_format(depth_format), gl_attachment(depth_format), dimensions)
end


bind(b::RenderBuffer) = glBindRenderbuffer(GL_RENDERBUFFER, b.id)
unbind(b::RenderBuffer) = glBindRenderbuffer(GL_RENDERBUFFER, b.id)

function resize_nocopy!(b::RenderBuffer, dimensions)
    bind(b)
    glRenderbufferStorage(GL_RENDERBUFFER, b.format, dimensions...)
end


"""
A FrameBuffer holds all the data related to the usual OpenGL FrameBufferObjects.
The `attachments` field gets mapped to the different possible GL_COLOR_ATTACHMENTs, which is bound by GL_MAX_COLOR_ATTACHMENTS,
and to one of either a GL_DEPTH_ATTACHMENT or GL_DEPTH_STENCIL_ATTACHMENT.
"""
struct FrameBuffer{ElementTypes, Internal}
    id::GLuint
    attachments::Internal
end
FrameBuffer(fb_size::Tuple{<: Integer, <: Integer}, texture_types...) = FrameBuffer(fb_size, texture_types)

function create_attachment(T, dimensions, lastcolor)
    tex = Texture(T, dimensions, minfilter = :nearest, x_repeat = :clamp_to_edge)
    # textures will be color attachments right now. Otherwise we'd need to check for detph attachments
    tex, lastcolor + 1
end
create_attachment(::Type{T}, dimensions, lastcolor) where T <: DepthFormat = (RenderBuffer(T, dimensions), lastcolor)

function FrameBuffer(fb_size::Tuple{<: Integer, <: Integer}, texture_types::NTuple{N, Any}) where N
    dimensions = Int.(fb_size)

    framebuffer = glGenFramebuffers()
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer)
    max_ca = glGetIntegerv(GL_MAX_COLOR_ATTACHMENTS)

    invalid_types = filter(x -> !(x <: DepthFormat || x <: GLArrayEltypes), texture_types)
    @assert isempty(invalid_types) "Types $invalid_types are not valid, supported types are:\n  $GLArrayEltypes\n  DepthFormat."
    if N > max_ca
        error("The length of texture types exceeds the maximum amount of framebuffer color attachments! Found: $N, allowed: $max_ca")
    end
    if length(collect(filter(x-> x <: DepthFormat, texture_types))) > 1
        error("The amount of DepthFormat types in texture types exceeds the maximum of 1.")
    end

    _attachments = []
    color_id = -1
    for T in texture_types
        attachment, color_id = create_attachment(T, dimensions, color_id)
        attach2framebuffer(attachment, gl_color_attachment(color_id))
        push!(_attachments, attachment)
    end

    attachments = (_attachments...,)

    @assert glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    return FrameBuffer{Tuple{texture_types...}, typeof(attachments)}(framebuffer, attachments)
end

function attach2framebuffer(t::Texture{T, 2}, attachment) where T
    glFramebufferTexture2D(GL_FRAMEBUFFER, attachment, GL_TEXTURE_2D, t.id, 0)
end
function attach2framebuffer(x::RenderBuffer, attachment)
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, x.attachment, GL_RENDERBUFFER, x.id)
end

Base.size(fb::FrameBuffer) = size(fb.textures[1]) # it's guaranteed that they all have the same size

function Base.resize!(fb::FrameBuffer, dimensions)
    ws = dimensions[1], dimensions[2]
    if ws != size(fb) && all(x -> x > 0, dimensions)
        dimensions = tuple(dimensions...)
        for attachment in fb.attachments
            resize_nocopy!(attachment, dimensions)
        end
    end
    nothing
end

bind(fb::FrameBuffer) = glBindFramebuffer(GL_FRAMEBUFFER, fb.id)
unbind(fb::FrameBuffer) = glBindFramebuffer(GL_FRAMEBUFFER, 0)
function Base.clear!(fb::FrameBuffer, color::RGBA) 
    bind(fb)
    glClearColor(GLfloat(color.r), GLfloat(color.g), GLfloat(color.b), GLfloat(color.alpha))
    color_attachments = GLuint[]
    println(eltype(fb))
    for typ in eltype(fb)[1]
        if !(typeof(typ) <: DepthFormat)
            push!(color_attachments, gl_color_attachment(length(color_attachments)))
        end
    end
    glDrawBuffers(GLuint(length(color_attachments)), color_attachments)
    glClear(GL_COLOR_BUFFER_BIT)
    glClear(GL_DEPTH_BUFFER_BIT)
    unbind(fb)
end
clear!(fb::FrameBuffer, color::RGB{T}) where T = clear!(fb, RGBA(color.r, color.g, color.b, T(0.0)))
clear!(fb::FrameBuffer) = clear!(fb, RGBA(0.0, 0.0, 0.0, 0.0))
