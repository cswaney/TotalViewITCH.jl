using Revise
using Pkg
Pkg.activate(".")
using TotalViewITCH
using Dates

file = "/Users/colinswaney/Data/ITCH/bin/S031413-v41.txt"
version = 4.1
date = Date("2013-03-14")
nlevels = 3
tickers = ["AAPL", "GOOG"]
dir = "/Users/colinswaney/Desktop/test"
process(file, version, date, nlevels, tickers, dir)

# io = open(file, "r")
# for i in 1:100000
#     message_size = get_message_size(io)
#     message_type = get_message_type(io)
#     message = get_message(
#         io,
#         message_size,
#         message_type,
#         date,
#         0,
#         version
#     )
#     if message != nothing
#         println(message)
#     end
# end
# process(file, version, date, nlevels, names, path)
