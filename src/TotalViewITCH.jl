module TotalViewITCH

using Dates, ProgressMeter

function input(prompt)
    println(prompt)
    resp = readline()
    return resp
end

include("messages.jl")
include("orderbooks.jl")
include("backends.jl")
include("buffer.jl")
# include("database.jl")
# include("process.jl")
include("parser.jl")
export build, teardown, AbstractMessage, OrderMessage, SystemMessage, NOIIMessage, TradeMessage, Order, Book, Recorder, Parser

end # module
