"""
    Parser
...

### Details
...

### Example
```julia
parser = Parser{MongoDB}("mongodb://localhost:27017")
parser("data/bin/S022717-v50.txt", ["A"]; date=Date("2017-02-27"), version=5.1)
```
"""
struct Parser{T<:Backend}
    backend::T
end

Parser{T}(url::String) where {T<:Backend} = Parser(T(url))

function (parser::Parser{T})(file::String, date::Date, tickers::Vector{String}, version::AbstractFloat; nlevels::Int=5, buffer_size::Int=10_000) where {T<:Backend}

    version = ITCHVersion{version}()

    success = check_exists(parser.backend)
    !success && ErrorException("Unable to connect to backend.")

    duplicate_tickers = filter(t -> check_exists(date, t, parser.backend), tickers)
    if length(duplicate_tickers) > 0
        resp = input("Found order messages for the following tickers: $duplicate_tickers\n. Do you want to replace data for these tickers? (Y/n)")
        if lowercase(resp) == "y"
            for ticker in duplicate_tickers
                @info "Cleaning up ticker: $ticker"
                clean(date, ticker, parser.backend)
            end
        else
            tickers = setdiff(tickers, duplicates_tickers)
            if length(tickers) == 0 
                println("No new tickers found. Exiting.")
            else
                println("Processing data for new tickers: $tickers")
            end
        end
    end
 
    orders = Dict{Int,Order}()
    books = Dict([t => Book(t, nlevels) for t in tickers])
    messages_buffer = Buffer{T,OrderMessage}(tickers, parser.backend, "messages", date, buffer_size)
    trades_buffer = Buffer{T,TradeMessage}(tickers, parser.backend, "trades", date, buffer_size)
    noii_buffer = Buffer{T,NOIIMessage}(tickers, parser.backend, "noii", date, buffer_size)
    orderbooks_buffer = Buffer{T,Book}(tickers, parser.backend, "orderbooks", date, buffer_size)

    @info "Reading bytes..."
    t = @elapsed io = IOBuffer(read(open(file, "r"))) # read entire file -> Vector{UInt8}
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
                @debug "TIME=$(clock)"
            end
            continue
        end

        # update system
        if message.type == 'S'
            @debug "SYSTEM MESSAGE: $(message.event)"
            if message.event == 'C'  # end of messages
                reading = false
            end
            continue
        elseif message.type == 'H'
            if message.ticker in tickers
                @debug "TRADE MESSAGE ($(message.ticker): $(message.event))"
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
            if message.ticker in tickers
                @debug "ORDER MESSAGE: $(message)"
                del_message, add_message = split_message(message)
                complete_delete_message!(del_message, orders)
                complete_replace_add_message!(add_message, orders)
                write(messages_buffer, message)
                message_writes += 1
                update!(orders, del_message)
                update!(books[message.ticker], del_message)
                add!(orders, add_message)
                update!(books[message.ticker], add_message)
                write(orderbooks_buffer, books[message.ticker]) # only save combined book update
            end
        elseif message.type in ['E', 'C', 'X']
            complete_execute_cancel_message!(message, orders)
            if message.ticker in tickers
                @debug "ORDER MESSAGE: $(message)"
                write(messages_buffer, message)
                message_writes += 1
                update!(orders, message)
                update!(books[message.ticker], message)
                write(orderbooks_buffer, books[message.ticker])
            end
        elseif message.type == 'D'
            complete_delete_message!(message, orders)
            if message.ticker in tickers
                @debug "ORDER MESSAGE: $(message)"
                write(messages_buffer, message)
                message_writes += 1
                update!(orders, message)
                update!(books[message.ticker], message)
                write(orderbooks_buffer, books[message.ticker])
            end
        elseif message.type in ['A', 'F']
            if message.ticker in tickers
                @debug "ORDER MESSAGE: $(message)"
                write(messages_buffer, message)
                message_writes += 1
                add!(orders, message)
                update!(books[message.ticker], message)
                write(orderbooks_buffer, books[message.ticker])
            end
        elseif message.type == 'P'
            # TODO
            @info "TRADE MESSAGE: $(message)"
            # if message.ticker in tickers
            #     push!(trades[message.ticker], to_csv(message))
            #     trade_writes += 1
            # end
        elseif message.type in ['Q', 'I']
            # TODO
            @info "NOII MESSAGE: $(message)"
            # if message.ticker in tickers
            #     push!(imbalances[message.ticker], to_csv(message))
            #     noii_writes += 1
            # end
        end

        if message_reads % 10_000_000 == 0
            elapsed_time = time() - start
            @info "Progress: $(io.ptr / length(io.data) * 100)% (elapsed: $(elapsed_time), messages: $message_reads, speed: $(message_reads / elapsed_time) msg/sec)"
        end

    end

    # clean up
    @info "Cleaning up..."
    flush(messages_buffer)
    flush(trades_buffer)
    flush(noii_buffer)
    flush(orderbook_buffer)

    stop = time()
    elapsed_time = stop - start
    @info "\n** FINISHED **"
    @info "Elapsed time: $(elapsed_time)"
    @info "Messages read: $(message_reads)"
    @info "Messages written: $(message_writes)"
    @info "NOII written: $(noii_writes)"
    @info "Trades written: $(trade_writes)"
