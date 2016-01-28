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
    speed = 30f0
    translatevec = Vec3f0(0f0)
    scroll_x, scroll_y = Vec2f0(scroll_xy)*speed
    if scroll_x == 0f0
        if in(341, buttonset) # left strg key
            translatevec = Vec3f0(scroll_y, 0f0, 0f0)
        else
            translatevec = Vec3f0(0f0, scroll_y, 0f0)
        end
    else
        translatevec = Vec3f0(scroll_x, scroll_y, 0f0)
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
    view = foldp(viewmatrix, eye(Mat4f0), inputs[:scroll], buttons_pressed)
    OrthographicCamera(
        inputs[:window_area],
        view,
        Signal(-100f0), # nearclip
        Signal(100f0) # farclip
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


pressed(keys, key) = key in keys
singlepressed(keys, key) = length(keys) == 1 && first(keys) == key

mouse_dragg(v0, args) = mouse_dragg(v0..., args...)
function mouse_dragg(
        started::Bool, startpoint, diff,
        ispressed::Bool, position, start_condition::Bool
    )
    if !started && ispressed && start_condition
        return (true, position, Vec2f0(0))
    end
    started && ispressed && return (true, startpoint, position-startpoint)
    (false, Vec2f0(0), Vec2f0(0))
end
mouse_dragg_diff(v0, args) = mouse_dragg_diff(v0..., args...)
function mouse_dragg_diff(
        started::Bool, position0, diff,
        ispressed::Bool, position, start_condition::Bool
    )
    if !started && ispressed && start_condition
        return (true, position, Vec2f0(0))
    end
    started && ispressed && return (true, position, position0-position)
    (false, Vec2f0(0), Vec2f0(0))
end

function dragged(mouseposition, key_pressed, start_condition=true)
    v0 = (false, Vec2f0(0), Vec2f0(0))
    args = const_lift(tuple, key_pressed, mouseposition, start_condition)
    dragg_sig = foldp(mouse_dragg, v0, args)
    is_dragg = map(first, dragg_sig)
    dragg_diff = map(last, dragg_sig)
    dragg_diff
end
function dragged_diff(mouseposition, key_pressed, start_condition=true)
    v0 = (false, Vec2f0(0), Vec2f0(0))
    args = const_lift(tuple, key_pressed, mouseposition, start_condition)
    dragg_sig = foldp(mouse_dragg_diff, v0, args)
    is_dragg = map(first, dragg_sig)
    dragg_diff = map(last, dragg_sig)
    dragg_diff
end
#=
function dragged(mouseposition, key_pressed, start_condition=true)
    v0 = (false, Vec2f0(0), Vec2f0(0), value(start_condition))
    args = const_lift(tuple, key_pressed, mouseposition, start_condition)
    dragg_sig = foldp(mouse_dragg, v0, args)
    println(dragg_sig)
    is_dragg = map(first, dragg_sig)
    dragg_diff = map(last, dragg_sig)
    println(is_dragg)
    println(dragg_diff)
    filterwhen(is_dragg, Vec2f0(0), dragg_diff)
end
=#





"""
Transforms a mouse drag into a selection from drag start to drag end
"""
function drag2selectionrange(v0, selection)
    mousediff, id_start, current_id = selection
    if mousediff != Vec2f0(0) # Mouse Moved
        if current_id[1] == id_start[1]
            return min(id_start[2],current_id[2]):max(id_start[2],current_id[2])
        end
    else # if mouse did not move while dragging, make a single point selection
        if current_id.id == id_start.id
            return current_id.index:0 # this is the type stable way of indicating, that the selection is between currend_index
        end
    end
    v0
end


"""
Returns two signals, one boolean signal if clicked over `robj` and another
one that consists of the object clicked on and another argument indicating that it's the first click
"""
function clicked(robj::RenderObject, button::MouseButton, window)
    @materialize mouse_hover, mousebuttonspressed = window.inputs
    clicked_on = const_lift(mouse_hover, mousebuttonspressed) do mh, mbp
        mh.id == robj.id && in(button, mbp)
    end
    clicked_on_obj = keepwhen(clicked_on, false, clicked_on)
    clicked_on_obj = const_lift((mh, x)->(x,robj,mh), mouse_hover, clicked_on)
    clicked_on, clicked_on_obj
end
export is_same_id
is_same_id(id_index, robj) = id_index.id == robj.id
"""
Returns a boolean signal indicating if the mouse hovers over `robj`
"""
is_hovering(robj::RenderObject, window) =
    droprepeats(const_lift(is_same_id, window.inputs[:mouse_hover], robj))

function dragon_tmp(past, mh, mbp, mpos, robj, button, start_value)
    diff, dragstart_index, was_clicked, dragstart_pos = past
    over_obj = mh[1] == robj.id
    is_clicked = mbp == Int[button]
    if is_clicked && was_clicked # is draggin'
        return (dragstart_pos-mpos, dragstart_index, true, dragstart_pos)
    elseif over_obj && is_clicked && !was_clicked # drag started
        return (Vec2f0(0), mh[2], true, mpos)
    end
    return start_value
end

"""
Returns a signal with the difference from dragstart and current mouse position,
and the index from the current ROBJ id.
"""
function dragged_on(robj::RenderObject, button::MouseButton, window)
    @materialize mouse_hover, mousebuttonspressed, mouseposition = window.inputs
    start_value = (Vec2f0(0), mouse_hover.value[2], false, Vec2f0(0))
    tmp_signal = foldp(dragon_tmp,
        start_value, mouse_hover,
        mousebuttonspressed, mouseposition,
        Signal(robj), Signal(button), Signal(start_value)
    )
    droprepeats(const_lift(getindex, tmp_signal, 1:2))
end


"""
returns a signal which becomes true whenever there is a doublecklick
"""
function doubleclick(mouseclick, threshold::Real)
    ddclick = foldp((time(), value(mouseclick), false), mouseclick) do v0, mclicked
        t0, lastc, _ = v0
        t1 = time()
        isclicked = (length(mclicked) == 1 &&
            length(lastc) == 1 &&
            first(lastc) == first(mclicked) &&
            t1-t0 < threshold
        )
        return (t1, mclicked, isclicked)
    end
    dd = const_lift(last, ddclick)
    return dd
end

export doubleclick

function default_camera_control(
        inputs, rotation_speed, translation_speed, keep=Signal(true)
    )
    @materialize mouseposition, mouse_buttons_pressed, scroll = inputs

    mouseposition = map(Vec2f0, mouseposition)
    left_pressed  = const_lift(pressed, mouse_buttons_pressed, GLFW.MOUSE_BUTTON_LEFT)
    right_pressed = const_lift(pressed, mouse_buttons_pressed, GLFW.MOUSE_BUTTON_RIGHT)
    xytheta       = dragged_diff(mouseposition, left_pressed, keep)
    xytranslate   = dragged_diff(mouseposition, right_pressed, keep)

    ztranslate    = filterwhen(keep, 0f0,
        const_lift(*, map(last, scroll), 150f0)
    )
    translate_theta(
        xytranslate, ztranslate, xytheta,
        rotation_speed, translation_speed
    )
end

function thetalift(yz, speed)
    Vec3f0(0f0, yz[2], yz[1]).*speed
end
function translationlift(up_left, zoom, speed)
    Vec3f0(zoom, -up_left[1], up_left[2]).*speed
end
function diff_vector(v0, p1)
    p0, diff = v0
    p1, p0-p1
end
function translate_theta(
        xytranslate, ztranslate, xytheta,
        rotation_speed, translation_speed
    )
    theta = map(thetalift, xytheta, rotation_speed)
    trans = map(translationlift, xytranslate, ztranslate, translation_speed)
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
    theta, trans = default_camera_control(inputs, Signal(0.01f0), Signal(0.005f0))

    cam = PerspectiveCamera(
        inputs[:window_area],
        eyeposition,
        lookatvec,
        theta,
        trans,
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
        wh::SimpleRectangle,
        fov::T, near::T, far::T,
        projection::Projection, zoom::T
    )
    aspect = T(wh.w/wh.h)
    h      = T(tan(fov / 360.0 * pi) * near)
    w      = T(h * aspect)
    projection == PERSPECTIVE && return frustum(-w, w, -h, h, near, far)
    h      = T(tan(fov / 360.0 * pi) * near)*zoom
    w      = T(h * aspect)
    orthographicprojection(-w, w, -h, h, near, far)
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
        fov             ::Signal{T},
        nearclip        ::Signal{T},
        farclip         ::Signal{T},

        up_vector   = Vec{3, T}(0,0,1),
        projection 	= Signal(PERSPECTIVE),
        reset   	= Signal(false),
        resetto 	= Signal(Quaternions.Quaternion(T(1),T(0),T(0),T(0)))
    )

    xaxis           = const_lift(-, eyeposition, lookatvec)
    yaxis           = const_lift(cross, xaxis, up_vector)
    zaxis           = const_lift(cross, yaxis, xaxis)

    pivot0          = Pivot(
        value(lookatvec), value(xaxis), value(yaxis), value(zaxis),
        Quaternions.Quaternion(T(1),T(0),T(0),T(0)), zero(Vec{3, T}), Vec{3, T}(1)
    )
    pivot           = foldp(update_pivot, pivot0, const_lift(tuple, theta, trans, reset, resetto))

    modelmatrix     = const_lift(transformationmatrix, pivot)
    positionvec     = const_lift(*, modelmatrix, Vec(eyeposition, one(T)))
    positionvec     = const_lift(Vec{3,T}, positionvec)

    up              = const_lift(getupvec, pivot)
    lookatvec1      = const_lift(origin, pivot)
    zoomlen         = const_lift(norm, const_lift(-, lookatvec1, positionvec))

    view            = const_lift(lookat, positionvec, lookatvec1, up)
    pmatrix      	= const_lift(projection_switch,
        window_size, fov, nearclip,
        farclip, projection, zoomlen
    )

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
