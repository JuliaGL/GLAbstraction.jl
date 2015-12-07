abstract Camera{T}

type OrthographicCamera{T} <: Camera{T}
    window_size     ::Signal{SimpleRectangle{Int}}
    view            ::Signal{Mat{4,4,T}}
    projection      ::Signal{Mat{4,4,T}}
    projectionview  ::Signal{Mat{4,4,T}}
end
type PerspectiveCamera{T} <: Camera{T}
    pivot           ::Signal{Pivot{T}}
    window_size     ::Signal{SimpleRectangle{Int}}
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
        (name in names) && (collected[name] = camera.(name))
    end
    return collected
end

function mousediff{T}(v0::Tuple{Bool, Vec{2, T}, Vec{2, T}},  clicked::Bool, pos::Vec{2, T})
    clicked0, pos0, pos0diff = v0
    (clicked0 && clicked) && return (clicked, pos, pos - pos0)
    return (clicked, pos, Vec{2, T}(0.0))
end
function viewmatrix(v0, scroll_x, scroll_y, buttonset)
    translatevec = Vec3f0(0f0)
    scroll_y = Float32(scroll_y)
    scroll_x = Float32(scroll_x)
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

#=
Creates an orthographic camera with the pixel perfect plane in z == 0
Signals needed:
[
:window_size                    => Signal(SimpleRectangle{Int}),
:buttonspressed                    => Signal(Int[]),
:mousebuttonspressed            => Signal(Int[]),
:mouseposition                    => mouseposition, -> Panning
:scroll_y                        => Signal(0) -> Zoomig
]
=#
function OrthographicPixelCamera(inputs::Dict{Symbol, Any})
    @materialize mouseposition, buttonspressed = inputs
    #Should be rather in Image coordinates
    view = foldp(viewmatrix, eye(Mat{4,4, Float32}), inputs[:scroll_x], inputs[:scroll_y], buttonspressed)
    OrthographicCamera(
        inputs[:window_size],
        view,
        Signal(-10f0), # nearclip
        Signal(10f0) # farclip
    )

end

#accumulates plus multiply by a constant
times_n(v0, v1, n) = Float32(v0+(v1*n))
normalize_positionf0(mouse, window) = Vec2f0(mouse) ./ Vec2f0(window.w, window.h)
is_leftclicked_without_keyboard(mb, kb) = in(0, mb) && isempty(kb)
#=
Creates an orthographic camera from a dict of signals
Signals needed:
[
:window_size                    => Signal(Vec{2, Int}),
:buttonspressed                    => Signal(Int[]),
:mousebuttonspressed            => Signal(Int[]),
:mouseposition                    => mouseposition, -> Panning
:scroll_y                        => Signal(0) -> Zoomig
]
=#
function OrthographicCamera(inputs::Dict{Symbol, Any})
    @materialize mouseposition, mousebuttonspressed, buttonspressed, window_size = inputs

    zoom                 = foldp(times_n , 1.0f0, inputs[:scroll_y], Signal(0.1f0)) # add up and multiply by 0.1f0
    #Should be rather in Image coordinates
    normedposition         = const_lift(normalize_positionf0, inputs[:mouseposition], inputs[:window_size])
    clickedwithoutkeyL     = const_lift(is_leftclicked_without_keyboard, mousebuttonspressed, buttonspressed)

    # Note 1: Don't do unnecessary updates, so just signal when mouse is actually clicked
    # Note 2: Get the difference, starting when the mouse is down
    mouse_diff             = filterwhen(clickedwithoutkeyL, (false, Vec2f0(0.0f0), Vec2f0(0.0f0)),  ## (Note 1)
    foldp(mousediff, (false, Vec2f0(0.0f0), Vec2f0(0.0f0)), ## (Note 2)
    clickedwithoutkeyL, normedposition))
    translate             = const_lift(getindex, mouse_diff, Signal(3))  # Extract the mouseposition from the diff tuple

    OrthographicCamera(
    window_size,
    zoom,
    translate,
    normedposition
    )
end
#=
Creates an orthographic camera from signals, controlling the camera
Args:

window_size: Size of the window
zoom: Zoom
translatevec: Panning
normedposition: Pivot for translations
=#
function OrthographicCamera{T}(
    windows_size ::Signal{SimpleRectangle{Int}},
    view         ::Signal{Mat{4,4,T}},
    nearclip     ::Signal{T},
    farclip      ::Signal{T}
    )

    projection = const_lift(orthographicprojection, windows_size, nearclip, farclip)
    #projection = Signal(eye(Mat4))
    #view = Signal(eye(Mat4))
    projectionview = const_lift(*, projection, view)

    OrthographicCamera{T}(
        windows_size,
        view,
        projection,
        projectionview
    )
end



#=
Creates an orthographic camera from signals, controlling the camera
Args:

window_size: Size of the window
zoom: Zoom
translatevec: Panning
normedposition: Pivot for translations

