abstract Camera{T}

type OrthographicCamera{T} <: Camera{T}
    window_size     ::Signal{SimpleRectangle{Int}}
    view            ::Signal{Mat{4,4,T}}
    projection      ::Signal{Mat{4,4,T}}
    projectionview  ::Signal{Mat{4,4,T}}
end

type PerspectiveCamera{T} <: Camera{T}
    window_size     ::Signal{SimpleRectangle{Int}}
    pivot           ::Signal{Pivot{T}}
    nearclip        ::Signal{T}
    farclip         ::Signal{T}
    fov             ::Signal{T}
    view            ::Signal{Mat{4,4,T}}
    projection      ::Signal{Mat{4,4,T}}
    projectionview  ::Signal{Mat{4,4,T}}
    eyeposition     ::Signal{Vec{3, T}}
    lookat          ::Signal{Vec{3, T}}
    up              ::Signal{Vec{3, T}}
end

type DummyCamera{T} <: Camera{T}
    window_size     ::Signal{SimpleRectangle{Int}}
    view            ::Signal{Mat{4,4,T}}
    projection      ::Signal{Mat{4,4,T}}
    projectionview  ::Signal{Mat{4,4,T}}
end

function DummyCamera(;
        window_size    = Signal(SimpleRectangle(-1, -1, 1, 1)),
        view           = Signal(eye(Mat{4,4, Float32})),
        nearclip       = Signal(10000f0),
        farclip        = Signal(-10000f0),
        projection     = const_lift(orthographicprojection, window_size, nearclip, farclip),
        projectionview = const_lift(*, projection, view)
    )
    DummyCamera{Float32}(window_size, view, projection, projectionview)
end

function Base.collect(camera::Camera)
    collected = Dict{Symbol, Any}()
    names     = fieldnames(camera)
    for name in (:view, :projection, :projectionview, :eyeposition)
        if name in names
            collected[name] = camera.(name)
        end
    end
    return collected
end


function viewmatrix(v0, scroll_xy, buttonset)
    translatevec = Vec3f0(0f0)
    scroll_y, scroll_x = Vec2f0(scroll_xy)
    if scroll_x == 0f0
        if in(341, buttonset) # left strg key
            translatevec = Vec3f0(scroll_y*20f0, 0f0, 0f0)
        else
            translatevec = Vec3f0(0f0, scroll_y*20f0, 0f0)
        end
    else
        translatevec = Vec3f0(scroll_x*10f0, scroll_y*10f0, 0f0)
    end
    v0 * translationmatrix(translatevec)
end

"""
Creates an orthographic camera with the pixel perfect plane in z == 0
Signals needed:
Dict(
    :window_size           => Signal(SimpleRectangle{Int}),
    :buttons_pressed       => Signal(Int[]),
    :mouse_buttons_pressed => Signal(Int[]),
    :mouseposition         => mouseposition, -> Panning
    :scroll_y              => Signal(0) -> Zoomig
)
"""
function OrthographicPixelCamera(inputs::Dict{Symbol, Any})
    @materialize mouseposition, buttons_pressed = inputs
    #Should be rather in Image coordinates
    view = foldp(viewmatrix, eye(Mat{4,4, Float32}), inputs[:scroll], buttons_pressed)
    OrthographicCamera(
        inputs[:window_size],
        view,
        Signal(-10f0), # nearclip
        Signal(10f0) # farclip
    )

end


"""
Creates an orthographic camera from signals, controlling the camera
Args:

window_size: Size of the window
zoom: Zoom
translatevec: Panning
normedposition: Pivot for translations
"""
function OrthographicCamera{T}(
        windows_size ::Signal{SimpleRectangle{Int}},
        view         ::Signal{Mat{4,4,T}},
        nearclip     ::Signal{T},
        farclip      ::Signal{T}
    )

    projection = const_lift(orthographicprojection, windows_size, nearclip, farclip)
    projectionview = const_lift(*, projection, view)

    OrthographicCamera{T}(
        windows_size,
        view,
        projection,
        projectionview
    )
end


mousepressed(mousebuttons::IntSet, button::Int) = in(button, mousebuttons)

thetalift(mdL, speed) = Vec3f0(0f0, -mdL[2]/speed, mdL[1]/speed)
translationlift(xy, z) = Vec3f0(scroll_y, mdM[1]/200f0, -mdM[2]/200f0)

function default_camera_control(
        inputs;
        trans = Signal(Vec3f0(0)), 
        theta = Signal(Vec3f0(0)), 
        keep  = Signal(true)
    )
    @materialize mouseposition, mouse_buttons_pressed, scroll = inputs

    mouseposition = map(Vec2f0, mouseposition)
    left_pressed  = map(pressed, mouse_buttons_pressed, MOUSE_LEFT)
    right_pressed = map(pressed, mouse_buttons_pressed, MOUSE_RIGHT)
    clickedkeyL   = dragged(mouseposition, left_pressed, keep)
    clickedkeyM   = dragged(mouseposition, right_pressed, keep)

    zoom = filterwhen(keep, 0f0, 
        const_lift(Float32, const_lift(/, map(last, scroll), 5f0))
    )
    _theta = filterwhen(keep, Vec3f0(0), 
        merge(const_lift(thetalift, clickedkeyL, 50f0), theta)
    )
    _trans = filterwhen(keep, Vec3f0(0), 
        merge(const_lift(translationlift, zoom, clickedkeyM), trans)
    )
    _theta, _trans, zoom
