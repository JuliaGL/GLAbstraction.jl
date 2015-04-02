immutable Layout{Structure, Limits} end

immutable RenderObject
	camera
	primitive
	layout
	model
	light
	program
end


typealias Surface RenderObject{Mesh2D, Layout{Matrix{Z}, Rectangle}}
typealias BoxPlot RenderObject{Mesh3D, Layout{Matrix{ZScale}, Rectangle}}

typealias VectorField RenderObject{Mesh3D, Layout{Array{Vector3, 3}, Cube}} # better Vector{DualQuaternion}

typealias Particle RenderObject{Mesh3D, Layout{Array{Point}, Nothing}}

typealias Text2D RenderObject{Mesh2D, Layout{Array{Point2}, Nothing}}
typealias Text3D RenderObject{Mesh2D, Layout{Array{Point3}, Nothing}}

typealias Image RenderObject{Texture, Layout{Matrix{Color}, Rectangle}}


typealias List RenderObject{Vector{RenderObject}, Rectangle}
typealias Grid RenderObject{Matrix{RenderObject}, Rectangle}


typealias HeightField Layout{Matrix{Real}, Rectangle}}

typealias OrientedGrid3D Layout{Array{Vector3, 3}, Cube}
typealias OrientedGrid2D Layout{Array{Vector3, 2}, Cube}

typealias Particle2D Layout{Array{Point2}, Nothing}
typealias Particle3D Layout{Array{Point3}, Nothing}

typealias Text2D RenderObject{Mesh2D, Layout{Array{Point2}, Nothing}}
typealias Text3D RenderObject{Mesh2D, Layout{Array{Point3}, Nothing}}

typealias Image RenderObject{Texture, Layout{Matrix{Color}, Rectangle}}


typealias List RenderObject{Vector{RenderObject}, Rectangle}
typealias Grid RenderObject{Matrix{RenderObject}, Rectangle}