abstract Camera{T}
type OrthographicCamera{T} <: Camera{T}
	window_size::Signal{Vector4{Int}}
	view::Signal{Matrix4x4{T}}
	projection::Signal{Matrix4x4{T}}
	projectionview::Signal{Matrix4x4{T}}
end
type PerspectiveCamera{T} <: Camera{T}
	pivot::Signal{Pivot{T}}
	window_size::Signal{Vector4{Int}}
	nearclip::Signal{T}
  	farclip::Signal{T}
  	fov::Signal{T}
	view::Signal{Matrix4x4{T}}
	projection::Signal{Matrix4x4{T}}
	projectionview::Signal{Matrix4x4{T}}
	eyeposition::Signal{Vector3{T}}
	lookat::Signal{Vector3{T}}
	up::Signal{Vector3{T}}
end



function mousediff{T}(v0::@compat(Tuple{Bool, Vector2{T}, Vector2{T}}),  clicked::Bool, pos::Vector2{T})
    clicked0, pos0, pos0diff = v0
    if clicked0 && clicked
        return (clicked, pos, pos - pos0)
    end
    return (clicked, pos, Vector2(0.0))
end
function viewmatrix(v0, scroll_x, scroll_y, buttonset)
	translatevec = Vec3(0f0)
	if scroll_x == 0f0
		if in(341, buttonset) # left strg
			translatevec = Vec3(scroll_y*10f0, 0f0, 0f0)
		else
			translatevec = Vec3(0f0, scroll_y*10f0, 0f0)
		end
	else
		translatevec = Vec3(scroll_x*10f0, scroll_y*10f0, 0f0)
	end
	v0 * translationmatrix(translatevec)	
end

#= 
Creates an orthographic camera with the pixel perfect plane in z == 0
Signals needed:
[
	:window_size					=> Input(Vector2{Int}),
	:buttonspressed					=> Input(IntSet()),
	:mousebuttonspressed			=> Input(IntSet()), 
	:mouseposition					=> mouseposition, -> Panning
	:scroll_y						=> Input(0) -> Zoomig
]
=#
function OrthographicPixelCamera(inputs::Dict{Symbol, Any})

	mouseposition   = inputs[:mouseposition]
	buttonspressed  = inputs[:buttonspressed]
	
	#Should be rather in Image coordinates
	view = foldl(viewmatrix, eye(Mat4), inputs[:scroll_x], inputs[:scroll_y], buttonspressed)

	OrthographicCamera(
				inputs[:window_size],
				view,
				Input(-10f0), # nearclip
				Input(10f0) # farclip
			)

end

