module GLAbstraction
using ImmutableArrays, ModernGL, React, Quaternions
import Mustache
import Base.delete!

include("GLInit.jl")
include("GLExtendedFunctions.jl")
include("GLTypes.jl")
include("GLUniforms.jl")

include("GLMatrixMath.jl")
include("GLRender.jl")
include("GLShader.jl")
include("GLCamera.jl")
include("GLShapes.jl")


end # module
