abstract type AbstractMessage end

function to_csv(message::T) where {T<:AbstractMessage}
    fields = fieldnames(T)  # T = typeof(message)
    vals = [getfield(message, f) for f in fields]
    line = join(string.(vals), ",")
end


"""
Message

Data structure representing order book updates.
"""
mutable struct Message <: AbstractMessage
    date::Date
    sec::Int
    nano::Int
    type::String
    event::String
    name::String
    side::String
    price::Int
    shares::Int
    refno::Int
    newrefno::Int
    mpid::String
end

function Message(date; sec = -1, nano = -1, type = ".", event = ".", name = ".", side = ".", price = -1, shares = -1, refno = -1, newrefno = -1, mpid = ".")
    return Message(date, sec, nano, type, event, name, side, price, shares, refno, newrefno, mpid)
end

import Base.split
"""
split(message)

Convert a replace message into an add and a delete.
"""
function split(message)
    if message.type == "U"
        del_message = Message(
            message.date,
            sec=message.sec,
            nano=message.nano,
            type="D",
            refno=message.refno  # newrefno = -1 by default
        )
        add_message = Message(
            message.date,
            sec=message.sec,
            nano=message.nano,
            type="G",
            price=message.price,
            shares=message.shares,
            refno=message.refno,
            newrefno=message.newrefno
        )
        return message, del_message, add_message
    else
        @warn "Split method called on non-replace message."
    end
end


"""
complete(message, orders)

Fill in missing message data by matching it to its reference order.
"""
function complete!(message::Message, orders::Dict)
    if message.refno in keys(orders)
        ref_order = orders[message.refno]
        if message.type == "U"  # TODO: remove this (do we ever complete replace messages directly?)
            message.name = ref_order.name
            message.side = ref_order.side
        elseif message.type == "G"  # ADD from a split REPLACE order
            message.type = "A"
            message.name = ref_order.name
            message.side = ref_order.side
            message.refno = message.newrefno
            message.newrefno = -1
        elseif message.type in ["E", "C", "X"]
            message.name = ref_order.name
            message.side = ref_order.side
            message.price = ref_order.price
        elseif message.type == "D"
            message.name = ref_order.name
            message.side = ref_order.side
            message.price = ref_order.price
            message.shares = ref_order.shares
        end
    end
    return message
end


"""
NOIIMessage

Data structure representing net order imbalance indicator messages and cross trade messages.
"""
mutable struct NOIIMessage <: AbstractMessage
    date::Date
    sec::Int
    nano::Int
    name::String
    type::String
    cross::String
    side::String
    price::Int
    shares::Int
    matchno::Int
    paired::Int
    imbalance::Int
    direction::String
    far::Int
    near::Int
    current::Int
end

function NOIIMessage(date; sec = -1, nano = -1, name = ".", type = ".", cross = ".", side = ".", price = -1, shares = -1, matchno = -1, paired = -1, imbalance = -1, direction = ".", far = -1, near = -1, current = -1)
    return NOIIMessage(date, sec, nano, name, type, cross, side, price, shares, matchno, paired, imbalance, direction, far, near, current)
end


"""
TradeMessage

Data structure representing trades.
"""
mutable struct TradeMessage <: AbstractMessage
    date::Date
    sec::Int
    nano::Int
    name::String
    type::String
    side::String
    price::Int
    shares::Int
end

function TradeMessage(date; sec = -1, nano = -1, name = ".", type = ".", side = ".", price = -1, shares = -1)
    return TradeMessage(date, sec, nano, name, type, side, price, shares)
end
