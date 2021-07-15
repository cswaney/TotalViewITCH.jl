using Revise
using Pkg
Pkg.activate(".")
using TotalViewITCH
using Dates

file = "./data/bin/S031413-v41.txt"
version = "4.1"
date = Date("2013-03-14")
nlevels = 3
tickers = ["ALT"]
dir = "./data"

open(file, "r") do io
    clock = 0
    for _ in 1:10
        message_size = TotalViewITCH.get_message_size(io)
        @info "message_size=$message_size"
        message_type = TotalViewITCH.get_message_type(io)
        @info "message_type=$message_type"
        message = TotalViewITCH.get_message(
            io,
            message_size,
            message_type,
            date,
            clock,
            version
        )
        @info "message=$message"
    end
end



message_size = TotalViewITCH.get_message_size(io)
message_type = TotalViewITCH.get_message_type(io)
payload = TotalViewITCH.unpack(io, "I") # [0x000054f6]::Vector{UInt32}
Int(payload[1]) # 21750

message_size = TotalViewITCH.get_message_size(io)
message_type = TotalViewITCH.get_message_type(io)
payload = TotalViewITCH.unpack(io, "Is") # [0x16ff7604, "O"]::Vector{Any}
Int(payload[1]) # 385840644

message_size = TotalViewITCH.get_message_size(io)
message_type = TotalViewITCH.get_message_type(io)
read(io, message_size - 1)