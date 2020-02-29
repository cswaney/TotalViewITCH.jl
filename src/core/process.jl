const TYPES = ["T", "S", "H", "A", "F", "E", "C", "X", "D", "U", "P", "Q", "I"]

get_message_size(io) = Int(unpack(io, "H")[1])

get_message_type(io) = String(unpack(io, "s")[1])

function get_message(io, size, type, date, time, version)
    if type in TYPES
        return unpack_message_payload(io, type, date, time, version)
    else
        skipbytes(io, size - 1)
    end
end


"""
unpack_message_payload(message_bytes, type, time, version)

Unpack binary message data and return an out-going message.
"""
function unpack_message_payload(io, type, date, time, version)
    if type == "P"  # trade
        message = TradeMessage(date, type = type)
        payload = unpack(io, "IQsI8sIQ")
        message.sec = time
        message.nano = Int(payload[1])
        # message.refno = Int(payload[2])
        message.side = String(payload[3])
        message.shares = Int(payload[4])
        message.name = rstrip(String(payload[5]), ' ')
        message.price = Int(payload[6])
        return message
    elseif type == "I"  # imbalance
        message = NOIIMessage(date, type = type)
        payload = unpack(io, "IQQs8sIIIss")
        message.sec = time
        message.nano = Int(payload[1])
        message.paired = Int(payload[2])
        message.imbalance = Int(payload[3])
        message.direction = String(payload[4])
        message.name = rstrip(String(payload[5]), ' ')
        message.far = Int(payload[6])
        message.near = Int(payload[7])
        message.current = Int(payload[8])
        message.cross = String(payload[9])
        return message
    else  # message
        message = Message(date, type = type)
        if type == "T"  # time
            payload = unpack(io, "I")
            message.sec = Int(payload[1])
            message.nano = 0
        elseif type == "S"  # systems
            payload = unpack(io, "Is")
            message.sec = time
            message.nano = Int(payload[1])
            message.name = "."
            message.event = String(payload[2])
        elseif type == "H"  # trade action
            payload = unpack(io, "I8sss4s")
            message.sec = time
            message.nano = Int(payload[1])
            message.name = rstrip(String(payload[2]), ' ')
            message.event = String(payload[3])
        elseif type == "A"  # add
            payload = unpack(io, "IQsI8sI")
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
            message.side = String(payload[3])
            message.shares = Int(payload[4])
            message.name = rstrip(String(payload[5]), ' ')
            message.price = Int(payload[6])
        elseif type == "F"  # add w/ MPID
            payload = unpack(io, "IQsI8sI4s")
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
            message.side = String(payload[3])
            message.shares = Int(payload[4])
            message.name = rstrip(String(payload[5]), ' ')
            message.price = Int(payload[6])
            message.mpid = rstrip(String(payload[7]), ' ')
        elseif type == "E"  # execute
            payload = unpack(io, "IQIQ")
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
            message.shares = Int(payload[3])
        elseif type == "C"  # execute w/ price
            payload = unpack(io, "IQIQsI")
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
            message.shares = Int(payload[3])
            message.price = Int(payload[6])
        elseif type == "X"  # cancel
            payload = unpack(io, "IQI")
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
            message.shares = Int(payload[3])
        elseif type == "D"  # delete
            payload = unpack(io, "IQ")
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
        elseif type == "U"  # replace
            payload = unpack(io, "IQQII")
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
            message.newrefno = Int(payload[3])
            message.shares = Int(payload[4])
            message.price = Int(payload[5])
        elseif type == "Q"  # cross-trade
            payload = unpack(io, "IQ8sIQs")
            message.sec = time
            message.nano = Int(payload[1])
            message.shares = Int(payload[2])
            message.name = rstrip(String(payload[3]), ' ')
            message.price = Int(payload[4])
            message.event = String(payload[6])
        end
        return message
    end
end


"""
unpack(s::IOStream, fmt::String)

Unpack a stream of binary data according to the given format. Equivalent to `struct.unpack` in Python.

# Format Strings
Symbol      Julia Type      Bytes
'c'         Char            1
'b'         Int8            1
'B'         UInt8           1
'h'         Int16           2
'H'         UInt16          2
'i'         Int32           4
'I'         UInt32          4
'q'         Int64           8
'Q'         UInt64          8
's'         String          Defined by preceeding integer (e.g., '4s')
"""
function unpack(s::IOStream, fmt::String)
    list = []
    idx = 1
    n = 1
    while idx <= length(fmt)
        value = fmt[idx]
        type = typeof(tryparse(Int, string(value)))
        if type == Int64
            n = tryparse(Int, string(value))
        else
            symbol = Char(value)
            # println("symbol=$symbol, n=$n")
            append!(list, readbytes(s, symbol, n))
            n = 1
        end
        idx += 1
    end
    return list
