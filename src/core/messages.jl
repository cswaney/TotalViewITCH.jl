"""
Message

Data structure representing order book updates.
"""
struct Message
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
    rewrefno::Int
    mpid::String
end

function Message(date, sec = -1, nano = -1, type = ".", event = ".", name = ".", side = ".", price = -1, shares = -1, refno = -1, newrefno = -1, mpid = ".")
    return Message(
        date,
        sec,
        nano,
        type,
        event,
        name,
        side,
        price,
        shares,
        refno,
        newrefno,
        mpid
    )
end

"""
split(message)

Convert a replace message into an add and a delete.
"""
function split(message)
    if message.type == 'U'
        del_message = Message(
            date=message.date,
            sec=message.sec,
            nano=message.nano,
            type='D',
            refno=message.refno  # newrefno = -1 by default
        )
        add_message = Message(
            date=message.date,
            sec=message.sec,
            nano=message.nano,
            type='G',
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
        if message.type == 'U'
            message.name = ref_order.name
            message.side = ref_order.side
        elseif message.type == 'G'  # ADD from a split REPLACE order
            message.type = 'A'
            message.name = ref_order.name
            message.side = ref_order.side
            message.refno = message.newrefno
            message.newrefno = -1
        elseif message.type in ['E', 'C', 'X']
            message.name = ref_order.name
            message.side = ref_order.side
            message.price = ref_order.price
            message.shares = message.shares
        elseif message.type == 'D'
            message.name = ref_order.name
            message.side = ref_order.side
            message.price = ref_order.price
            message.shares = ref_order.shares
        end
    end
end


"""
add_order!(orders::Dict, message::Message)

Add an order to the order list based on message payload.
"""
function add!(orders::Dict, message::Message)
    order = Order(message.name, message.side, message.price, message.shares)
    orders[message.refno] = order
end


"""
update_order!(orders::Dict, message::Message)

Update an order in the order list based on message payload.
"""
function update!(orders::Dict, message::Message)
    if message.refno in keys(orders)
        if message.type in ['E', 'X', 'C']  # execute, execute w/ price, cancel
            orders[message.refno].shares -= message.shares
        elseif message.type == 'D'  # delete
            delete!(orders, message.refno)
        end
    end
end


"""
NOIIMessage

Data structure representing net order imbalance indicator messages and cross trade messages.
"""
struct NOIIMessage
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


"""
TradeMessage

Data structure representing trades.
"""
struct TradeMessage
    date::Date
    sec::Int
    nano::Int
    name::String
    side::String
    price::Int
    shares::Int
end


"""

Write a list of messages to text file.
"""
function write(messages, path::String, group::String) end

function write(message::Message)
    
end
function write(message::TradeMessage) end
function write(message::NOIIMessage) end
