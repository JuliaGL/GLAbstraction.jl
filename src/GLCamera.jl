abstract Camera{T}

type OrthographicCamera{T} <: Camera{T}
    window_size     ::Signal{Rectangle{Int}}
    view            ::Signal{Mat{4,4,T}}
    projection      ::Signal{Mat{4,4,T}}
    projectionview  ::Signal{Mat{4,4,T}}
end
type PerspectiveCamera{T} <: Camera{T}
    pivot           ::Signal{Pivot{T}}
    window_size     ::Signal{Rectangle{Int}}
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
    window_size     ::Signal{Rectangle{Int}}
    view            ::Signal{Mat{4,4,T}}
    projection      ::Signal{Mat{4,4,T}}
    projectionview  ::Signal{Mat{4,4,T}}
end

function DummyCamera(;
        window_size    = Input(Rectangle(-1, -1, 1, 1)),
        view           = Input(eye(Mat{4,4, Float32})),
        nearclip       = Input(10000f0),
        farclip        = Input(-10000f0),
        projection     = lift(orthographicprojection, window_size, nearclip, farclip),
        projectionview = lift(*, projection, view)
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
            translatevec = Vec3f0(scroll_y*10f0, 0f0, 0f0)
        else
            translatevec = Vec3f0(0f0, scroll_y*10f0, 0f0)
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
:window_size                    => Input(Rectangle{Int}),
:buttonspressed                    => Input(Int[]),
:mousebuttonspressed            => Input(Int[]),
:mouseposition                    => mouseposition, -> Panning
:scroll_y                        => Input(0) -> Zoomig
]
=#
function OrthographicPixelCamera(inputs::Dict{Symbol, Any})
    @materialize mouseposition, buttonspressed = inputs
    #Should be rather in Image coordinates
    view = foldl(viewmatrix, eye(Mat{4,4, Float32}), inputs[:scroll_x], inputs[:scroll_y], buttonspressed)
    OrthographicCamera(
        inputs[:window_size],
        view,
        Input(-10f0), # nearclip
        Input(10f0) # farclip
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
:window_size                    => Input(Vec{2, Int}),
:buttonspressed                    => Input(Int[]),
:mousebuttonspressed            => Input(Int[]),
:mouseposition                    => mouseposition, -> Panning
:scroll_y                        => Input(0) -> Zoomig
]
=#
function OrthographicCamera(inputs::Dict{Symbol, Any})
    @materialize mouseposition, mousebuttonspressed, buttonspressed, window_size = inputs

    zoom                 = foldl(times_n , 1.0f0, inputs[:scroll_y], Input(0.1f0)) # add up and multiply by 0.1f0
    #Should be rather in Image coordinates
    normedposition         = lift(normalize_positionf0, inputs[:mouseposition], inputs[:window_size])
    clickedwithoutkeyL     = lift(is_leftclicked_without_keyboard, mousebuttonspressed, buttonspressed)

    # Note 1: Don't do unnecessary updates, so just signal when mouse is actually clicked
    # Note 2: Get the difference, starting when the mouse is down
    mouse_diff             = keepwhen(clickedwithoutkeyL, (false, Vec2f0(0.0f0), Vec2f0(0.0f0)),  ## (Note 1)
    foldl(mousediff, (false, Vec2f0(0.0f0), Vec2f0(0.0f0)), ## (Note 2)
    clickedwithoutkeyL, normedposition))
    translate             = lift(getindex, mouse_diff, Input(3))  # Extract the mouseposition from the diff tuple

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
    windows_size ::Signal{Rectangle{Int}},
    view         ::Signal{Mat{4,4,T}},
    nearclip     ::Signal{T},
    farclip      ::Signal{T}
    )

    projection = lift(orthographicprojection, windows_size, nearclip, farclip)
    #projection = Input(eye(Mat4))
    #view = Input(eye(Mat4))
    projectionview = lift(*, projection, view)

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
        windows_size     ::Signal{Rectangle{Int}},
        zoom             ::Signal{T},
        translatevec     ::Signal{Vec{2, T}},
        normedposition   ::Signal{Vec{2, T}}
    )

    projection = lift(windows_size) do wh
        w,h = width(wh), height(wh)
        if w < 1 || h < 1
            return eye(Mat{4,4,T})
        end
        # change the aspect ratio, to always display an image with the right dimensions
        # this behaviour should definitely be changed, as soon as the camera is used for anything else.
        wh = w > h ? ((w/h), 1f0) : (1f0,(h/w))
        orthographicprojection(zero(T), T(wh[1]), zero(T), T(wh[2]), -one(T), T(10))
    end

    scale             = lift(x -> scalematrix(Vec{3, T}(x, x, one(T))), zoom)
    transaccum        = foldl(+, Vec{2,T}(0), translatevec)
    translate         = lift(x-> translationmatrix(Vec{3,T}(x, zero(T))), transaccum)

    view = lift(scale, translate) do s, t
        pivot = Vec(normedposition.value..., zero(T))
        translationmatrix(pivot)*s*translationmatrix(-pivot)*t
    end


    projectionview = lift(*, projection, view)

    OrthographicCamera{T}(
        windows_size,
        projection,
        view,
        projectionview
    )
