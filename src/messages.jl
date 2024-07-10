abstract type AbstractMessage end

import Base.==
(==)(a::T, b::T) where {T<:AbstractMessage} = all([getfield(a, f) == getfield(b, f) for f in fieldnames(T)])

function to_csv(message::T) where {T<:AbstractMessage}
    fields = fieldnames(T)
    vals = [getfield(message, f) for f in fields]
    return join(string.(vals), ",") * "\n"
end


"""
    SystemMessage

A simple data type representing system updates.

System updates comunicate changes that apply to the entire exchange, such as
the beginning and ending of trading hours.
"""
mutable struct SystemMessage <: AbstractMessage
    date::Date
    sec::Int
    nano::Int
    type::Char
    ticker::String
    event::Char
end

TimestampMessage(date, sec) = SystemMessage(date, sec, 0, 'T', "-", '-')
SystemEventMessage(date, sec, nano, event) = SystemMessage(date, sec, nano, 'S', "-", event)
TradeActionMessage(date, sec, nano, ticker, event) = SystemMessage(date, sec, nano, 'H', ticker, event)

function to_csv(message::SystemMessage)
    return "$(message.date),$(message.sec),$(message.nano),$(message.type),$(message.event),,,,,,,\n"
end

"""
    OrderMessage

A simple data type representing order book updates.

Order book updates communicate changes to the order book in response to trader
actions, e.g., add, execute, delete, etc.
"""
mutable struct OrderMessage <: AbstractMessage
    date::Date
    sec::Int
    nano::Int
    type::Char
    ticker::String
    side::Char
    price::Int
    shares::Int
    refno::Int
    newrefno::Int
    mpid::String
end

function to_csv(message::OrderMessage)
    return "$(message.ticker),$(message.date),$(message.sec),$(message.nano),$(message.type),$(message.ticker),$(message.side),$(message.price),$(message.shares),$(message.refno),$(message.newrefno),$(message.mpid)\n"
end

function OrderMessage(date, sec, nano, type; ticker = "-", side = '-', price = -1, shares = -1, refno = -1, newrefno = -1, mpid = "-")
    return OrderMessage(date, sec, nano, type, ticker, side, price, shares, refno, newrefno, mpid)
end

function AddMessage(date, sec, nano, refno, ticker, side, price, shares; type='A', mpid="-")
    return OrderMessage(date, sec, nano, type, ticker, side, price, shares, refno, -1, mpid)
end

function ExecuteMessage(date, sec, nano, refno, shares; type='E', price=-1)
    return OrderMessage(date, sec, nano, type, "-", '-', price, shares, refno, -1, "-")
end

function CancelMessage(date, sec, nano, refno, shares)
    return OrderMessage(date, sec, nano, 'X', "-", '-', -1, shares, refno, -1, "-")
end

function DeleteMessage(date, sec, nano, refno)
    return OrderMessage(date, sec, nano, 'D', "-", '-', -1, -1, refno, -1, "-")
end

function ReplaceMessage(date, sec, nano, refno, newrefno, shares, price)
    return OrderMessage(date, sec, nano, 'U', "-", '-', price, shares, refno, newrefno, "-")
end

function split_message(message::OrderMessage)
    """Convert a replace message into an add and a delete."""
    message.type != 'U' && throw(ArgumentError("cannot split message of type '$(message.type)'"))
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
        newrefno = message.newrefno
    )
    return del_message, add_message
end

function complete_message!(message::OrderMessage, orders::Dict)
    """Fill in missing message data by matching it to its reference order."""
    if message.type == 'U'
        complete_replace_message!(message, orders)
    elseif message.type == 'G'
        complete_replace_add_message!(message, orders)
    elseif message.type in ['E', 'X', 'C']
        complete_execute_cancel_message!(message, orders)
    elseif message.type == 'D'
        complete_delete_message!(message, orders)
    else
        throw(ArgumentError("cannot complete message of type $(message.type)"))
    end
end

function complete_replace_message!(message::OrderMessage, orders::Dict)
    message.type != 'U' && throw(ArgumentError("not a replace message (type=$(message.type))"))
    ref_order = get(orders, message.refno, nothing)
    if !isnothing(ref_order)
        message.ticker = ref_order.ticker
        message.side = ref_order.side
        @debug "completed message: $(message)"
    else
        @debug "skipped message: $(message)"
    end
    return message
end

function complete_replace_add_message!(message::OrderMessage, orders::Dict)
    message.type != 'G' && throw(ArgumentError("not an add message (type=$(message.type))"))
    ref_order = get(orders, message.refno, nothing)
    if !isnothing(ref_order)
        message.type = 'A'
        message.ticker = ref_order.ticker
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
    !(message.type in ['E', 'X', 'C']) && throw(ArgumentError("not an execute or cancel message (type=$(message.type))"))
    ref_order = get(orders, message.refno, nothing)
    if !isnothing(ref_order)
        message.ticker = ref_order.ticker
        message.side = ref_order.side
        message.price = ref_order.price
        @debug "completed message: $(message)"
    else
        @debug "skipped message: $(message)"
    end
    return message
end

function complete_delete_message!(message::OrderMessage, orders::Dict)
    message.type != 'D' && throw(ArgumentError("not a delete message (type=$(message.type))"))
    ref_order = get(orders, message.refno, nothing)
    if !isnothing(ref_order)
        message.ticker = ref_order.ticker
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

A simple data type representing net order imbalance indicator messages and cross
trade messages.
"""
mutable struct NOIIMessage <: AbstractMessage
    date::Date
    sec::Int
    nano::Int
    type::Char
    ticker::String
    paired::Int
    imbalance::Int
    direction::Char
    far::Int
    near::Int
    current::Int
    cross::Char
end

function NOIIMessage(date, sec, nano; type = '-', ticker = "-", paired = -1, imbalance = -1, direction = '-', far = -1, near = -1, current = -1, cross = '-')
    return NOIIMessage(date, sec, nano, type, ticker, paired, imbalance, direction, far, near, current, cross)
end

function to_csv(message::NOIIMessage)
    return "$(message.date),$(message.sec),$(message.nano),$(message.type),$(message.ticker),$(message.paired),$(message.imbalance),$(message.direction),$(message.far),$(message.near),$(message.current),$(message.cross)\n"
end

"""
    TradeMessage

A simple data type representing trade messages.
"""
mutable struct TradeMessage <: AbstractMessage
    date::Date
    sec::Int
    nano::Int
    type::Char
    ticker::String
    side::Char
    price::Int
    shares::Int
end

function TradeMessage(date, sec, nano; type = '-', ticker = "-", side = '-', price = -1, shares = -1)
    return TradeMessage(date, sec, nano, type, ticker, side, price, shares)
end

function to_csv(message::TradeMessage)
    return "$(message.date),$(message.sec),$(message.nano),$(message.type),$(message.ticker),$(message.side),$(message.price),$(message.shares)\n"
end