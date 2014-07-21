using Quaternions

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
function rotate{T}(angle::T, axis::Vector3{T})
 	rotationmatrix(qrotation(convert(Array, axis), angle))
end


immutable Cam{T}
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

function Cam(inputs, eyeposition)
	mouseposition 	= inputs[:mouseposition]
	clicked 	= inputs[:mousepressed]
	keypressed 	= inputs[:keypressed]

	draggx = lift(x-> float32(x[1]), Float32, mouseposition)
	draggy = lift(x-> float32(x[2]), Float32, mouseposition)
	zoom = foldl((a,b) -> float32(a+(b*0.1f0)) , 0f0, inputs[:scroll_y])

	fov 	= foldl((a,b) -> begin
				if b == 265
					return a-5f0
				elseif b == 264
					return a+5f0
				end
				a
			end, 41f0, inputs[:keypressed])

	Cam(inputs[:window_size], draggx, draggy, zoom, eyeposition, Input(Vector3(0f0)), fov, inputs[:mousepressed])
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

	#strgmod = lift(x-> x==GLFW.MOD_CONTROL, Bool, inputs[:keymodifiers])
	#position = keepwhen(strgmod, lift(x-> Vec2(x...), Vec2, mouseposition)

	up 		= Input(Vec3(0,0,1))
	pos 	= Input(Vec3(1,0,0)) 
	lookatv = Input(Vec3(0))

	inputs = lift((x...) -> CamVectors(x...), up, pos, lookatv, xangle, yangle, zoom, mousedown)


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


function update(cam::PerspectiveCamera)
	cam.projection 	= perspectiveprojection(76, cam.w / cam.h,  1.0f0, 30.0f0)
	cam.view   		= lookAt(
					cam.position,           # Camera is here
					cam.lookAt, # and looks here : at the same position, plus "direction"
					[0f0, 0f0, 1f0])

end
function update(cam::OrthogonalCamera)
	cam.projection 		= computeOrthographicProjection(0f0, cam.w, 0f0, cam.h, cam.nearClip, cam.farClip)
	cam.view 			= translationMatrix(cam.position)
end


rotate(xDiff, yDiff, cam::Camera) = rotate(float32(xDiff), float32(yDiff), cam)

function rotate(xDiff::Float32, yDiff::Float32, cam::Camera)
	if xDiff > 0
		rotMatrixX = rotatationMatrix(deg2rad(xDiff), [0,0,1])
	else
		rotMatrixX = inv(rotatationMatrix(deg2rad(abs(xDiff)), [0,0,1]))
	end
	if yDiff > 0
		rotMatrixY = rotatationMatrix(deg2rad(yDiff), cam.right)
	else
		rotMatrixY = inv(rotatationMatrix(deg2rad(abs(yDiff)), cam.right))
	end
	position = [cam.position..., 1f0]'
	position *= rotMatrixY
	position *= rotMatrixX
	cam.position = position[1:3]

	cam.direction 	= cam.position - cam.lookAt
	cam.right 		= cross(cam.direction, [0f0, 0f0, 1f0])
	cam.right 		/= norm(cam.right)

	update(cam)
end
function rotate2(xDiff::Float32, yDiff::Float32, cam::Camera)
	cam.verticalAngle   += cam.rotationSpeed * yDiff
	cam.direction = [
		cos(cam.verticalAngle) * sin(cam.horizontalAngle),
		sin(cam.verticalAngle),
		cos(cam.verticalAngle) * cos(cam.horizontalAngle)]

	# Right vector
	cam.right = cross(cam.direction, [0f0, 0f0, 1f0])

	update(cam)
end
function zoom(event, cam::Camera)
	cam.FoV += event.key == 4 ? -cam.zoomSpeed : cam.zoomSpeed
	update(cam)
end
function move(xDiff, yDiff, cam::PerspectiveCamera)
	cam.position += cam.right 		* xDiff * cam.moveSpeed
	cam.position += cam.direction 	* yDiff * cam.moveSpeed
	update(cam)
end

function move(event, cam::OrthogonalCamera)
	cam.position[2] += event.key == 4 ? -cam.moveSpeed : cam.moveSpeed
	update(cam)
end

resize(event, cam::Camera) = resize(event.w, event.h, cam)
function resize2(event, cam)
	cam.w = 1.0
	cam.h = event.h / event.w
	update(cam)
end

function resize(w, h, cam::Camera)
	cam.w = w
	cam.h = h
	update(cam)
end

export resize, move, zoom, rotate, mouseToRotate, resize2, update, Cam