=#
function OrthographicCamera{T}(
        windows_size     ::Signal{SimpleRectangle{Int}},
        zoom             ::Signal{T},
        translatevec     ::Signal{Vec{2, T}},
        normedposition   ::Signal{Vec{2, T}}
    )

    projection = const_lift(windows_size) do wh
        w,h = width(wh), height(wh)
        if w < 1 || h < 1
            return eye(Mat{4,4,T})
        end
        # change the aspect ratio, to always display an image with the right dimensions
        # this behaviour should definitely be changed, as soon as the camera is used for anything else.
        wh = w > h ? ((w/h), 1f0) : (1f0,(h/w))
        orthographicprojection(zero(T), T(wh[1]), zero(T), T(wh[2]), -one(T), T(10))
    end

    scale             = const_lift(x -> scalematrix(Vec{3, T}(x, x, one(T))), zoom)
    transaccum        = foldp(+, Vec{2,T}(0), translatevec)
    translate         = const_lift(x-> translationmatrix(Vec{3,T}(x, zero(T))), transaccum)

    view = const_lift(scale, translate) do s, t
        pivot = Vec(normedposition.value..., zero(T))
        translationmatrix(pivot)*s*translationmatrix(-pivot)*t
    end


    projectionview = const_lift(*, projection, view)

    OrthographicCamera{T}(
        windows_size,
        projection,
        view,
        projectionview
    )
end

mousepressed(mousebuttons::Vector{Int}, button::Int) = in(button, mousebuttons)

thetalift(mdL, speed) = Vec3f0(0f0, -mdL[2]/speed, mdL[1]/speed)
translationlift(scroll_y, mdM) = Vec3f0(scroll_y, mdM[1]/200f0, -mdM[2]/200f0)

function default_camera_control(inputs, T = Float32; trans=Signal(Vec3f0(0)), theta=Signal(Vec3f0(0)), filtersignal=Signal(true))
    @materialize mouseposition, mousebuttonspressed, scroll_y = inputs

    mouseposition       = const_lift(Vec{2, T}, mouseposition)
    clickedkeyL         = const_lift(GLAbstraction.mousepressed, mousebuttonspressed, Signal(0))
    clickedkeyM         = const_lift(GLAbstraction.mousepressed, mousebuttonspressed, Signal(2))
    mousedraggdiffL     = const_lift(last, foldp(GLAbstraction.mousediff, (false, Vec2f0(0.0f0), Vec2f0(0.0f0)), clickedkeyL, mouseposition));
    mousedraggdiffM     = const_lift(last, foldp(GLAbstraction.mousediff, (false, Vec2f0(0.0f0), Vec2f0(0.0f0)), clickedkeyM, mouseposition));

    zoom         = filterwhen(filtersignal, 0f0, const_lift(Float32, const_lift(/, scroll_y, 5f0)))
    _theta       = filterwhen(filtersignal, Vec3f0(0), merge(const_lift(GLAbstraction.thetalift, mousedraggdiffL, 50f0), theta))
    _trans       = filterwhen(filtersignal, Vec3f0(0), merge(const_lift(GLAbstraction.translationlift, zoom, mousedraggdiffM), trans))
    _theta, _trans, zoom
end
#=
Creates a perspective camera from a dict of signals
Args:

inputs: Dict of signals, looking like this:
[
:window_size                    => Signal(Vec{2, Int}),
:buttonspressed                    => Signal(Int[]),
:mousebuttonspressed            => Signal(Int[]),
:mouseposition                   => mouseposition, -> Panning + Rotation
:scroll_y                        => Signal(0) -> Zoomig
]
eyeposition: Position of the camera
lookatvec: Point the camera looks at
=#
function PerspectiveCamera{T}(inputs::Dict{Symbol,Any}, eyeposition::Vec{3, T}, lookatvec::Vec{3, T})
    theta,trans,zoom = default_camera_control(inputs, T)

    cam = PerspectiveCamera(
        inputs[:window_size],
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

@enum Projection PERSPECTIVE ORTHOGRAPHIC
getupvec(p::Pivot) = p.rotation * p.zaxis

function projection_switch(w::SimpleRectangle, fov::Number, near::Number, far::Number, projection::Projection, zoom::Number)
    projection == PERSPECTIVE && return perspectiveprojection(w, fov, near, far)
    zoom   = Float32(zoom/2f0)
    aspect = Float32((w.w/w.h)*zoom)
    orthographicprojection(-zoom, aspect, -zoom, zoom, near, far) # can only be orthographic...
end

#=
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

=#
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
    positionvec     = const_lift(*, modelmatrix, Signal(Vec(eyeposition, one(T))))
    positionvec     = const_lift(Vec{3,T}, positionvec)

    up              = const_lift(getupvec, pivot)
    lookatvec1      = const_lift(getfield, pivot, :origin) # silly way of geting a field

    view            = const_lift(lookat, positionvec, lookatvec1, up)
    zoom            = foldp(+, 1f0, zoom)
    pmatrix      	= const_lift(projection_switch, window_size, fov, nearclip, farclip, projection, zoom)

    projectionview  = const_lift(*, pmatrix, view)

    PerspectiveCamera{T}(
        pivot,
        window_size,
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
