immutable Cam{T}
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
        return (clicked, pos, pos0 - pos)
    end
    return (clicked, pos, Vector2(0.0))
end

function Cam{T}(inputs::Dict{Symbol,Any}, eyeposition::Vector3{T}, lookatvec::Vector3{T})

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

	cam = Cam(
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
					Input(100f0)
	)
end





function Cam{T}(
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
	eyepositionstart 	= Vector3{T}(1,0,0)

	rotation0 			= rotation(eyepositionstart, eyeposition)

	xaxis 				= rotation0 * Vector3{T}(1,0,0)
	yaxis 				= rotation0 * Vector3{T}(0,1,0)
	zaxis 				= rotation0 * Vector3{T}(0,0,1)

	translate 			= Vector3{T}(0,0,0)

	origin 				= lookatvec

	p0 = Pivot(origin, xaxis, yaxis, zaxis, Quaternion(1f0,0f0,0f0,0f0), translate, Vector3{T}(1))


	pivot = foldl((v0, v1) -> begin
		xt, yt, zt, xtr, ytr, ztr = v1

		xaxis = v0.rotation * v0.xaxis # rotate the axis
		yaxis = v0.rotation * v0.yaxis
		zaxis = v0.rotation * v0.zaxis

		xrot = qrotation(xaxis, xt)
		yrot = qrotation(yaxis, yt)
		zrot = qrotation(v0.zaxis, zt)

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

	return Cam{T}(
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




export Cam
