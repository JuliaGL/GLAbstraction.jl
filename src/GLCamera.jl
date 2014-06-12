
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




function update(cam::PerspectiveCamera)
	projMat 	= pProj(cam.FoV, cam.w / cam.h,  1.0f0, 30.0f0)
	viewMatrix  = lookAt(	
					cam.position,           # Camera is here
					cam.lookAt, # and looks here : at the same position, plus "direction"
					[0f0, 0f0, 1f0])

	cam.mvp 	= projMat * viewMatrix 
end
function update(cam::OrthogonalCamera)
	projMat 		= computeOrthographicProjection(0f0, cam.w, 0f0, cam.h, cam.nearClip,  cam.farClip)
	viewMatrix 		= translationMatrix(cam.position)
	cam.mvp 		= projMat * viewMatrix
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

export resize, move, zoom, rotate, mouseToRotate, resize2, update