end


using BitIntegers
@define_integers 48

BUFFER_SIZE = 10 ^ 4
REPORT_FREQ = 1800

read_string(io::IO, n) = rstrip(String(read(io, n)), ' ')
read_uint48(io) = Int(ntoh(read(io, UInt48)))

struct ITCHVersion{N} end

function get_trade_message(io, date, sec, version::ITCHVersion{4.1})
    nano = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # refno
    side = Char(read(io, Char))
    shares = Int(ntoh(read(io, UInt32)))
    ticker = rstrip(String(read(io, 8)), ' ')
    price = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # matchno
    return TradeMessage(date, sec, nano, 'P', ticker, side, price, shares)
end

function get_trade_message(io, date, sec, version::ITCHVersion{5.0})
    read(io, 2) # stock locate == 0
    read(io, 2) # tracking number
    nano = read_uint48(io)
    _ = Int(ntoh(read(io, UInt64))) # refno
    side = Char(read(io, Char))
    shares = Int(ntoh(read(io, UInt32)))
    ticker = rstrip(String(read(io, 8)), ' ')
    price = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # matchno
    return TradeMessage(date, sec, nano, 'P', ticker, side, price, shares)
end

function get_noii_message(io, date, sec, version::ITCHVersion{4.1})
    nano = Int(ntoh(read(io, UInt32)))
    paired = Int(ntoh(read(io, UInt64)))
    imbalance = Int(ntoh(read(io, UInt64)))
    direction = Char(read(io, Char))
    ticker = rstrip(String(read(io, 8)), ' ')
    far = Int(ntoh(read(io, UInt32)))
    near = Int(ntoh(read(io, UInt32)))
    current = Int(ntoh(read(io, UInt32)))
    cross = Char(read(io, Char))
    _ = Char(read(io, Char)) # indicator
    return NOIIMessage(date, sec, nano, 'I', ticker, paired, imbalance, direction, far, near, current, cross)
end

function get_noii_message(io, date, sec, version::ITCHVersion{5.0})
    read(io, 2) # stock locate == 0
    read(io, 2) # tracking number
    nano = read_uint48(io)
    paired = Int(ntoh(read(io, UInt64)))
    imbalance = Int(ntoh(read(io, UInt64)))
    direction = Char(read(io, Char))
    ticker = rstrip(String(read(io, 8)), ' ')
    far = Int(ntoh(read(io, UInt32)))
    near = Int(ntoh(read(io, UInt32)))
    current = Int(ntoh(read(io, UInt32)))
    cross = Char(read(io, Char))
    _ = Char(read(io, Char)) # indicator
    return NOIIMessage(date, sec, nano, 'I', ticker, paired, imbalance, direction, far, near, current, cross)
end

function get_timestamp_message(io, date, version::ITCHVersion{4.1})
    sec = Int(ntoh(read(io, UInt32)))
    return TimestampMessage(date, sec)
end

function get_system_event_message(io, date, sec, version::ITCHVersion{4.1})
    nano = Int(ntoh(read(io, UInt32)))
    event = Char(read(io, Char))
    return SystemEventMessage(date, sec, nano, event)
