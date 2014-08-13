export OrthographicCamera, PerspectiveCamera

immutable OrthographicCamera{T}
	window_size::Signal{Vector2{Int}}
	view::Signal{Matrix4x4{T}}
	projection::Signal{Matrix4x4{T}}
	projectionview::Signal{Matrix4x4{T}}
end
immutable PerspectiveCamera{T}
	pivot::Signal{Pivot{T}}
	window_size::Signal{Vector2{Int}}
	nearclip::Signal{T}
  	farclip::Signal{T}
  	fov::Signal{T}
	view::Signal{Matrix4x4{T}}
	projection::Signal{Matrix4x4{T}}
	projectionview::Signal{Matrix4x4{T}}
	normalmatrix::Signal{Matrix3x3{T}}
	eyeposition::Signal{Vector3{T}}
	lookat::Signal{Vector3{T}}
	up::Signal{Vector3{T}}
end

function mousediff(v0::(Bool, Vector2{Float64}, Vector2{Float64}),  clicked::Bool, pos::Vector2{Float64})
    clicked0, pos0, pos0diff = v0
    if clicked0 && clicked
        return (clicked, pos, pos - pos0)
    end
    return (clicked, pos, Vector2(0.0))
end


function OrthographicCamera(inputs)

	mouseposition   = inputs[:mouseposition]
	clicked         = inputs[:mousebuttonspressed]
	keypressed      = inputs[:buttonspressed]
	
	zoom 			= foldl((a,b) -> float32(a+(b*0.1f0)) , 1.0f0, inputs[:scroll_y])

	#Should be rather in Image coordinates
	normedposition 		= lift(./, inputs[:mouseposition], inputs[:window_size])
	clickedwithoutkeyL 	= lift((mb, kb) -> in(0, mb) && isempty(kb), Bool, clicked, keypressed)
	translate 			= lift(x-> float32(x[3]), Vec2, # Extract the mouseposition from the diff tuple
							keepwhen(clickedwithoutkeyL, (false, Vector2(0.0), Vector2(0.0)), # Don't do unnecessary updates, so just signal when mouse is actually clicked
								foldl(mousediff, (false, Vector2(0.0), Vector2(0.0)),  # Get the difference, starting when the mouse is down
									clickedwithoutkeyL, normedposition)))
	OrthographicCamera(
				inputs[:window_size],
				zoom,
				translate,
				normedposition
			)

end
function OrthographicCamera{T}(
									windows_size::Signal{Vector2{Int}},
									zoom::Signal{T},
									translatevec::Signal{Vector2{T}},
									normedposition
								)

	lift(x -> glViewport(0,0, x...) , windows_size)
	projection = lift(wh -> begin
	  @assert wh[2] > 0
	  @assert wh[1] > 0
	  # change the aspect ratio, to always display an image with the right dimensions
	  # this behaviour should definitely be changed, as soon as the camera is used for anything else.
	  wh = wh[1] > wh[2] ? ((wh[1]/wh[2]), 1f0) : (1f0,(wh[2]/wh[1]))
	  orthographicprojection(0f0, convert(T, wh[1]), 0f0, convert(T, wh[2]), -1f0, 10f0)
	end, Matrix4x4{T}, windows_size)

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



