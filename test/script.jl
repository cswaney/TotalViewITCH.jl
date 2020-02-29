"""
Read a binary data file and write message and order book data to file.

# Arguments
- `file`: location of file to read.
- `version`: ITCH version number.
- `date`: date to associate with output.
- `nlevels`: number of order book levels to track.
- `tickers`: stock tickers to track.
- `dir`: location to write output.
"""
using Revise
using Pkg
Pkg.activate(".")
using TotalViewITCH
using Dates

const TYPES = ["T", "S", "H", "A", "F", "E", "C", "X", "D", "U", "P", "Q", "I"]

build(dir)

BUFFER_SIZE = 10 ^ 4

orders = Dict{Int,Order}()
books = create_books(tickers, nlevels)
snapshots, messages, trades, imbalances = create_recorders(tickers, dir, BUFFER_SIZE)

io = open(file, "r")
message_reads = 0
message_writes = 0
noii_writes = 0
trade_writes = 0
reading = true
clock = 0
start = time()

while reading

    # read message
    message_size = get_message_size(io)
    message_type = get_message_type(io)
    message = get_message(
        io,
        message_size,
        message_type,
        date,
        clock,
        version
    )
    message_reads += 1

    message == nothing && continue  # ignored message type

    # update clock
    if message.type == "T"
        clock = message.sec
        if clock % 1800 == 0
            @info "TIME=$(clock)"
        end
    end

    # update system
    if message.type == "S"
        @info "SYSTEM MESSAGE: $(message.event)"
        if message.event == "C"  # end of messages
            reading = false
        end
    elseif message.type == "H"
        if message.name in tickers
            @info "TRADE MESSAGE ($(message.name): $(message.event))"
            if message.event == "H"  # halted (all US)
                # TODO
            elseif message.event == "P"  # paused (all US)
                # TODO
            elseif message.event == "Q"  # quotation only
                # TODO
            elseif message.event == "T"  # trading on nasdaq
                # TODO
            end
        end
    end

    # complete message
    if message.type == "U"
        message, del_message, add_message = split(message)
        complete!(message, orders)
        complete!(del_message, orders)
        complete!(add_message, orders)
        if message.name in tickers
            @info "message: $(message)"
            push!(messages[message.name], to_csv(message))
            message_writes += 1
            update!(orders, del_message)
            update!(books[message.name], del_message)
            push!(snapshots[message.name], to_csv(books[message.name]))
            add!(orders, add_message)
            update!(books[message.name], add_message)
            push!(snapshots[message.name], to_csv(books[message.name]))
        end
    elseif message.type in ["E", "C", "X", "D"]
        complete!(message, orders)
        if message.name in tickers
            @info "message: $(message)"
            push!(messages[message.name], to_csv(message))
            message_writes += 1
            update!(orders, message)
            update!(books[message.name], message)
            push!(snapshots[message.name], to_csv(books[message.name]))
        end
    elseif message.type in ["A", "F"]
        if message.name in tickers
            @info "message: $(message)"
            push!(messages[message.name], to_csv(message))
            message_writes += 1
            add!(orders, message)
            update!(books[message.name], message)
            push!(snapshots[message.name], to_csv(books[message.name]))
        end
    elseif message.type == "P"
        # TODO
        # @info "trade message: $(message)"
        # if message.name in tickers
        #     push!(trades[message.name], to_csv(message))
        #     trade_writes += 1
        # end
    elseif message.type in ["Q", "I"]
        # TODO
        # @info "imbalance message: $(message)"
        # if message.name in tickers
        #     push!(imbalances[message.name], to_csv(message))
        #     noii_writes += 1
        # end
    end

end

# clean up
@info "Cleaning up..."
for name in tickers
    write(snapshots[name])
    write(messages[name])
    write(trades[name])
    write(imbalances[name])
end

stop = time()
elapsed_time = stop - start
@info "Elapsed time: $(elapsed_time)"
@info "Messages read: $(message_reads)"
@info "Messages written: $(message_writes)"
@info "NOII written: $(noii_writes)"
@info "Trades written: $(trade_writes)"
