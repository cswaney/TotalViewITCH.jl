module TotalViewITCH

using Dates, ProgressMeter

# include("messages.jl")
include("messages_v41.jl")
# include("orderbooks.jl")
include("orderbooks_v41.jl")
include("database.jl")
# include("process.jl")
include("process_v41.jl")
export process, AbstractMessage, OrderMessage, SystemMessage, NOIIMessage, TradeMessage, Order, Book

end # module