times_n(v0, v1, n) = Float32(v0+(v1*n))
#= 
Creates an orthographic camera from a dict of signals
Signals needed:
[
	:window_size					=> Input(Vector2{Int}),
	:buttonspressed					=> Input(IntSet()),
	:mousebuttonspressed			=> Input(IntSet()), 
	:mouseposition					=> mouseposition, -> Panning
	:scroll_y						=> Input(0) -> Zoomig
]
=#
function OrthographicCamera(inputs::Dict{Symbol, Any})

	mouseposition   = inputs[:mouseposition]
	clicked         = inputs[:mousebuttonspressed]
	keypressed      = inputs[:buttonspressed]
	
	zoom 			= foldl(times_n , 1.0f0, inputs[:scroll_y], Input(0.1f0)) # add up and multiply by 0.1f0

	#Should be rather in Image coordinates
	normedposition 		= lift((a,b) -> Vector2((a./b[3:4])...), inputs[:mouseposition], inputs[:window_size])
	clickedwithoutkeyL 	= lift((mb, kb) -> in(0, mb) && isempty(kb), Bool, clicked, keypressed)
	mouse_diff 			= keepwhen(clickedwithoutkeyL, (false, Vector2(0.0), Vector2(0.0)), # Don't do unnecessary updates, so just signal when mouse is actually clicked
								foldl(mousediff, (false, Vector2(0.0), Vector2(0.0)),  # Get the difference, starting when the mouse is down
									clickedwithoutkeyL, normedposition))
	translate 			= lift(getindex, Vec2, mouse_diff, Input(3))# Extract the mouseposition from the diff tuple
							
	OrthographicCamera(
				inputs[:window_size],
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
									windows_size::Signal{Vector4{Int}},
									view::Signal{Matrix4x4{T}},
									
									nearclip::Signal{T},
									farclip::Signal{T}
								)

	projection = lift(orthographicprojection, windows_size, nearclip, farclip) 
	#projection = Input(eye(Mat4))
	#view = Input(eye(Mat4))
	projectionview = lift(*, Matrix4x4{T}, projection, view)

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
									windows_size::Signal{Vector4{Int}},
									zoom::Signal{T},
									translatevec::Signal{Vector2{T}},
									normedposition::Signal{Vector2{Float64}}
								)

	projection = lift(Matrix4x4{T}, windows_size) do wh
	  if wh[3] < 1 || wh[4] < 1
	  	return eye(Matrix4x4{T})
	  end
	  # change the aspect ratio, to always display an image with the right dimensions
	  # this behaviour should definitely be changed, as soon as the camera is used for anything else.
	  wh = wh[3] > wh[4] ? ((wh[3]/wh[4]), 1f0) : (1f0,(wh[4]/wh[3]))
	  orthographicprojection(0f0, convert(T, wh[1]), 0f0, convert(T, wh[2]), -1f0, 10f0)
	end

	scale             = lift(x -> scalematrix(Vector3{T}(x, x, one(T))), zoom)
	transaccum 		  = foldl(+, Vector2(zero(T)), translatevec)
	translate         = lift(x-> translationmatrix(Vector3(x..., zero(T))), transaccum)

	view = lift((s, t) -> begin
	  pivot = Vec3(normedposition.value..., zero(T))
	  translationmatrix(pivot)*s*translationmatrix(-pivot)*t
	end, Matrix4x4{T}, scale, translate)

	projectionview = lift(*, Matrix4x4{T}, projection, view)

	OrthographicCamera{T}(
							windows_size,
							projection,
							view,
							projectionview
						)

end

mousepressed_without_keyboard(mousebuttons::IntSet, button::Int, keyboard::IntSet) = 
	in(button, mousebuttons) && isempty(keyboard)

isnotempty(A) = !isempty(A)
#= 
Creates a perspective camera from a dict of signals
Args:

      inputs: Dict of signals, looking like this:
			[
				:window_size					=> Input(Vector2{Int}),
				:buttonspressed					=> Input(IntSet()),
				:mousebuttonspressed			=> Input(IntSet()), 
				:mouseposition					=> mouseposition, -> Panning + Rotation
				:scroll_y						=> Input(0) -> Zoomig
			]
  eyeposition: Position of the camera
	lookatvec: Point the camera looks at
=#
function PerspectiveCamera{T}(inputs::Dict{Symbol,Any}, eyeposition::Vector3{T}, lookatvec::Vector3{T})

	mouseposition   	= inputs[:mouseposition]
	clicked         	= inputs[:mousebuttonspressed]
	keypressed      	= inputs[:buttonspressed]

	clickedwithoutkeyL 	= lift(mousepressed_without_keyboard, clicked, Input(0), keypressed)
	clickedwithoutkeyM 	= lift(mousepressed_without_keyboard, clicked, Input(2), keypressed)

	nokeydown 			= lift(isempty,  keypressed)
	anymousedown 		= lift(isnotempty,  clicked)

	mousedraggdiffL = lift(last, foldl(mousediff, (false, Vector2(0.0f0), Vector2(0.0f0)), clickedwithoutkeyL, mouseposition))
	mousedraggdiffM = lift(last, foldl(mousediff, (false, Vector2(0.0f0), Vector2(0.0f0)), clickedwithoutkeyM, mouseposition))

	speed  = Input(50f0)
	xtheta = Input(0f0)
	ytheta = lift(-, lift(/, lift(last,  mousedraggdiffL), speed)) # uugly
	ztheta = lift(/, lift(first,  mousedraggdiffL), speed)


	xtrans = lift(Float32 ,lift(*,  inputs[:scroll_y], Input(0.1f0)))

	ytrans = lift(-, lift(/, lift(first,  mousedraggdiffM), speed)) #-(mouse.x / speed)
	ztrans = lift(/, lift(last, mousedraggdiffM), speed) # (mouse.x / speed)

	fov 	= Input(41f0)

	cam = PerspectiveCamera(
					inputs[:window_size],
					
					eyeposition,
					lookatvec,
					
					xtheta,
					ytheta,
					ztheta,
					
					xtrans,
					ytrans,
					ztrans,
					
					Input(41f0),
					Input(1f0),
					Input(100f0)
	)
