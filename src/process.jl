# TODO: Check that no bytes are skipped—should read entire format string even if not used!

BUFFER_SIZE = 10 ^ 4
REPORT_FREQ = 1800

read_string(io::IO, n) = rstrip(String(read(io, n)), ' ' )

function get_trade_message(io, date, sec)
    nano = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # refno
    side = Char(read(io, Char))
    shares = Int(ntoh(read(io, UInt32)))
    name = rstrip(String(read(io, 8)), ' ')
    price = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # matchno
    return TradeMessage(date, sec, nano, 'P', name, side, price, shares)
end

function get_noii_message(io, date, sec)
    nano = Int(ntoh(read(io, UInt32)))
    paired = Int(ntoh(read(io, UInt64)))
    imbalance = Int(ntoh(read(io, UInt64)))
    direction = Char(read(io, Char))
    name = rstrip(String(read(io, 8)), ' ')
    far = Int(ntoh(read(io, UInt32)))
    near = Int(ntoh(read(io, UInt32)))
    current = Int(ntoh(read(io, UInt32)))
    cross = Char(read(io, Char))
    _ = Char(read(io, Char)) # indicator
    return NOIIMessage(date, sec, nano, 'I', name, paired, imbalance, direction, far, near, current, cross)
end

function get_timestamp_message(io, date)
    sec = Int(ntoh(read(io, UInt32)))
    return TimestampMessage(date, sec)
end

function get_system_event_message(io, date, sec)
    nano = Int(ntoh(read(io, UInt32)))
    event = Char(read(io, Char))
    return SystemEventMessage(date, sec, nano, event)
end

function get_trade_action_message(io, date, sec)
    nano = Int(ntoh(read(io, UInt32)))
    name = read_string(io, 8)
    event = Char(read(io, Char))
    read(io, Char)
    read_string(io, 4)
    return TradeActionMessage(date, sec, nano, name, event)
end

function get_add_message(io, date, sec)
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    side = Char(read(io, Char))
    shares = Int(ntoh(read(io, UInt32)))
    name = read_string(io, 8)
    price = Int(ntoh(read(io, UInt32)))
    return AddMessage(date, sec, nano, refno, name, side, price, shares)
end

function get_add_mpid_message(io, date, sec)
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    side = Char(read(io, Char))
    shares = Int(ntoh(read(io, UInt32)))
    name = read_string(io, 8)
    price = Int(ntoh(read(io, UInt32)))
    mpid = read_string(io, 4)
    return AddMessage(date, sec, nano, refno, name, side, price, shares; type='F', mpid=mpid)
end

function get_execute_message(io, date, sec)
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    shares = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # matchno
    return ExecuteMessage(date, sec, nano, refno, shares)
end

function get_execute_price_message(io, date, sec)
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    shares = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # matchno
    _ = Char(read(io, Char)) # printable
    price = Int(ntoh(read(io, UInt32)))
    return ExecuteMessage(date, sec, nano, refno, shares, type='C', price=price)
end

function get_cancel_message(io, date, sec)
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    shares = Int(ntoh(read(io, UInt32)))
    return CancelMessage(date, sec, nano, refno, shares)
end

function get_delete_message(io, date, sec)
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    return DeleteMessage(date, sec, nano, refno)
end

function get_replace_message(io, date, sec)
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    newrefno = Int(ntoh(read(io, UInt64)))
    shares = Int(ntoh(read(io, UInt32)))
    price = Int(ntoh(read(io, UInt32)))
    return ReplaceMessage(date, sec, nano, refno, newrefno, shares, price)
end

function get_cross_trade_message(io, date, sec)
    nano = Int(ntoh(read(io, UInt32)))
    shares = Int(ntoh(read(io, UInt64)))
    name = read_string(io, 8)
    price = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # matchno
    event = Char(read(io, Char))
    return CrossTradeMessage(date, sec, nano, shares, name, price, event)
end

get_message_size(io) = Int(ntoh(read(io, UInt16)))
get_message_type(io) = Char(read(io, Char))

function get_message_body(io, size, type, date, sec, version)
    if version == "4.1"
        if type == 'T'
            return get_timestamp_message(io, date)
        elseif type == 'S'
            return get_system_event_message(io, date, sec)
        elseif type == 'H'
            return get_trade_action_message(io, date, sec)
        elseif type == 'A'
            return get_add_message(io, date, sec)
        elseif type == 'F'
            return get_add_mpid_message(io, date, sec)
        elseif type == 'E'
            return get_execute_message(io, date, sec)
        elseif type == 'C'
            return get_execute_price_message(io, date, sec)
        elseif type == 'X'
            return get_cancel_message(io, date, sec)
        elseif type == 'D'
            return get_delete_message(io, date, sec)
        elseif type == 'U'
            return get_replace_message(io, date, sec)
        elseif type == 'Q'
            return get_cross_trade_message(io, date, sec)
        elseif type == 'P'
            return get_trade_message(io, date, sec)
        elseif type == 'I'
            return get_noii_message(io, date, sec)
        else
            read(io, size - 1)
            @warn "Unable to get message body (unsupported message type $(type))."
            return nothing
        end
    elseif version == "5.0"
        throw(ErrorException("Invalid version.\n\n Version $(version) is not currently supported."))
    else
        throw(ArgumentError("Invalid version $(version)"))
    end
