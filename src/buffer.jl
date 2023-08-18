"""
    Buffer

An abstraction to handle writing parsed data to disk.

Parsed data is written to the buffer and the buffer flushes itself to its backend.
"""
struct Buffer{T<:Backend,S<:Writable}
    data::Dict{String,Vector{S}}
    backend::T
    collection::String
    date::Date
    maxsize::Int
    cnt::Int # number of items flushed
    ptrs::Dict{String,Vector{Int}}
end

function Buffer{T, S}(tickers, backend::T, collection, date, maxsize) where {T<:Backend,S<:Writable}
    data = Dict([t => Vector{S}(undef, maxsize) for t in tickers])
    ptrs = Dict([t => 1 for t in tickers])
    return Buffer{T}(data, backend, collection, date, maxsize, 0, ptrs)
end

function Base.write(b::Buffer, item)
    b.data[item.ticker][b.ptr] = item
    b.ptrs[item.ticker] += 1
    b.ptrs[item.ticker] == b.maxsize + 1 && flush(b, item.ticker)
end

function flush(b::Buffer, ticker)
    b.cnt += insert(b.backend, b.data[ticker][1:(b.ptr - 1)], b.collection, ticker, b.date)
    reset(b, ticker)
end

function flush(b::Buffer)
    for ticker in keys(b.data)
        flush(b, ticker)
    end
end

function reset(b::Buffer, ticker)
    b.ptrs[ticker] = 1
end

function reset(b::Buffer)
    for ticker in keys(b.data)
        reset(b, ticker)
    end
end