end



function translate_zoom_theta(
        xytranslate, ztranslate, xytheta, 
        rotation_speed, translation_speed
    )
    theta = map(thetalift, xtheta, rotation_speed)
    trans = map(translationlift, xytranslate, ztranslate)
    theta, trans
end

"""
Creates a perspective camera from a dict of signals
Args:

inputs: Dict of signals, looking like this:
[
    :window_size            => Signal(Vec{2, Int}),
    :buttons_pressed        => Signal(Int[]),
    :mouse_buttons_pressed  => Signal(Int[]),
    :mouseposition          => mouseposition, -> Panning + Rotation
    :scroll_y               => Signal(0) -> Zoomig
]
eyeposition: Position of the camera
lookatvec: Point the camera looks at
"""
function PerspectiveCamera{T}(inputs::Dict{Symbol,Any}, eyeposition::Vec{3, T}, lookatvec::Vec{3, T})
    theta,trans,zoom = default_camera_control(inputs)

    cam = PerspectiveCamera(
        inputs[:window_area],
        eyeposition,
        lookatvec,
        theta,
        trans,
        zoom,
        Signal(41f0),
        Signal(1f0),
        Signal(100f0)
    )
end



function update_pivot(v0, v1)
    theta, translation, reset, resetto = v1
    xaxis = v0.rotation * v0.xaxis # rotate the axis
    yaxis = v0.rotation * v0.yaxis
    zaxis = v0.rotation * v0.zaxis
    if reset
        v1rot = resetto
    else
        xrot  = Quaternions.qrotation(xaxis, theta[1])
        yrot  = Quaternions.qrotation(yaxis, theta[2])
        zrot  = Quaternions.qrotation(Vec(0f0,0f0,1f0), theta[3])
        v1rot = zrot*xrot*yrot*v0.rotation
    end

    v1trans    = yaxis*translation[2] + zaxis*translation[3]
    accumtrans = v1trans + v0.translation

    Pivot(
        v0.origin + v1trans,
        v0.xaxis,
        v0.yaxis,
        v0.zaxis,
        v1rot,
        accumtrans + v0.xaxis*translation[1],
        v0.scale
    )
end

getupvec(p::Pivot) = p.rotation * p.zaxis

function projection_switch{T<:Real}(
        w::SimpleRectangle, 
        fov::T, near::T, far::T, projection::Projection
    )
    aspect = T(wh.w/wh.h)
    h      = T(tan(fov / 360.0 * pi) * near)
    w      = T(h * aspect)
    projection == PERSPECTIVE && return frustum(-w, w, -h, h, znear, zfar)
    orthographicprojection(-w, w, -h, h, near, far) # can only be orthographic...
end

"""
Creates a perspective camera from signals, controlling the camera
Args:

window_size: Size of the window
zoom: Zoom
eyeposition: Position of the camera
lookatvec: Point the camera looks at

xtheta: xrotation angle
ytheta: yrotation angle
ztheta: zrotation angle

xtrans: x translation
ytrans: y translation
ztrans: z translation
fov: Field of View
nearclip: Near clip plane
farclip: Far clip plane
"""
function PerspectiveCamera{T <: Real}(
        window_size     ::Signal{SimpleRectangle{Int}},
        eyeposition     ::Vec{3, T},
        lookatvec       ::Union{Signal{Vec{3, T}}, Vec{3, T}},
        theta           ::Signal{Vec{3, T}},
        trans           ::Signal{Vec{3, T}},
        zoom            ::Signal{T},
        fov             ::Signal{T},
        nearclip        ::Signal{T},
        farclip         ::Signal{T},
        projection 	= Signal(PERSPECTIVE),
        reset   	= Signal(false),
        resetto 	= Signal(Quaternions.Quaternion(T(1),T(0),T(0),T(0)))
    )

    origin          = lookatvec
    vup             = Vec{3, T}(0,0,1)
    xaxis           = const_lift(-, eyeposition, lookatvec)
    yaxis           = const_lift(cross, xaxis, vup)
    zaxis           = const_lift(cross, yaxis, xaxis)

    pivot0          = Pivot(value(lookatvec), value(xaxis), value(yaxis), value(zaxis), Quaternions.Quaternion(T(1),T(0),T(0),T(0)), zero(Vec{3, T}), Vec{3, T}(1))
    pivot           = foldp(update_pivot, pivot0, const_lift(tuple, theta, trans, reset, resetto))

    modelmatrix     = const_lift(transformationmatrix, pivot)
    positionvec     = const_lift(*, modelmatrix, Vec(eyeposition, one(T)))
    positionvec     = const_lift(Vec{3,T}, positionvec)

    up              = const_lift(getupvec, pivot)
    lookatvec1      = const_lift(origin, pivot)

    view            = const_lift(lookat, positionvec, lookatvec1, up)
    pmatrix      	= const_lift(projection_switch, window_size, fov, nearclip, farclip, projection)

    projectionview  = const_lift(*, pmatrix, view)

    PerspectiveCamera{T}(
        window_size,
        pivot,
        nearclip,
        farclip,
        fov,
        view,
        pmatrix,
        projectionview,
        positionvec,
        lookatvec1,
        up
    )
end
