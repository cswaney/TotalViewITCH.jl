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
dir = "./data/csv/"

# process(file, version, date, nlevels, tickers, dir)

max_messages = 100000
open(file, "r") do io
    clock = 0
    for _ in 1:max_messages
        message_size = TotalViewITCH.get_message_size(io)
        # @info "message_size=$message_size"
        message_type = TotalViewITCH.get_message_type(io)
        # @info "message_type=$message_type"
        message = TotalViewITCH.get_message(io, message_size, message_type, date, clock, version)
        if !(message_type in ['H', 'R', 'Y', 'L'])
            @info "message_size=$message_size"
            @info "message_type=$message_type"
            @info "message=$message"
        end
        if message_type == 'T'
            clock = message.sec
        end
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