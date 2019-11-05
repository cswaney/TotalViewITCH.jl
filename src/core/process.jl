const TYPES = ['T', 'S', 'H', 'A', 'F', 'E', 'C', 'X', 'D', 'U', 'P', 'Q', 'I']

get_message_size(io) = Int(unpack(io, "H")[1])

get_message_type(io) = Char(unpack(io, "c")[1])

function get_message(io, size, type, date, time, version)
    if type in TYPES
        return unpack_message_payload(io, type, date, time, version)
    else
        skipbytes(io, size)
    end
end


"""
unpack_message_bytes(message_bytes, type, time, version)

Unpack binary message data and return an out-going message.
"""
function unpack_message_payload(io, type, time, version)

    message = Message()
    message.date = date

    if version == 4.0

        if type == 'T'  # time

        elseif type == 'S'  # systems

        elseif type == 'H'  # trade action

        elseif type == 'A'  # add

        elseif type == 'F'  # add w/ MPID

        elseif type == 'E'  # execute

        elseif type == 'C'  # execute w/ price

        elseif type == 'X'  # cancel

        elseif type == 'D'  # delete

        elseif type == 'U'  # replace

        elseif type == 'Q'  # cross-trade

        elseif type == 'P'  # trade message

        elseif type == 'I'  # imbalance

        end

    elseif version == 4.1
        if type == 'T'  # time
            payload = unpack(io, "I")
            message.sec = Int(payload[1])
            message.nano = 0
        elseif type == 'S'  # systems
            payload = unpack(io, "Is")
            message.sec = time
            message.nano = Int(payload[1])
            message.name = "."
            message.event = String(payload[2])
        elseif type == 'H'  # trade action
            payload = unpack(io, "I8sss4s")
            message.sec = time
            message.nano = Int(payload[1])
            message.name = rstrip(String(payload[2]), ' ')
            message.event = String(payload[3])
        elseif type == 'A'  # add
            payload = unpack("IQsI8sI", message_bytes)
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
            message.side = String(payload[3])
            message.shares = Int(payload[4])
            message.name = rstrip(String(payload[5]), ' ')
            message.price = Int(payload[6])
        elseif type == 'F'  # add w/ MPID
            payload = unpack("IQsI8sI4s", message_bytes)
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
            message.side = String(payload[3])
            message.shares = Int(payload[4])
            message.name = rstrip(String(payload[5]), ' ')
            message.price = Int(payload[6])
            message.mpid = rstrip(String(payload[7]), ' ')
        elseif type == 'E'  # execute
            payload = unpack(io, "IQIQ")
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
            message.shares = Int(payload[3])
        elseif type == 'C'  # execute w/ price
            payload = unpack(io, "IQIQsI")
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
            message.shares = Int(payload[3])
            message.price = Int(payload[6])
        elseif type == 'X'  # cancel
            payload = unpack(io, "IQI")
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
            message.shares = Int(payload[3])
        elseif type == 'D'  # delete
            payload = unpack(io, "IQ")
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
        elseif type == 'U'  # replace
            payload = unpack(io, "IQQII")
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
            message.newrefno = Int(payload[3])
            message.shares = Int(payload[4])
            message.price = Int(payload[5])
        elseif type == 'Q'  # cross-trade
            payload = unpack(io, "IQ8sIQs")
            message.sec = time
            message.nano = Int(payload[1])
            message.shares = Int(payload[2])
            message.name = rstrip(String(payload[3]), ' ')
            message.price = Int(payload[4])
            message.event = String(payload[6])
        elseif type == 'P'  # trade message
            payload = unpack(io, "IQsI8sIQ")
            message.sec = time
            message.nano = Int(payload[1])
            message.refno = Int(payload[2])
            message.side = String(payload[3])
            message.shares = Int(payload[4])
            message.name = rstrip(String(payload[5]), ' ')
            message.price = Int(payload[6])
        elseif type == 'I'  # imbalance
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
        end

    elseif version == 5.0

        if type == 'T'  # time

        elseif type == 'S'  # systems

        elseif type == 'H'  # trade action

        elseif type == 'A'  # add

        elseif type == 'F'  # add w/ MPID

        elseif type == 'E'  # execute

        elseif type == 'C'  # execute w/ price

        elseif type == 'X'  # cancel

        elseif type == 'D'  # delete

        elseif type == 'U'  # replace

        elseif type == 'Q'  # cross-trade

        elseif type == 'P'  # trade message

        elseif type == 'I'  # imbalance

        end

    end

    return message
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
read(file, version, date, nlevels, names, path)

