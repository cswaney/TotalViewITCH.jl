"""
`Order`

Data structure representing a limit order.
"""
mutable struct Order
    name::String
    side::String
    price::Int
    shares::Int
end

import Base.==
(==)(a::Order, b::Order) = all([getfield(a, f) == getfield(b, f) for f in fieldnames(Order)])

"""
add_order!(orders::Dict, message::Message)

Add an order to an order collection based on a new message.
"""
function add!(orders::Dict{Int,Order}, message::Message)
    if !(message.type in ["A", "F"])
        @error "Tried to add order from message type $(message.type)"
    end
    order = Order(
        message.name,
        message.side,
        message.price,
        message.shares
    )
    orders[message.refno] = order
end


"""
`update!(orders::Dict{Int,Order}, message::Message)`

Find and update an order from a collection of orders based on an incoming message.
"""
function update!(orders::Dict{Int,Order}, message::Message)
    if message.refno in keys(orders)
        if message.type in ["E", "X", "C"]  # execute, execute w/ price, cancel
            orders[message.refno].shares -= message.shares
            if orders[message.refno].shares == 0  # remove order if completed
                delete!(orders, message.refno)
            end
        elseif message.type == "D"  # delete
            delete!(orders, message.refno)
        end
    else
        @warn "Failed to update order for message: $(message.refno)"
    end
end


"""
`Book`

Data structure representing an order book.
"""
mutable struct Book
    bids::Dict{Int,Int}  # price => shares
    asks::Dict{Int,Int}
    sec::Int
    nano::Int
    name::String
    nlevels::Int  # number of levels to report
end

function Book(nlevels::Int; name::String = ".")
    return Book(Dict{Int,Int}(), Dict{Int,Int}(), -1, -1, name, nlevels)
end

function to_csv(book::Book)
    bid_prices = [k for k in keys(book.bids)]
    ask_prices = [k for k in keys(book.asks)]
    # bid_idx = sortperm(bid_prices, rev=true)[1:book.nlevels]
    # ask_idx = sortperm(ask_prices)[1:book.nlevels]
    bid_idx = sortperm(bid_prices, rev=true)[1:min(book.nlevels, length(bid_prices))]
    ask_idx = sortperm(ask_prices)[1:min(book.nlevels, length(ask_prices))]
    prices = [bid_prices[bid_idx]; ask_prices[ask_idx]]
    bid_shares = [v for v in values(book.bids)]
    ask_shares = [v for v in values(book.asks)]
    shares = [bid_shares[bid_idx]; ask_shares[ask_idx]]
    prices_string = join(string.(prices), ",")
    shares_string = join(string.(shares), ",")
    return join([prices_string, shares_string], ",")
end


"""
`update(book::Book, message::Message)`

Update an order book from a new message.
"""
function update!(book::Book, message::Message)

    # double-check matching tickers
    if book.name != message.name
        @error "Book name $(book.name) doesn't match message name $(message.name)"
    end

    if message.side == "B"
        if message.price in keys(book.bids)
            if message.type in ["E", "C", "X", "D"]
                book.bids[message.price] -= message.shares
                if book.bids[message.price] == 0
                    delete!(book.bids, message.price)
                    @debug "Deleted price $(message.price) from bids"
                end
            elseif message.type in ["A", "F"]
                book.bids[message.price] += message.shares
            end
        elseif message.type in ["A", "F"]
            book.bids[message.price] = message.shares
            @debug "Added price $(message.price) to bids"
        end
    elseif message.side == "S"
        if message.price in keys(book.asks)
            if message.type in ["E", "C", "X", "D"]
                book.asks[message.price] -= message.shares
                if book.asks[message.price] == 0
                    delete!(book.asks, message.price)
                    @debug "Deleted price $(message.price) from asks"
                end
            elseif message.type in ["A", "F"]
                book.asks[message.price] += message.shares
            end
        elseif message.type in ["A", "F"]
            book.asks[message.price] = message.shares
            @debug "Added price $(message.price) to bids"
        end
    end
    return book
end


# """
#
# Write a list of order book snapshots to a text file.
# """
# function write(books, name::String, group::String) end
#
# function write(book::Book) end
