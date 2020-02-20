using Test

function (≜)(a::T, b::T) where {T}
    fields = fieldnames(T)
    bools = [getfield(a, f) == getfield(b, f) for f in fields]
    return all(bools)
end

include("messages.jl")
include("orderbooks.jl")
# include("process.jl")
# include("database.jl")