end

function get_system_event_message(io, date, sec, version::ITCHVersion{5.0})
    read(io, 2) # stock locate == 0
    read(io, 2) # tracking number
    nano = read_uint48(io)
    event = Char(read(io, Char))
    return SystemEventMessage(date, sec, nano, event)
end

function get_trade_action_message(io, date, sec, version::ITCHVersion{4.1})
    nano = Int(ntoh(read(io, UInt32)))
    ticker = read_string(io, 8)
    event = Char(read(io, Char))
    read(io, Char)
    read_string(io, 4)
    return TradeActionMessage(date, sec, nano, ticker, event)
end

function get_trade_action_message(io, date, sec, version::ITCHVersion{5.0})
    read(io, 2)
    read(io, 2)
    nano = read_uint48(io)
    ticker = read_string(io, 8)
    event = Char(read(io, Char))
    read(io, Char)
    read_string(io, 4)
    return TradeActionMessage(date, sec, nano, ticker, event)
end

function get_add_message(io, date, sec, version::ITCHVersion{4.1})
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    side = Char(read(io, Char))
    shares = Int(ntoh(read(io, UInt32)))
    ticker = read_string(io, 8)
    price = Int(ntoh(read(io, UInt32)))
    return AddMessage(date, sec, nano, refno, ticker, side, price, shares)
end

function get_add_message(io, date, sec, version::ITCHVersion{5.0})
    read(io, 2)
    read(io, 2)
    nano = read_uint48(io)
    refno = Int(ntoh(read(io, UInt64)))
    side = Char(read(io, Char))
    shares = Int(ntoh(read(io, UInt32)))
    ticker = read_string(io, 8)
    price = Int(ntoh(read(io, UInt32)))
    return AddMessage(date, sec, nano, refno, ticker, side, price, shares)
end

function get_add_mpid_message(io, date, sec, version::ITCHVersion{4.1})
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    side = Char(read(io, Char))
    shares = Int(ntoh(read(io, UInt32)))
    ticker = read_string(io, 8)
    price = Int(ntoh(read(io, UInt32)))
    mpid = read_string(io, 4)
    return AddMessage(date, sec, nano, refno, ticker, side, price, shares; type='F', mpid=mpid)
end

function get_add_mpid_message(io, date, sec, version::ITCHVersion{5.0})
    read(io, 2)
    read(io, 2)
    nano = read_uint48(io)
    refno = Int(ntoh(read(io, UInt64)))
    side = Char(read(io, Char))
    shares = Int(ntoh(read(io, UInt32)))
    ticker = read_string(io, 8)
    price = Int(ntoh(read(io, UInt32)))
    mpid = read_string(io, 4)
    return AddMessage(date, sec, nano, refno, ticker, side, price, shares; type='F', mpid=mpid)
end

function get_execute_message(io, date, sec, version::ITCHVersion{4.1})
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    shares = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # matchno
    return ExecuteMessage(date, sec, nano, refno, shares)
end

function get_execute_message(io, date, sec, version::ITCHVersion{5.0})
    read(io, 2)
    read(io, 2)
    nano = read_uint48(io)
    refno = Int(ntoh(read(io, UInt64)))
    shares = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # matchno
    return ExecuteMessage(date, sec, nano, refno, shares)
end

function get_execute_price_message(io, date, sec, version::ITCHVersion{4.1})
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    shares = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # matchno
    _ = Char(read(io, Char)) # printable
    price = Int(ntoh(read(io, UInt32)))
    return ExecuteMessage(date, sec, nano, refno, shares, type='C', price=price)
end

function get_execute_price_message(io, date, sec, version::ITCHVersion{5.0})
    read(io, 2)
    read(io, 2)
    nano = read_uint48(io)
    refno = Int(ntoh(read(io, UInt64)))
    shares = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # matchno
    _ = Char(read(io, Char)) # printable
    price = Int(ntoh(read(io, UInt32)))
    return ExecuteMessage(date, sec, nano, refno, shares, type='C', price=price)
end

function get_cancel_message(io, date, sec, version::ITCHVersion{4.1})
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    shares = Int(ntoh(read(io, UInt32)))
    return CancelMessage(date, sec, nano, refno, shares)
