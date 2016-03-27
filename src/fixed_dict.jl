"""
Dictionary types which keys are fixed at creation time
"""
abstract AbstractFixedDict{Keys}

"""
Dictionary types which keys and values are fixed at creation time
"""
immutable FixedKeyValueDict{Keys<:Tuple, Values<:Tuple} <: AbstractFixedDict{Keys}
    values::Values
end
"""
Dictionary types which keys are fixed at creation time
"""
immutable FixedKeyDict{Keys<:Tuple, Values<:AbstractVector} <: AbstractFixedDict{Keys}
    values::Values
end

function FixedKeyValueDict{N}(keys::NTuple{N, Symbol}, values::NTuple{N, Any})
    keyparams = Tuple{keys...}
    FixedKeyValueDict{keyparams, typeof(values)}(values)
end

function FixedKeyValueDict(key_values)
    keys = map(first, key_values)
    values = map(last, key_values)
    keyparams = Tuple{keys...}
    FixedKeyValueDict{keyparams, typeof(values)}(values)
end


function FixedKeyDict{N}(keys::NTuple{N, Symbol}, values::AbstractVector)
    keyparams = Tuple{keys...}
    FixedKeyDict{keyparams}(values)
end

function FixedKeyDict(key_values)
    keys = map(first, key_values)
    values = [v for (k,v) in key_values]
    keyparams = Tuple{keys...}
    FixedKeyDict{keyparams, typeof(values)}(values)
end

@generated function Base.keys{T<:AbstractFixedDict}(::Type{T})
    keys = [Expr(:quote, sym) for sym in T.parameters[1].parameters]
    :(tuple($(keys...)))
end

Base.keys{T<:AbstractFixedDict}(::T) = keys(T)
Base.values(x::AbstractFixedDict) = x.values
Base.length(x::AbstractFixedDict) = length(x.values)

function Base.start(x::AbstractFixedDict)
    ks = keys(x)
    (1, ks) # we pass around the keys so that we don't have to get them multiple times
end
function Base.next(x::AbstractFixedDict, state)
    index, ks = state
    (x[index], ks[index]), (index+1, ks)
end
function Base.done(x::AbstractFixedDict, state)
    length(x) > state[1]
end

@generated function Base.getindex{T<:AbstractFixedDict, Key}(
        sd::T, ::Type{Val{Key}}
    )
    index = findfirst(keys(T), Key)
    index == 0 && throw(KeyError("key $Key not found in $sd"))
    :(@inbounds return sd.values[$index])
end

@generated function Base.setindex!{T<:FixedKeyDict, Key}(
        sd::T, value, ::Type{Val{Key}}
    )
    index = findfirst(keys(T), Key)
    index == 0 && throw(KeyError("key $Key not found in $sd"))
    :(@inbounds return sd.values[$index] = value)
end

function haskey{T<:AbstractFixedDict, Key}(sd::T, ::Type{Val{Key}})
    Key in keys(sd)
end
function get{T<:AbstractFixedDict, Key}(f::Function, sd::T, k::Type{Val{Key}})
    if haskey(sd, k)
        sd[k]
    else
        f()
    end
end
function get{T<:AbstractFixedDict, Key}(f::Function, sd::T, k::Type{Val{Key}})
    if haskey(sd, k)
        sd[k]
    else
        f()
    end
end
function get!{T<:FixedKeyDict, Key}(f::Function, sd::T, k::Type{Val{Key}})
    if haskey(sd, k)
        sd[k]
    else
        val = f()
        sd[k] = val
        val
    end
end

function getfield_expr(expr)
    dict, key = expr.args
    :($dict[Val{$key}])
end
macro get(expr)
    if expr.head == :(.)
        return getfield_expr(expr)
    elseif expr.head == :(=)
        fieldexpr, val = expr.args
        return :($(getfield_expr(fieldexpr)) = $val)
    else
        throw(
            ArgumentError("Expression of the form $expr not allowed. Try a.key, or a.key=value")
        )
    end
end
