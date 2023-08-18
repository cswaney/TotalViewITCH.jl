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

function (parser::Parser{T})(file, date, tickers, version; nlevels=5, buffer_size=10_000) where {T<:Backend}

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
                write(messages_buffer, message)
                message_writes += 1
                del_message, add_message = split_message(message)
                complete_delete_message!(del_message, orders)
                complete_replace_add_message!(add_message, orders)
                update!(orders, del_message)
                update!(books[message.name], del_message)
                add!(orders, add_message)
                update!(books[message.name], add_message)
                write(orderbooks_buffer, books[message.name]) # only save combined book update
            end
        elseif message.type in ['E', 'C', 'X']
            complete_execute_cancel_message!(message, orders)
            if message.name in tickers
                @info "message: $(message)"
                write(messages_buffer, message)
                message_writes += 1
                update!(orders, message)
                update!(books[message.name], message)
                write(orderbooks_buffer, books[message.name])
            end
        elseif message.type == 'D'
            complete_delete_message!(message, orders)
            if message.name in tickers
                @info "message: $(message)"
                write(messages_buffer, message)
                message_writes += 1
                update!(orders, message)
                update!(books[message.name], message)
                write(orderbooks_buffer, books[message.name])
            end
        elseif message.type in ['A', 'F']
            if message.name in tickers
                @info "message: $(message)"
                write(messages_buffer, message)
                message_writes += 1
                add!(orders, message)
                update!(books[message.name], message)
                write(orderbooks_buffer, books[message.name])
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