function PerspectiveCamera{T}(inputs::Dict{Symbol,Any}, eyeposition::Vector3{T}, lookatvec::Vector3{T})

	mouseposition   	= inputs[:mouseposition]
	clicked         	= inputs[:mousebuttonspressed]
	keypressed      	= inputs[:buttonspressed]

	clickedwithoutkeyL 	= lift((mb, kb) -> in(0, mb) && isempty(kb), Bool, clicked, keypressed)
	clickedwithoutkeyM 	= lift((mb, kb) -> in(2, mb) && isempty(kb), Bool, clicked, keypressed)

	nokeydown 			= lift((kb) -> isempty(kb), Bool, keypressed)
	anymousedown 		= lift((mb) -> !isempty(mb), Bool, clicked)

	mousedraggdiffL = lift(x->x[3], Vector2{Float64}, foldl(mousediff, (false, Vector2(0.0), Vector2(0.0)), clickedwithoutkeyL, mouseposition))
	mousedraggdiffM = lift(x->x[3], Vector2{Float64}, foldl(mousediff, (false, Vector2(0.0), Vector2(0.0)), clickedwithoutkeyM, mouseposition))

	speed = 50f0
	xtheta = Input(0f0)
	ytheta = lift(x-> float32(-x[2]) / speed, Float32, mousedraggdiffL)
	ztheta = lift(x-> float32(x[1]) / speed, Float32, mousedraggdiffL)


	xtrans = lift(x-> float32(x*0.1f0), Float32, inputs[:scroll_y])
	ytrans = lift(x-> -float32(x[1]) / speed, Float32, mousedraggdiffM)
	ztrans = lift(x-> float32(x[2]) / speed, Float32, mousedraggdiffM)

	fov 	= Input(41f0)

	cam = PerspectiveCamera(
					inputs[:window_size],# = iVec2(50,50),
					
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
					Input(2000f0)
	)
end





function PerspectiveCamera{T}(
					window_size::Signal{Vector2{Int}},# = iVec2(50,50),
					
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
	lift(x-> glViewport(0,0,x...), window_size)
	eyepositionstart 	= Vector3{T}(1,0,0)
	origin 				= lookatvec

	xaxis 				= eyeposition - origin
	yaxis 				= cross(xaxis, Vector3{T}(0,0,1))
	zaxis 				= cross(yaxis, xaxis)

	translate 			= Vector3{T}(0,0,0)


	p0 = Pivot(origin, xaxis, yaxis, zaxis, Quaternion(1f0,0f0,0f0,0f0), translate, Vector3{T}(1))


	pivot = foldl((v0, v1) -> begin
		xt, yt, zt, xtr, ytr, ztr = v1

		xaxis = v0.rotation * v0.xaxis # rotate the axis
		yaxis = v0.rotation * v0.yaxis
		zaxis = v0.rotation * v0.zaxis

		xrot = qrotation(xaxis, xt)
		yrot = qrotation(yaxis, yt)
		zrot = qrotation(Vector3{T}(0,0,1), zt)

		v1rot = zrot*xrot*yrot*v0.rotation

		v1trans 	= yaxis*ytr + zaxis*ztr 
		accumtrans 	= v1trans + v0.translation

		Pivot(v0.origin + v1trans, v0.xaxis, v0.yaxis, v0.zaxis, v1rot, accumtrans + v0.xaxis*xtr, v0.scale)
		
	end, p0, lift(tuple, xtheta, ytheta, ztheta, xtrans, ytrans, ztrans))

	modelmatrix 	= lift(transformationmatrix, Matrix4x4{T}, pivot)
	positionvec 	= lift((m,v) -> (r=(convert(Array,m)*T[v...,1]) ; Vector3(r[1:3])), Vector3{T}, modelmatrix, Input(eyeposition))
	up 				= lift(p->p.rotation * p.zaxis , Vector3{T}, pivot)
	lookatvec1 		= lift(p->p.origin , Vector3{T}, pivot)

	view 			= lift(lookat, Matrix4x4{T}, positionvec, lookatvec1, up)

	window_ratio 	= lift(x -> x[1] / x[2], T, window_size)
	projection 		= lift(perspectiveprojection, Matrix4x4{T}, fov, window_ratio, nearclip, farclip)

	projectionview 	= lift(*, Matrix4x4{T}, projection, view)

	normalmatrix 	= lift(x -> inv(Matrix3x3(x))', Matrix3x3{T}, projectionview)

	return PerspectiveCamera{T}(
			pivot,
			window_size,
			nearclip,
			farclip,
			fov,
			view,
			projection,
			projectionview,
			normalmatrix,
			positionvec,
			lookatvec1,
			up
		)
end