end


function fold_pivot(v0, v1)
	xt, yt, zt, xtr, ytr, ztr = v1

	xaxis = v0.rotation * v0.xaxis # rotate the axis
	yaxis = v0.rotation * v0.yaxis
	zaxis = v0.rotation * v0.zaxis

	xrot = qrotation(xaxis, xt)
	yrot = qrotation(yaxis, yt)
	zrot = qrotation(Vector3(0f0,0f0,1f0), zt)

	v1rot = zrot*xrot*yrot*v0.rotation

	v1trans 	= yaxis*ytr + zaxis*ztr 
	accumtrans 	= v1trans + v0.translation

	Pivot(v0.origin + v1trans, v0.xaxis, v0.yaxis, v0.zaxis, v1rot, accumtrans + v0.xaxis*xtr, v0.scale)
end

getupvec(p::Pivot) = p.rotation * p.zaxis
vec3(v::Vector4) = Vector3(v[1], v[2], v[3])
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
					window_size::Signal{Vector4{Int}},# = iVec2(50,50),
					
					eyeposition::Vector3{T},
					lookatvec::Vector3{T},
					xtheta::Signal{T},
					ytheta::Signal{T},
					ztheta::Signal{T},

					xtrans::Signal{T},
					ytrans::Signal{T},
					ztrans::Signal{T},

					fov::Signal{T},
					
					nearclip::Signal{T},
					farclip::Signal{T}
	)
	eyepositionstart 	= Vector3{T}(1,0,0)
	origin 				= lookatvec
	vup 				= Vector3{T}(0,0,1)
	xaxis 				= eyeposition - origin
	yaxis 				= cross(xaxis, vup)
	zaxis 				= cross(yaxis, xaxis)

	translate 			= Vector3{T}(0,0,0)

	p0 				= Pivot(origin, xaxis, yaxis, zaxis, Quaternion(1f0,0f0,0f0,0f0), translate, Vector3{T}(1))
	pivot 			= foldl(fold_pivot, p0, lift(tuple, xtheta, ytheta, ztheta, xtrans, ytrans, ztrans))

	modelmatrix 	= lift(transformationmatrix, pivot)
	positionvec 	= lift(*, modelmatrix, Input(Vector4(eyeposition..., one(T))))
	positionvec 	= lift(vec3,  positionvec)

	up 				= lift(getupvec, pivot)
	lookatvec1 		= lift(getfield, pivot, Input(:origin)) # silly way of geting a field

	view 			= lift(lookat,  positionvec, lookatvec1, up)
	w 				= lift(getindex, window_size, Input(3))
	h 				= lift(last, window_size)
	window_ratio 	= lift(/, T, w, h)
	projection 		= lift(perspectiveprojection, fov, window_ratio, nearclip, farclip)

	projectionview 	= lift(*,  projection, view)


	return PerspectiveCamera{T}(
			pivot,
			window_size,
			nearclip,
			farclip,
			fov,
			view,
			projection,
			projectionview,
			positionvec,
			lookatvec1,
			up
		)
end