end

function get_cancel_message(io, date, sec, version::ITCHVersion{5.0})
    read(io, 2)
    read(io, 2)
    nano = read_uint48(io)
    refno = Int(ntoh(read(io, UInt64)))
    shares = Int(ntoh(read(io, UInt32)))
    return CancelMessage(date, sec, nano, refno, shares)
end

function get_delete_message(io, date, sec, version::ITCHVersion{4.1})
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    return DeleteMessage(date, sec, nano, refno)
end

function get_delete_message(io, date, sec, version::ITCHVersion{5.0})
    read(io, 2)
    read(io, 2)
    nano = read_uint48(io)
    refno = Int(ntoh(read(io, UInt64)))
    return DeleteMessage(date, sec, nano, refno)
end

function get_replace_message(io, date, sec, version::ITCHVersion{4.1})
    nano = Int(ntoh(read(io, UInt32)))
    refno = Int(ntoh(read(io, UInt64)))
    newrefno = Int(ntoh(read(io, UInt64)))
    shares = Int(ntoh(read(io, UInt32)))
    price = Int(ntoh(read(io, UInt32)))
    return ReplaceMessage(date, sec, nano, refno, newrefno, shares, price)
end

function get_replace_message(io, date, sec, version::ITCHVersion{5.0})
    read(io, 2)
    read(io, 2)
    nano = read_uint48(io)
    refno = Int(ntoh(read(io, UInt64)))
    newrefno = Int(ntoh(read(io, UInt64)))
    shares = Int(ntoh(read(io, UInt32)))
    price = Int(ntoh(read(io, UInt32)))
    return ReplaceMessage(date, sec, nano, refno, newrefno, shares, price)
end

function get_cross_trade_message(io, date, sec, version::ITCHVersion{4.1})
    nano = Int(ntoh(read(io, UInt32)))
    shares = Int(ntoh(read(io, UInt64)))
    ticker = read_string(io, 8)
    price = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # matchno
    event = Char(read(io, Char))
    return CrossTradeMessage(date, sec, nano, shares, ticker, price, event)
end

function get_cross_trade_message(io, date, sec, version::ITCHVersion{5.0})
    read(io, 2)
    read(io, 2)
    nano = read_uint48(io)
    shares = Int(ntoh(read(io, UInt64)))
    ticker = read_string(io, 8)
    price = Int(ntoh(read(io, UInt32)))
    _ = Int(ntoh(read(io, UInt64))) # matchno
    event = Char(read(io, Char))
    return CrossTradeMessage(date, sec, nano, shares, ticker, price, event)
end

get_message_size(io) = Int(ntoh(read(io, UInt16)))
get_message_type(io) = Char(read(io, Char))

function get_message_body(io, size, type, date, sec, version::ITCHVersion)
    if type == 'T'
        return get_timestamp_message(io, date, version)
    elseif type == 'S'
        return get_system_event_message(io, date, sec, version)
    elseif type == 'H'
        return get_trade_action_message(io, date, sec, version)
    elseif type == 'A'
        return get_add_message(io, date, sec, version)
    elseif type == 'F'
        return get_add_mpid_message(io, date, sec, version)
    elseif type == 'E'
        return get_execute_message(io, date, sec, version)
    elseif type == 'C'
        return get_execute_price_message(io, date, sec, version)
    elseif type == 'X'
        return get_cancel_message(io, date, sec, version)
    elseif type == 'D'
        return get_delete_message(io, date, sec, version)
    elseif type == 'U'
        return get_replace_message(io, date, sec, version)
    elseif type == 'Q'
        return get_cross_trade_message(io, date, sec, version)
    elseif type == 'P'
        return get_trade_message(io, date, sec, version)
    elseif type == 'I'
        return get_noii_message(io, date, sec, version)
    else
        read(io, size - 1)
        @debug "WARNING: unable to get message body (unsupported message type $(type))."
        return nothing
    end
end

function get_message(io, date, clock, version::ITCHVersion)
    message_size = get_message_size(io)
    message_type = get_message_type(io)
    message = get_message_body(io, message_size, message_type, date, clock, version)
    return message
end
