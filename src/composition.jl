
abstract Unit
abstract Composable{unit}

immutable DeviceUnit <: Unit end

type Context{Unit} <: Composable{Unit}
    children::Vector{Composable}
    boundingbox::Signal{AABB{Float32}}
    transformation::Signal{Mat{4,4, Float32}}
end
Context() = Context{DeviceUnit}(Composable[], Input(AABB{Float32}(Vec3f0(0), Vec3f0(0))), Input(eye(Mat{4,4, Float32})))
Context(trans::Signal{Mat{4,4, Float32}}) = Context{DeviceUnit}(Composable[], Input(AABB{Float32}(Vec3f0(0), Vec3f0(0))), trans)
function Context(a::Composable...; parent=Context())
    append!(parent, a)
    parent
end
boundingbox(c::Composable) = c.boundingbox
transformation(c::Composable) = c.transformation

function transformation(c::Composable, model)
    c.transformation = lift(*, model, c.transformation)
    for elem in c.children
        transformation(elem, c.transformation)
    end
end

convert!{unit <: Unit}(::Type{unit}, x::Composable) = x # I don't do units just yet

function Base.append!{unit <: Unit, N}(context::Context{unit}, x::Union{Vector{Composable}, NTuple{N, Composable}})
    for elem in x
        push!(context, elem)
    end
    context
end
function Base.push!{unit <: Unit}(context::Context{unit}, x::Composable)
    x = convert!(unit, x)
    context.boundingbox = lift(union, boundingbox(context), boundingbox(x))
    transformation(x, transformation(context))
    push!(context.children, x)
    context
end
export transformation
export boundingbox