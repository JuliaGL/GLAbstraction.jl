
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
	horizontalAngle::Float32 		= 10f0,
	verticalAngle::Float32 			= 0f0,
	rotationSpeed::Float32 			= 0.00005f0,
	zoomSpeed::Float32 				= 5f0,
	moveSpeed::Float32 				= 0.01f0,
	FoV::Float32 					= 50f0,
	position::Array{Float32, 1}		= [0f0,50f0,0f0],
	id::Int							= 0)  
	
	PerspectiveCamera(nearClip,farClip,horizontalAngle,verticalAngle,rotationSpeed,zoomSpeed,moveSpeed,FoV,position)
end




function update(cam::PerspectiveCamera)
	projMat 	= pProj(cam.FoV, cam.w / cam.h,  1.0f0, 30.0f0)

	viewMatrix  = lookAt(	
					cam.position,           # Camera is here
					cam.position + cam.direction, # and looks here : at the same position, plus "direction"
					cam.up)
	
	cam.mvp 	= projMat * viewMatrix 
end
function update(cam::OrthogonalCamera)
	projMat 		= computeOrthographicProjection(0f0, cam.w, 0f0, cam.h, cam.nearClip,  cam.farClip)
	viewMatrix 		= translationMatrix(cam.position)
	cam.mvp 		= projMat * viewMatrix
end

function mouseToRotate(event, cam)
	rotate(float32(event.start.x - event.x), float32(event.start.y - event.y), cam)
end

function rotate(xDiff::Float32, yDiff::Float32, cam::Camera)
	cam.horizontalAngle += cam.rotationSpeed * xDiff
	cam.verticalAngle   += cam.rotationSpeed * yDiff
	cam.direction = [
		cos(cam.verticalAngle) * sin(cam.horizontalAngle), 
		sin(cam.verticalAngle),
		cos(cam.verticalAngle) * cos(cam.horizontalAngle)]
	
	# Right vector
	cam.right = [
		sin(cam.horizontalAngle - 3.14f0/2.0f0), 
		0,
		cos(cam.horizontalAngle - 3.14f0/2.0f0)]

	cam.up = cross(cam.right, cam.direction)
	update(cam)
end

function zoom(event, cam::Camera)
	cam.FoV += event.key == 4 ? -cam.zoomSpeed : cam.zoomSpeed
	update(cam)
end

function move(event, cam::PerspectiveCamera)
	global lastX = 0
	global lastY = 0

	cam.position += cam.right 		* (event.start.x - event.x) * cam.moveSpeed
	cam.position += cam.direction 	* (event.start.y - event.y) * cam.moveSpeed

	lastX = event.x
	lastY = event.y
	update(cam)
end
function move(event, cam::OrthogonalCamera)
	cam.position[2] += event.key == 4 ? -cam.moveSpeed : cam.moveSpeed
	update(cam)
end

resize(event, cam::Camera) = resize(event.w, event.h, cam)

function resize(w, h, cam::Camera)
	cam.w = w
	cam.h = h
	update(cam)
end

export resize, move, zoom, rotate, mouseToRotate