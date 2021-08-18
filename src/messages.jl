abstract type AbstractMessage end

import Base.==
(==)(a::T, b::T) where {T<:AbstractMessage} = all([getfield(a, f) == getfield(b, f) for f in fieldnames(T)])

function to_csv(message::T) where {T<:AbstractMessage}
    fields = fieldnames(T)  # T = typeof(message)
    vals = [getfield(message, f) for f in fields]
    return join(string.(vals), ",") * "\n"
end


"""
SystemMessage

Data structure representing system updates.
"""
mutable struct SystemMessage <: AbstractMessage
    date::Date
    sec::Int
    nano::Int
    type::Char
    name::String
    event::Char
end

TimestampMessage(date, sec) = SystemMessage(date, sec, 0, 'T', "-", '-')
SystemEventMessage(date, sec, nano, event) = SystemMessage(date, sec, nano, 'S', "-", event)
TradeActionMessage(date, sec, nano, name, event) = SystemMessage(date, sec, nano, 'H', name, event)

function to_csv(message::SystemMessage)
    return "$(message.date),$(message.sec),$(message.nano),$(message.type),$(message.event),,,,,,,\n"
end

"""
OrderMessage

Data structure representing order book updates.
"""
mutable struct OrderMessage <: AbstractMessage
    date::Date
    sec::Int
    nano::Int
    type::Char
    event::Char
    name::String
    side::Char
    price::Int
    shares::Int
    refno::Int
    newrefno::Int
    mpid::String
end

function to_csv(message::OrderMessage)
    return "$(message.date),$(message.sec),$(message.nano),$(message.type),$(message.event),$(message.name),$(message.side),$(message.price),$(message.shares),$(message.refno),$(message.newrefno),$(message.mpid)\n"
end

function OrderMessage(date, sec, nano, type; event = '-', name = "-", side = '-', price = -1, shares = -1, refno = -1, newrefno = -1, mpid = "-")
    return OrderMessage(date, sec, nano, type, event, name, side, price, shares, refno, newrefno, mpid)
end

function AddMessage(date, sec, nano, refno, name, side, price, shares; type='A', mpid="-")
    return OrderMessage(date, sec, nano, type, '-', name, side, price, shares, refno, -1, mpid)
end

function ExecuteMessage(date, sec, nano, refno, shares; type='E', price=-1)
    return OrderMessage(date, sec, nano, type, '-', "-", '-', price, shares, refno, -1, "-")
end

function CancelMessage(date, sec, nano, refno, shares)
    return OrderMessage(date, sec, nano, 'X', '-', "-", '-', -1, shares, refno, -1, "-")
end

function DeleteMessage(date, sec, nano, refno)
    return OrderMessage(date, sec, nano, 'D', '-', "-", '-', -1, -1, refno, -1, "-")
end

function ReplaceMessage(date, sec, nano, refno, newrefno, shares, price)
    return OrderMessage(date, sec, nano, 'U', '-', "-", '-', price, shares, refno, newrefno, "-")
end

function CrossTradeMessage(date, sec, nano, shares, name, price, event)
    return OrderMessage(date, sec, nano, 'Q', event, name, '-', price, shares, -1, -1, "-")
end


import Base.split
"""
split(message)

Convert a replace message into an add and a delete.
"""
function split(message::OrderMessage)
    message.type != 'U' && error("cannot split message of type '$(message.type)'")
    del_message = OrderMessage(
        message.date,
        message.sec,
        message.nano,
        'D',
        refno = message.refno  # newrefno = -1 by default
    )
    add_message = OrderMessage(
        message.date,
        message.sec,
        message.nano,
        'G',  # special type for add messages derived from replace
        price = message.price,
        shares = message.shares,
        refno = message.refno,
        newrefno = message.newrefno # NOTE: should error if message.type != "U"
    )
    return del_message, add_message
end


"""
complete_replace_message!(message, orders)
complete_replace_add_message!(message, orders)
complete_execute_cancel_message!(message, orders)
complete_delete_message!(message, orders)

Fill in missing message data by matching it to its reference order.
"""
function complete_replace_message!(message::OrderMessage, orders::Dict)
    ref_order = get(orders, message.refno, nothing)
    if !isnothing(ref_order)
        message.name = ref_order.name
        message.side = ref_order.side
        @debug "completed message: $(message)"
    else
        @debug "skipped message: $(message)"
    end
    return message
end
function complete_replace_add_message!(message::OrderMessage, orders::Dict)
    ref_order = get(orders, message.refno, nothing)
    if !isnothing(ref_order)
        message.type = 'A'
        message.name = ref_order.name
        message.side = ref_order.side
        message.refno = message.newrefno
        message.newrefno = -1
        @debug "completed message: $(message)"
    else
        @debug "skipped message: $(message)"
    end
    return message
end
function complete_execute_cancel_message!(message::OrderMessage, orders::Dict)
    ref_order = get(orders, message.refno, nothing)
    if !isnothing(ref_order)
        message.name = ref_order.name
        message.side = ref_order.side
        message.price = ref_order.price
        @debug "completed message: $(message)"
    else
        @debug "skipped message: $(message)"
    end
    return message
end
function complete_delete_message!(message::OrderMessage, orders::Dict)
    ref_order = get(orders, message.refno, nothing)
    if !isnothing(ref_order)
        message.name = ref_order.name
        message.side = ref_order.side
        message.price = ref_order.price
        message.shares = ref_order.shares
        @debug "completed message: $(message)"
    else
        @debug "skipped message: $(message)"
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
    type::Char
    name::String
    paired::Int
    imbalance::Int
    direction::Char
    far::Int
    near::Int
    current::Int
    cross::Char
end

function NOIIMessage(date, sec, nano; type = '-', name = "-", paired = -1, imbalance = -1, direction = '-', far = -1, near = -1, current = -1, cross = '-')
    return NOIIMessage(date, sec, nano, type, name, paired, imbalance, direction, far, near, current, cross)
end

function to_csv(message::NOIIMessage)
    return "$(message.date),$(message.sec),$(message.nano),$(message.type),$(message.name),$(message.paired),$(message.imbalance),$(message.direction),$(message.far),$(message.near),$(message.current),$(message.cross)\n"
end

"""
TradeMessage

Data structure representing trades.
"""
mutable struct TradeMessage <: AbstractMessage
    date::Date
    sec::Int
    nano::Int
    type::Char
    name::String
    side::Char
    price::Int
    shares::Int
end

function TradeMessage(date, sec, nano; type = '-', name = "-", side = '-', price = -1, shares = -1)
    return TradeMessage(date, sec, nano, type, name, side, price, shares)
end

function to_csv(message::TradeMessage)
    return "$(message.date),$(message.sec),$(message.nano),$(message.type),$(message.name),$(message.side),$(message.price),$(message.shares)\n"
end