end

function get_message(io, date, clock, version)
    message_size = TotalViewITCH.get_message_size(io)
    message_type = TotalViewITCH.get_message_type(io)
    message = TotalViewITCH.get_message_body(io, message_size, message_type, date, clock, version)
    return message
end

"""process(file, version, date, nlevels, tickers, path)

Read a binary data file and write message and order book data to file.

# Arguments
- `file`: location of file to read.
- `version`: ITCH version number (4.1 or 5.0).
- `date`: `Date` to associate with output.
- `nlevels`: number of order book levels to track.
- `tickers`: stock tickers to track.
- `dir`: location to write output.
"""
function process(file, version, date, nlevels, tickers, dir)

    success = build(dir)
    !success && return

    orders = Dict{Int,Order}()
    books = create_books(tickers, nlevels)
    snapshots, messages, trades, imbalances = create_recorders(tickers, dir, BUFFER_SIZE)

    @info "Reading bytes..."
    io = open(file, "r")
    t = @elapsed io = IOBuffer(read(io)) # read entire file -> Vector{UInt8}
    @info "done (elapsed: $(t))"
    message_reads = 0
    message_writes = 0
    noii_writes = 0
    trade_writes = 0
    reading = true
    clock = 0
    start = time()
    while reading

        # read message
        message = get_message(io, date, clock, version)
        message_reads += 1
        isnothing(message) && continue  # ignored message type

        # update clock
        if message.type == 'T'
            clock = message.sec
            if clock % REPORT_FREQ == 0
                @info "TIME=$(clock)"
                elapsed_time = time() - start
                @info "(messages_read=$(message_reads), elapsed_time=$(elapsed_time), rate=$(message_reads / elapsed_time) (msg/sec)"
            end
            continue
        end

        # update system
        if message.type == 'S'
            @info "SYSTEM MESSAGE: $(message.event)"
            if message.event == 'C'  # end of messages
                reading = false
            end
            continue
        elseif message.type == 'H'
            if message.name in tickers
                @info "TRADE MESSAGE ($(message.name): $(message.event))"
                if message.event == 'H'  # halted (all US)
                    # TODO
                elseif message.event == 'P'  # paused (all US)
                    # TODO
                elseif message.event == 'Q'  # quotation only
                    # TODO
                elseif message.event == 'T'  # trading on nasdaq
                    # TODO
                end
            end
            continue
        end

        # complete message
        if message.type == 'U'
            complete_replace_message!(message, orders)
            if message.name in tickers
                @info "message: $(message)"
                del_message, add_message = split_message(message)
                complete_delete_message!(del_message, orders)
                complete_replace_add_message!(add_message, orders)
                push!(messages[message.name], to_csv(message))
                message_writes += 1
                update!(orders, del_message)
                update!(books[message.name], del_message)
                add!(orders, add_message)
                update!(books[message.name], add_message)
                push!(snapshots[message.name], to_csv(books[message.name])) # only save combined book update
            end
        elseif message.type in ['E', 'C', 'X']
            complete_execute_cancel_message!(message, orders)
            if message.name in tickers
                @info "message: $(message)"
                push!(messages[message.name], to_csv(message))
                message_writes += 1
                update!(orders, message)
                update!(books[message.name], message)
                push!(snapshots[message.name], to_csv(books[message.name]))
            end
        elseif message.type == 'D'
            complete_delete_message!(message, orders)
            if message.name in tickers
                @info "message: $(message)"
                push!(messages[message.name], to_csv(message))
                message_writes += 1
                update!(orders, message)
                update!(books[message.name], message)
                push!(snapshots[message.name], to_csv(books[message.name]))
            end
        elseif message.type in ['A', 'F']
            if message.name in tickers
                @info "message: $(message)"
                push!(messages[message.name], to_csv(message))
                message_writes += 1
                add!(orders, message)
                update!(books[message.name], message)
                push!(snapshots[message.name], to_csv(books[message.name]))
            end
        elseif message.type == 'P'
            # TODO
            # @info "trade message: $(message)"
            # if message.name in tickers
            #     push!(trades[message.name], to_csv(message))
            #     trade_writes += 1
            # end
        elseif message.type in ['Q', 'I']
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
    @info "\n** FINISHED **"
    @info "Elapsed time: $(elapsed_time)"
    @info "Messages read: $(message_reads)"
    @info "Messages written: $(message_writes)"
    @info "NOII written: $(noii_writes)"
    @info "Trades written: $(trade_writes)"
end

function create_books(tickers, nlevels)
    books = Dict{String,Book}()
    for name in tickers
        books[name] = Book(name, nlevels)
    end
    return books
end

function create_recorders(tickers, dir, buffer_size = BUFFER_SIZE)
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
