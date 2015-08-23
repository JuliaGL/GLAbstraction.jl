
abstract Unit
abstract Composable{unit}

immutable DeviceUnit <: Unit end

type Context{Unit} <: Composable{Unit}
    children::Vector{Composable}
    boundingbox::AABB{Float32}
end
Context() = Context{DeviceUnit}(Composable[], AABB{Float32}(Vec3f0(0), Vec3f0(0)))
function Context(a::Composable...)
    c = Context()
    append!(c, a)
    c
end
boundingbox(c::Composable) = boundingbox(c.boundingbox)
boundingbox(c::Signal) = c.value
boundingbox(c::AABB) = c

convert!{unit <: Unit}(::Type{unit}, x::Composable) = x # I don't do units just yet

function Base.append!{unit <: Unit, N}(context::Context{unit}, x::Union(Vector{Composable}, NTuple{N, Composable}))
    for elem in x
        push!(context, elem)
    end
    context
end
function Base.push!{unit <: Unit}(context::Context{unit}, x::Composable)
    x = convert!(unit, x)
    context.boundingbox = union(boundingbox(context), boundingbox(x))
    push!(context.children, x)
    context
end
