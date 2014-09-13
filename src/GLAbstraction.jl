module GLAbstraction
using ImmutableArrays, ModernGL, Reactive, Quaternions, Color, FixedPointNumbers
import Images: imread, colorspace, Image, AbstractGray, RGB4

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