Read a binary data file and write message and order book data to file.

# Arguments
- `file`: location of file to read.
- `version`: ITCH version number.
- `date`: date to associate with output.
- `nlevels`: number of order book levels to track.
- `names`: stock tickers to track.
- `path`: location to write output.
"""
function import(file, version, date, nlevels, names, path)

    BUFFER_SIZE = 10 ** 4

    orders = Dict{Int,Order}()
    books = Dict{String,Book}()
    snapshots = Dict{String,Vector}()
    messages = Dict{String,Vector}()
    trades = Dict{String,Vector}()
    imbalances = Dict{String,Vector}()

    io = open(file)
    message_reads = 0
    message_writes = 0
    noii_writes = 0
    trade_writes = 0
    reading = True
    clock = 0
    start = time()

    while reading
        # read message
        message_size = get_message_size(io)
        message_type = get_message_type(io)
        message = get_message(io, size, type, date, clock, version)
        message_reads += 1

        # update clock
        if message.type == 'T'
            clock = message.sec
            if clock % 1800 == 0
                println("TIME=$(clock)")
            end
        end

        # update system
        if message.type == 'S'
            println("SYSTEM MESSAGE: $(message.event)")
            write(message, log_path)
            if message.event == 'C'  # end of messages
                reading = False
            end
        elseif message.type == 'H'
            if message.name in names
                print("TRADE MESSAGE ($(message.name): $(message.event)")
                write(message, log_path)
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
        end

        # complete message
        if message.type == 'U'
            message, del_message, add_message = split(message)
            complete!(message, orders)
            complete!(del_message, orders)
            complete!(add_message, orders)
            if message.name in names
                message_writes += 1
                update!(orders, del_message)
                update!(books, del_message)
                update!(orders, add_message)
                update!(books, add_message)
                push!(messages[message.name], message)
            end
        elseif message.type in ['E', 'C', 'X', 'D']
            complete!(message, orders)
            if message.name in names
                message_writes += 1
                update!(orders, message)
                update!(books, message)
                push!(messages[message.name], message)
            end
        elseif message.type in ['A', 'F']
            if message.name in names
                message_writes += 1
                add!(orders, message)
                update!(books, message)
                push!(messages[message.name], message)
            end
        elseif message.type == 'P'
            if message.name in names
                trade_writes += 1
                push!(trades[message.name], message)
            end
        elseif message.type in ['Q', 'I']
            if message.name in names
                noii_writes += 1
                push!(imbalances[message.name], message)
            end
        end

        # write message
        if message.type in ['U', 'A', 'F', 'E', 'C', 'X', 'D']
            if message.name in names
                name = message.name
                if length(messages[name]) == BUFFER_SIZE
                    write(messages, name = name, path = path, grp = "messages")
                end
                if length(snapshots[name]) == BUFFER_SIZE
                    write(snapshots, name = name, path = path, grp = "books")
                end
            end
        elseif message.type == 'P'
            if message.name in names
                name = message.name
                if length(trades[name]) == BUFFER_SIZE
                    write(trades, name = name, path = path, grp = "trades")
                end
            end
        elseif message.type in ['Q', 'I']
            if message.name in names
                name = message.name
                if length(imbalances[name]) == BUFFER_SIZE
                    write(imbalances, name = name, path = path, grp = "noii")
                end
            end
        end
    end

    # clean up
    for name in names
        write(messages, name = name, path = path, grp = "messages")
        write(snapshots, name = name, path = path, grp = "books")
        write(trades, name = name, path = path, grp = "trades")
        write(imbalances, name = name, path = path, grp = "noii")
    end

    stop = time()
    elapsed_time = stop - start
    println("Elapsed time: $(elapsed_time)")
    println("Messages read: $(message_reads)")
    println("Messages written: $(message_writes)")
    println("NOII written: $(noii_writes)")
    println("Trades written: $(trade_writes)")
end
