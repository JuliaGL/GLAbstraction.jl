import Base: copy!
import Base: splice!
import Base: append!
import Base: push!
import Base: resize!
import Base: setindex!
import Base: getindex
import Base: map
import Base: length
import Base: eltype
import Base: endof
import Base: ndims
import Base: size
import Base: start
import Base: next
import Base: done

import GeometryTypes.Rectangle

abstract GPUArray{T, NDim} <: AbstractArray{T, NDim}

#=
immutable GPUArray{T, NDim, GPUBuff <: GPUBuffer} <: DenseArray{T, NDim}
    buff::GPUBuff{T, NDim}
    size::NTuple{Int, NDim}
end

immutable BufferedGPUArray{GPUArr <: GPUArray}
    buff::GPUBuff{T, NDim}
    ram::Array{T, NDim}
end
=#

length(A::GPUArray)                                     = prod(size(A))
eltype{T, NDim}(b::GPUArray{T, NDim})                   = T
endof(A::GPUArray)                                      = length(A)
ndims{T, NDim}(A::GPUArray{T, NDim})                    = NDim
size(A::GPUArray)                                       = A.size
size(A::GPUArray, i::Integer)                           = A.size[i]

function checkdimensions(value::Array, ranges::Union{Integer, UnitRange}...)
    array_size   = size(value)
    indexes_size = map(length, ranges)

    (array_size != indexes_size) && throw(DimensionMismatch("asigning a $array_size to a $(indexes_size) location"))
    true
end
to_range(index) = map(index) do val
    isa(val, Integer) && return val:val
    isa(val, Range) && return val
    error("Indexing only defined for integers or ranges. Found: $val")
end

setindex!{T, N}(A::GPUArray{T, N}, value::Union{T, Array{T, N}}) = (A[1] = value)

function setindex!{T, N}(A::GPUArray{T, N}, value, indexes...)
    ranges = to_range(indexes)
    v = isa(value, T) ? [value] : convert(Array{T,N}, value)
    setindex!(A, v, ranges...)
    nothing
end

setindex!{T}(A::GPUArray{T, 2}, value::Vector{T}, i::Integer, range::UnitRange) =
   (A[i, range] = reshape(value, (length(value),1)))

function setindex!{T, N}(A::GPUArray{T, N}, value::Array{T, N}, ranges::UnitRange...)
    checkbounds(A, ranges...)
    checkdimensions(value, ranges...)
    gpu_setindex!(A, value, ranges...)
    nothing
end

function update!{T, N}(A::GPUArray{T, N}, value::Array{T, N})
    @assert length(A) == length(value) "update! needs arrays to have the same length. To update length: $(length(A)), updatevalue $(length(value))"
    dims = map(x->1:x, size(A))
    A[dims...] = value
    nothing
end

getindex{T, N}(A::GPUArray{T, N}, i::Int) = (checkbounds(A, i); gpu_getindex(A, i:i)[1]) # not as bad as its looks, as so far gpu data must be loaded into an array anyways
function getindex{T, N}(A::GPUArray{T, N}, ranges::UnitRange...)
    checkbounds(A, ranges...)
    gpu_getindex(A, ranges...)
end

getindex{T, N}(A::GPUArray{T, N}, rect::Rectangle)                      = A[rect.x+1:rect.x+rect.w, rect.y+1:rect.y+rect.h]
setindex!{T, N}(A::GPUArray{T, N}, value::Array{T, N}, rect::Rectangle) = (A[rect.x+1:rect.x+rect.w, rect.y+1:rect.y+rect.h] = value)


type GPUVector{T}
    buffer
    size
    real_length
end
GPUVector(x::GPUArray) = GPUVector{eltype(x)}(x, size(x), length(x))

function update!{T}(A::GPUVector{T}, value::Vector{T})
    @assert length(A) == length(value) "update! needs arrays to have the same length. To update length: $(length(A)), updatevalue $(length(value))"
    dims = map(x->1:x, size(A))
    A.buffer[dims...] = value
    nothing
end

length(v::GPUVector)            = prod(size(v))
size(v::GPUVector)              = v.size
size(v::GPUVector, i::Integer)  = v.size[i]
ndims(::GPUVector)              = 1
eltype{T}(::GPUVector{T})       = T
endof(A::GPUVector)             = length(A)


start(b::GPUVector)             = start(b.buffer)
next(b::GPUVector, state)       = next(b.buffer, state)
done(b::GPUVector, state)       = done(b.buffer, state)

gpu_data(A::GPUVector)          = A.buffer[1:length(A)]

getindex(v::GPUVector, index)           = v.buffer[index]
setindex!(v::GPUVector, value, index)   = v.buffer[index] = value


function grow_dimensions(real_length::Int, _size::Int, additonal_size::Int, growfactor::Real=1.5)
    new_dim = round(Int, real_length*growfactor)
    return max(new_dim, additonal_size+_size)
