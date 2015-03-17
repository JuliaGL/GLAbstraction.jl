using GLAbstraction, GLPlot

createdisplay(async=true)

obj = glplot(rand(Float32, 20,20), color=Vec4(1,0,0,1), primitive=CUBE())

gpuz = obj[:z]

gpuz[1,1] = Float32(2)

obj[:postrender, renderinstanced] = (obj.vertexarray, 3)