end

mousepressed_without_keyboard(mousebuttons::Vector{Int}, button::Int, keyboard::Vector{Int}) =
    in(button, mousebuttons) && isempty(keyboard)

thetalift(mdL, speed) = Vec3f0(0f0, -mdL[2]/speed, mdL[1]/speed)
translationlift(scroll_y, mdM) = Vec3f0(scroll_y, mdM[1]/200f0, -mdM[2]/200f0)

function default_camera_control(inputs, T = Float32; trans=Input(Vec3f0(0)), theta=Input(Vec3f0(0)))
    @materialize mouseposition, mousebuttonspressed, buttonspressed, scroll_y = inputs
    
    mouseposition       = lift(Vec{2, T}, mouseposition);
    clickedwithoutkeyL  = lift(GLAbstraction.mousepressed_without_keyboard, mousebuttonspressed, Input(0), buttonspressed)
    clickedwithoutkeyM  = lift(GLAbstraction.mousepressed_without_keyboard, mousebuttonspressed, Input(2), buttonspressed)
    mousedraggdiffL     = lift(last, foldl(GLAbstraction.mousediff, (false, Vec2f0(0.0f0), Vec2f0(0.0f0)), clickedwithoutkeyL, mouseposition));
    mousedraggdiffM     = lift(last, foldl(GLAbstraction.mousediff, (false, Vec2f0(0.0f0), Vec2f0(0.0f0)), clickedwithoutkeyM, mouseposition));

    zoom        = lift(Float32, lift(/, scroll_y, 5f0))
    _theta       = merge(lift(GLAbstraction.thetalift, mousedraggdiffL, 50f0), theta)
    _trans       = merge(lift(GLAbstraction.translationlift, zoom, mousedraggdiffM), trans)
    _theta, _trans, zoom
end
#=
Creates a perspective camera from a dict of signals
Args:

inputs: Dict of signals, looking like this:
[
:window_size                    => Input(Vec{2, Int}),
:buttonspressed                    => Input(Int[]),
:mousebuttonspressed            => Input(Int[]),
:mouseposition                   => mouseposition, -> Panning + Rotation
:scroll_y                        => Input(0) -> Zoomig
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
        Input(41f0),
        Input(1f0),
        Input(100f0)
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

function projection_switch(w::Rectangle, fov::Number, near::Number, far::Number, projection::Projection, zoom::Number)
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
        window_size     ::Signal{Rectangle{Int}},
        eyeposition     ::Vec{3, T},
        lookatvec       ::Union{Signal{Vec{3, T}}, Vec{3, T}},
        theta           ::Signal{Vec{3, T}},
        trans           ::Signal{Vec{3, T}},
        zoom            ::Signal{T},
        fov             ::Signal{T},
        nearclip        ::Signal{T},
        farclip         ::Signal{T},
        projection 	= Input(PERSPECTIVE),
        reset   	= Input(false),
        resetto 	= Input(Quaternions.Quaternion(T(1),T(0),T(0),T(0)))
    )

    origin          = lookatvec
    vup             = Vec{3, T}(0,0,1)
    xaxis           = lift(-, eyeposition, lookatvec)
    yaxis           = lift(cross, xaxis, vup)
    zaxis           = lift(cross, yaxis, xaxis)

    pivot0          = Pivot(value(lookatvec), value(xaxis), value(yaxis), value(zaxis), Quaternions.Quaternion(T(1),T(0),T(0),T(0)), zero(Vec{3, T}), Vec{3, T}(1))
    pivot           = foldl(update_pivot, pivot0, lift(tuple, theta, trans, reset, resetto))

    modelmatrix     = lift(transformationmatrix, pivot)
    positionvec     = lift(*, modelmatrix, Input(Vec(eyeposition, one(T))))
    positionvec     = lift(Vec{3,T}, positionvec)

    up              = lift(getupvec, pivot)
    lookatvec1      = lift(getfield, pivot, :origin) # silly way of geting a field

    view            = lift(lookat, positionvec, lookatvec1, up)
    zoom            = foldl(+, 1f0, zoom)
    pmatrix      	= lift(projection_switch, window_size, fov, nearclip, farclip, projection, zoom)

    projectionview  = lift(*, pmatrix, view)

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
