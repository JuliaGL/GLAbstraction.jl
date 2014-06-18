
function OrthogonalCamera(;
	nearClip::Float32 				= -10f0,
	farClip::Float32 				= 10f0,
	angle::Float32 					= 0f0,
	rotationSpeed::Float32 			= 0.00005f0,
	zoomSpeed::Float32 				= 5f0,
	moveSpeed::Float32 				= 10f0,
	position::Array{Float32, 1}		= [0f0,0f0,0f0],
	id::Int							= 0) 
	
	OrthogonalCamera(nearClip, farClip, angle, rotationSpeed, zoomSpeed,moveSpeed, position)
end
function PerspectiveCamera(;
	nearClip::Float32 				= 1f0,
	farClip::Float32 				= 30f0,
	horizontalAngle::Float32 		= 0f0,
	verticalAngle::Float32 			= 0f0,
	rotationSpeed::Float32 			= 0.05f0,
	zoomSpeed::Float32 				= 5f0,
	moveSpeed::Float32 				= 0.01f0,
	FoV::Float32 					= 50f0,
	position::Vector{Float32}		= [0f0,50f0,0f0],  
	lookAt::Vector{Float32}			= [0f0,0f0,0f0])  
	
	PerspectiveCamera(nearClip,farClip,horizontalAngle,verticalAngle,rotationSpeed,zoomSpeed,moveSpeed,FoV,position, lookAt)
end


function move{T}(point::Vector3{T}, angleX::T, angleY::T, zoom::T, lookatvec::Vector3{T}, up::Vector3{T})
	println(angleX)
	dir 		= point - lookatvec
	right 		= unit(cross(dir, up))

	xrotation 	= rotate(angleX, up)
	yrotation 	= rotate(angleY, right)
	zoomdir		= unit(dir)*zoom
 	Vector3(xrotation * yrotation * (Vector4((point-zoomdir)..., 0f0)))
end

function rotate(angle, axis)
	if angle > 0
		rotation = rotationmatrix(float32(deg2rad(angle)), axis)
	else
		# dirty workaround, because inv(Matrix4x4) is not working
		rotation = rotationmatrix(float32(deg2rad(abs(angle))), axis)
		tmp 	 	= zeros(Float32, 4,4)
		tmp[1:4, 1] = [rotation.c1...]
		tmp[1:4, 2] = [rotation.c2...]
		tmp[1:4, 3] = [rotation.c3...]
		tmp[1:4, 4] = [rotation.c4...]
		rotation = inv(tmp)
		rotation = Matrix4x4(rotation)
	end
end
function rotate(point::Vector3, rotationmatrix::Matrix4x4)
	Vector3(rotationmatrix * Vector4(point..., 0f0))
end
immutable Cam{T}
	window_size::Signal{Vector2{Int}}
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


function Cam{T}(window_size::Input{Vector2{Int}}, xdiff, ydiff, zoom, eyeposition::Vector3{T}, lookatvec::Input{Vector3{T}})
	
	nearclip 		= Input(convert(T, 1))
	farclip 		= Input(convert(T, 30))
	up 				= Input(Vector3{T}(0, 0, 1))
	fov 			= Input(convert(T, 76))

	rotationData	= lift(tuple, (T, T, T, Vector3{T}, Vector3{T}), xdiff, ydiff, zoom, lookatvec, up)

	positionvec		= foldl((pos, data) -> move(pos, data...), eyeposition, rotationData)


	window_ratio 	= lift(x -> x[1] / x[2], T, window_size)

	viewmat 		= lift(lookat, Matrix4x4{T}, positionvec, lookatvec, up)

	projection 		= lift(perspectiveprojection, Matrix4x4{T}, fov, window_ratio, nearclip, farclip)
	projectionview 	= lift(*, Matrix4x4{T}, projection, viewmat)

	Cam{T}(
			window_size, 
			nearclip,
			farclip,
			fov,
			viewmat, 
			projection,
			projectionview,
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