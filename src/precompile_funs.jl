

Base.precompile(*, (Mat{4,4, Float32}, Mat{4,4, Float32}))
Base.precompile(*, (Mat{4,4, Float32}, Vec{4, Float32}))
Base.precompile(transformationmatrix, (Vec{4, Float32},))
Base.precompile(frustum, (Float32,Float32,Float32,Float32,Float32,Float32,))
Base.precompile(perspectiveprojection, (Rectangle{Int}, Float32, Float32, Float32))
Base.precompile(lookat, (Vec3f0,Vec3f0,Vec3f0))
Base.precompile(orthographicprojection, (Rectangle{Int},Float32, Float32))
Base.precompile(Quaternions.qrotation, (Vec3f0, Float32))
Base.precompile(rotationmatrix4, (Quaternions.Quaternion{Float32},))
Base.precompile(transformationmatrix, (Pivot{Float32},))
Base.precompile(rotation, (Vec3f0,Vec3f0))
Base.precompile(scalematrix, (Vec3f0,))


Base.precompile(PerspectiveCamera, (
	Reactive.Lift{Rectangle{Int}},
	Vec3f0,
	Vec3f0,
	Reactive.Lift{Vec3f0},
	Reactive.Lift{Vec3f0},
	Input{Float32},
	Input{Float32},
	Input{Float32},
	Input{Projection}, 
	Input{Bool},
	Input{Quaternions.Quaternion{Float32}})
)
Base.precompile(OrthographicCamera, (
	Reactive.Lift{Rectangle{Int}},
	Reactive.Lift{Mat{4,4, Float32}},
	Input{Float32}, # nearclip
	Input{Float32})
)
Base.precompile(PerspectiveCamera, (Dict{Symbol, Any}, Vec3f0, Vec3f0))
Base.precompile(OrthographicPixelCamera, (Dict{Symbol, Any},))
Base.precompile(call, (Type{Vec3f0}, Int, Int, Int))
Base.precompile(call, (Type{Vec3f0}, Int,))
Base.precompile(call, (Type{Vec3f0}, Float32,))
Base.precompile(call, (Type{Vec3f0},Float32,Float32,Float32,))

Base.precompile(call, (Type{Vec2f0}, Float32,Float32,))
Base.precompile(call, (Type{Vec2f0}, Int,Int,))
Base.precompile(call, (Type{Vec2f0}, Int,))
Base.precompile(call, (Type{Vec2f0}, Float32,))

Base.precompile(call, (Type{Mat{4,4, Float32}}, Tuple{
	Tuple{Float32, Float32, Float32, Float32},
	Tuple{Float32, Float32, Float32, Float32},
	Tuple{Float32, Float32, Float32, Float32},
	Tuple{Float32, Float32, Float32, Float32},
	})
)

Base.precompile(lift, (Function, Input{Vec3f0}, Input{Vec3f0}))
Base.precompile(foldl, (Function, Vec3f0 ,Input{Vec3f0}, Input{Vec3f0}))