end
function Base.push!{T}(v::GPUVector{T}, x::Vector{T})
    lv, lx = length(v), length(x)
    if (v.real_length < lv+lx)
        resize!(v.buffer, grow_dimensions(v.real_length, lv, lx))
    end
    v.buffer[lv+1:(lv+lx)] = x
    v.real_length          = length(v.buffer)
    v.size                 = (lv+lx,)
    v
end
push!{T}(v::GPUVector{T}, x::T)            = push!(v, [x])
push!{T}(v::GPUVector{T}, x::T...)         = push!(v, [x...])
append!{T}(v::GPUVector{T}, x::Vector{T})  = push!(v, x)

resize!{T, NDim}(A::GPUArray{T, NDim}, dims::Int...) = resize!(A, dims)
function resize!{T, NDim}(A::GPUArray{T, NDim}, newdims::NTuple{NDim, Int})
    newdims == size(A) && return A
    gpu_resize!(A, newdims)
    A
end

function resize!(v::GPUVector, newlength::Int)
    if v.real_length >= newlength # is still big enough
        v.size = (max(0, newlength),)
        return v
    end
    resize!(v.buffer, grow_dimensions(v.real_length, length(v),  newlength-length(v)))
    v.size        = (newlength,)
    v.real_length = length(v.buffer)
end
function grow_at(v::GPUVector, index::Int, amount::Int)
    resize!(v, length(v)+amount)
    copy!(v, index, v, index+amount, amount)
end

function splice!{T}(v::GPUVector{T}, index::UnitRange, x::Vector=T[])
    lenv = length(v)
    elements_to_grow = length(x)-length(index) # -1
    buffer           = similar(v.buffer, length(v)+elements_to_grow)
    copy!(v.buffer, 1, buffer, 1, first(index)-1) # copy first half
    copy!(v.buffer, last(index)+1, buffer, first(index)+length(x), lenv-last(index)) # shift second half
    v.buffer      = buffer
    v.real_length = length(buffer)
    v.size        = (v.real_length,)
    copy!(x, 1, buffer, first(index), length(x)) # copy contents of insertion vector
    nothing
end
splice!{T}(v::GPUVector{T}, index::Int, x::T) = v[index] = x
splice!{T}(v::GPUVector{T}, index::Int, x::Vector=T[]) = splice!(v, index:index, map(T, x))


copy!(a::GPUVector, a_offset::Int, b::Vector, b_offset::Int, amount::Int)   = copy!(a.buffer, a_offset, b,        b_offset, amount)
copy!(a::GPUVector, a_offset::Int, b::GPUVector, b_offset::Int, amount::Int)= copy!(a.buffer, a_offset, b.buffer, b_offset, amount)


copy!(a::GPUArray, a_offset::Int, b::Vector,   b_offset::Int, amount::Int) = _copy!(a, a_offset, b, b_offset, amount)
copy!(a::Vector,   a_offset::Int, b::GPUArray, b_offset::Int, amount::Int) = _copy!(a, a_offset, b, b_offset, amount)
copy!(a::GPUArray, a_offset::Int, b::GPUArray, b_offset::Int, amount::Int) = _copy!(a, a_offset, b, b_offset, amount)

#don't overwrite Base.copy! with a::Vector, b::Vector
function _copy!(a::Union{Vector, GPUArray}, a_offset::Int, b::Union{Vector, GPUArray}, b_offset::Int, amount::Int)
    (amount <= 0) && return nothing
    @assert a_offset > 0 && (a_offset-1) + amount <= length(a) "a_offset $a_offset, amount $amount, lengtha $(length(a))"
    @assert b_offset > 0 && (b_offset-1) + amount <= length(b) "b_offset $b_offset, amount $amount, lengthb $(length(b))"
    unsafe_copy!(a, a_offset, b, b_offset, amount)
    return nothing
end

# Interface:
gpu_data(t)      = error("gpu_data not implemented for: $(typeof(t)). This happens, when you call data on an array, without implementing the GPUArray interface")
gpu_resize!(t)   = error("gpu_resize! not implemented for: $(typeof(t)). This happens, when you call resize! on an array, without implementing the GPUArray interface")
gpu_getindex(t)  = error("gpu_getindex not implemented for: $(typeof(t)). This happens, when you call getindex on an array, without implementing the GPUArray interface")
gpu_setindex!(t) = error("gpu_setindex! not implemented for: $(typeof(t)). This happens, when you call setindex! on an array, without implementing the GPUArray interface")
max_dim(t)       = error("max_dim not implemented for: $(typeof(t)). This happens, when you call setindex! on an array, without implementing the GPUArray interface")


function Base.call{T <: GPUArray}(::Type{T}, x::Signal)
    gpu_mem = T(value(x))
    Reactive.preserve(const_lift(update!, gpu_mem, x))
    gpu_mem
end

export data
export resize
export GPUArray
export GPUVector

export update!

export gpu_data
export gpu_resize!
export gpu_getindex
export gpu_setindex!
export max_dim