end

function skipbytes(s::IOStream, n)
    read(s, n)
    return
end

function readbytes(s::IOStream, symbol)
    if symbol == 'c'
        return read(s, Char)
    elseif symbol == 'b'
        return ntoh(read(s, Int8))
    elseif symbol == 'B'
        return ntoh(read(s, UInt8))
    elseif symbol == 'h'
        return ntoh(read(s, Int16))
    elseif symbol == 'H'
        return ntoh(read(s, UInt16))
    elseif symbol == 'i'
        return ntoh(read(s, Int32))
    elseif symbol == 'I'
        return ntoh(read(s, UInt32))
    elseif symbol == 'q'
        return ntoh(read(s, Int64))
    elseif symbol == 'Q'
        return ntoh(read(s, UInt64))
    elseif symbol == 's'
        return read(s, Char)
    end
end

function readbytes(s::IOStream, symbol, n)
    list = []
    for i in 1:n
        push!(list, readbytes(s, symbol))
    end
    if symbol == 's'
        return [string(list...)]
    else
        return list
    end
end


"""
`process(file, version, date, nlevels, tickers, path)`

Read a binary data file and write message and order book data to file.

# Arguments
- `file`: location of file to read.
- `version`: ITCH version number.
- `date`: date to associate with output.
- `nlevels`: number of order book levels to track.
- `tickers`: stock tickers to track.
- `dir`: location to write output.
"""
function process(file, version, date, nlevels, tickers, dir)

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

    # progress = Juno.Progress(59400 - 25200, 1)   # minimum update interval: 1 second

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
                reading = False
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

                # ProgressMeter.update!(progress, clock - 25200)

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

                # ProgressMeter.update!(progress, clock - 25200)

                push!(messages[message.name], to_csv(message))
                message_writes += 1
                update!(orders, message)
                update!(books[message.name], message)
                push!(snapshots[message.name], to_csv(books[message.name]))
            end
        elseif message.type in ["A", "F"]
            if message.name in tickers
                @info "message: $(message)"

                # ProgressMeter.update!(progress, clock - 25200)

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

        # TODO: remove (now handled by Recorder)
        # write message
        # if message.type in ["U", "A", "F", "E", "C", "X", "D"]
        #     if message.name in tickers
        #         name = message.name
        #         if length(messages[name]) == BUFFER_SIZE
        #             write(messages, dir = dir, group = "messages", name = name)
        #         end
        #         if length(snapshots[name]) == BUFFER_SIZE
        #             write(snapshots, dir = dir, group = "books", name = name)
        #         end
        #     end
        # elseif message.type == "P"
        #     if message.name in tickers
        #         name = message.name
        #         if length(trades[name]) == BUFFER_SIZE
        #             write(trades, dir = dir, group = "trades", name = name)
        #         end
        #     end
        # elseif message.type in ["Q", "I"]
        #     if message.name in tickers
        #         name = message.name
        #         if length(imbalances[name]) == BUFFER_SIZE
        #             write(imbalances, dir = dir, group = "noii", name = name)
        #         end
        #     end
        # end
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
end

function create_books(tickers, nlevels)
    books = Dict{String,Book}()
    for name in tickers
        books[name] = Book(nlevels, name = name)
    end
    return books
end

function create_recorders(tickers, dir, buffer_size = 10 ^ 4)
    books = Dict{String,Recorder}()
    messages = Dict{String,Recorder}()
    trades = Dict{String,Recorder}()
    imbalances = Dict{String,Recorder}()
    for name in tickers
        file = string(name, ".csv")
        books[name] = Recorder(buffer_size, string(dir, "/books/", file))
        messages[name] = Recorder(buffer_size, string(dir, "/messages/", file))
        trades[name] = Recorder(buffer_size, string(dir, "/trades/", file))
        imbalances[name] = Recorder(buffer_size, string(dir, "/noii/", file))
    end
    return books, messages, trades, imbalances
end
