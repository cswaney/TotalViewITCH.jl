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


"""
add_order!(orders::Dict, message::Message)

Add an order to the order collection based on a new message.
"""
function add!(orders::Dict{Int,Order}, message::Message)

    if !(message.type in ["A", "F"])
        error("Attempted to add order of type $(message.type) to order collection")
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
            # remove order if exhausted
            if orders[message.refno].shares == 0
                delete!(orders, message.refno)
            end
        elseif message.type == "D"  # delete
            delete!(orders, message.refno)
        end
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
    nlevels::Int
end

function Book(nlevels::Int; name::String = ".")
    return Book(Dict{Int,Int}(), Dict{Int,Int}(), -1, -1, name, nlevels)
end

# TODO: only use best `nlevels` of the book
function to_csv(book::Book)
    bid_prices = [k for k in keys(book.bids)]
    ask_prices = [k for k in keys(book.asks)]
    bid_idx = sortperm(bid_prices, rev=true)[1:book.nlevels]
    ask_idx = sortperm(ask_prices)[1:book.nlevels]
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
        error("Book name $(book.name) doesn't match message name $(message.name)")
    end

    if message.side == "B"
        if message.price in keys(book.bids)
            if message.type in ["E", "C", "X", "D"]
                book.bids[message.price] -= message.shares
                if book.bids[message.price] == 0
                    delete!(book.bids, message.price)
                end
            elseif message.type in ["A", "F"]
                book.bids[message.price] += message.shares
            end
        elseif message.type in ["A", "F"]
            book.bids[message.price] = message.shares
        end
    elseif message.side == "S"
        if message.price in keys(book.asks)
            if message.type in ["E", "C", "X", "D"]
                book.asks[message.price] -= message.shares
                if book.asks[message.price] == 0
                    delete!(book.asks, message.price)
                end
            elseif message.type in ["A", "F"]
                book.asks[message.price] += message.shares
            end
        elseif message.type in ["A", "F"]
            book.asks[message.price] = message.shares
        end
    end
    return book
end


"""

Write a list of order book snapshots to a text file.
"""
function write(books, name::String, group::String) end

function write(book::Book) end
