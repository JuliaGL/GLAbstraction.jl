
immutable CamVectors
	up::Vec3
	position::Vec3
	lookat::Vec3

	xangle::Float32
	yangle::Float32
	zoom::Float32	
	mousepressed::Bool
end


function movecam(state0::CamVectors, state1::CamVectors)
	if state0.mousepressed
		xangle 		= state0.xangle - state1.xangle #get the difference from the previous state
		yangle 		= state0.yangle - state1.yangle

		dir 		= state0.position - state0.lookat

		right 		= unit(cross(dir, state0.up))
		xrotation 	= rotate(deg2rad(xangle), state0.up) #rotation matrix around up
		yrotation 	= rotate(deg2rad(yangle), right)

		up 			= Vector3(yrotation * [state0.up...])
	 	pos1 		= Vector3(yrotation * xrotation * [state0.position...])
 		return CamVectors(up, pos1, state0.lookat, state1.xangle, state1.yangle, state1.zoom, state1.mousepressed)
	end	
	dir 	= state0.position - state0.lookat
	zoom 	= state0.zoom 	- state1.zoom
	zoomdir	= unit(dir)*zoom #zoom just shortens the direction vector
	pos1 	= state0.position-zoomdir
	return CamVectors(state0.up, pos1, state0.lookat, state1.xangle, state1.yangle, state1.zoom, state1.mousepressed)
end


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

function Cam(inputs, eyeposition)

	mouseposition   = inputs[:mouseposition]
	clicked         = inputs[:mousebuttonspressed]
	keypressed      = inputs[:buttonspressed]

	clickedwithoutkeyL 	= lift((mb, kb) -> in(0, mb) && isempty(kb), Bool, clicked, keypressed)
	clickedwithoutkeyM 	= lift((mb, kb) -> in(2, mb) && isempty(kb), Bool, clicked, keypressed)

	nokeydown 			= lift((kb) -> isempty(kb), Bool, keypressed)
	anymousedown 		= lift((mb) -> !isempty(mb), Bool, clicked)




	mousedraggdiffL = lift(x->x[3], Vector2{Float64}, foldl(mousediff, (false, Vector2(0.0), Vector2(0.0)), clickedwithoutkeyL, mouseposition))
	mousedraggdiffM = lift(x->x[3], Vector2{Float64}, foldl(mousediff, (false, Vector2(0.0), Vector2(0.0)), clickedwithoutkeyM, mouseposition))

	#mousedraggdiffL = keepwhen(clickedwithoutkeyL, Vector2(0.0), mousedraggdiffL)
	#mousedraggdiffM = keepwhen(clickedwithoutkeyM, Vector2(0.0), mousedraggdiffM)

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
					
					Input(Vec3(1,0,0)),
					Input(Vec3(0)),
					
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
					
					eyeposition::Signal{Vector3{T}},
					lookatvec::Signal{Vector3{T}},
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

	xaxis 				= Vector3{T}(1,0,0)
	yaxis 				= Vector3{T}(0,1,0)
	zaxis 				= Vector3{T}(0,0,1)

	eyepositionstart 	= Vector3{T}(1,0,0)
	origin 				= lookatvec.value

	translate 			= Vector3{T}(0,0,0)
	rotation0 			= Quaternion(1f0,0f0,0f0,0f0)
	
	p0 = Pivot(origin, xaxis, yaxis, zaxis, rotation0, translate, Vector3{T}(1))


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
	positionvec 	= lift((m,v) -> (r=(convert(Array,m)*T[v...,1]) ; Vector3(r[1:3])), Vector3{T}, modelmatrix, Input(eyepositionstart))
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

function Cam{T}(
					window_size::Input{Vector2{Int}},
					xangle,
					yangle,
					zoom,
					eyeposition::Vector3{T},
					lookatvec::Input{Vector3{T}},
					fov::Signal{T},
					mousedown::Signal{Bool}
				)

	nearclip 		= Input(convert(T, 1))
	farclip 		= Input(convert(T, 100))

	up 				= Input(Vec3(0,0,1))
	pos 			= Input(Vec3(1,0,0)) 
	lookatv 		= Input(Vec3(0))

	inputs 			= lift((x...) -> CamVectors(x...), up, pos, lookatv, xangle, yangle, zoom, mousedown)

	camvecs 	= foldl(movecam, CamVectors(Vec3(0,0,1), Vec3(1,0,0), Vec3(0), 0f0, 0f0, 0f0, false) , inputs)
	positionvec = lift(x-> x.position, Vec3, camvecs)
	lookatvec 	= lift(x-> x.lookat, Vec3, camvecs)
	up 			= lift(x-> x.up, Vec3, camvecs)

	camvecs = lift(x-> (x.position, x.lookat, x.up), camvecs)
	lift(x -> glViewport(0,0, x[1], x[2]), window_size)
	view 	= lift(lookat, Mat4, positionvec, lookatvec, up)

	window_ratio 	= lift(x -> x[1] / x[2], Float32, window_size)
	projection 		= lift(perspectiveprojection, Mat4, fov, window_ratio, nearclip, farclip)

	projectionview 	= lift(*, Mat4, projection, view)

	normalmatrix 	= lift(x -> inv(Matrix3x3(x))', Matrix3x3{T}, projectionview)
	Cam{T}(
			window_size,
			nearclip,
			farclip,
			fov,
			view,
			projection,
			projectionview,
			normalmatrix,
			positionvec,
			lookatvec,
			up
		)
end



export Cam
