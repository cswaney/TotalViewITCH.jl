using DataStructures: SortedDict
using Base.Order
using Base.Iterators

"""
    `Order`

A limit order.
"""
mutable struct Order
    name::String
    side::Char
    price::Int
    shares::Int
end

import Base.==
(==)(a::Order, b::Order) = all([getfield(a, f) == getfield(b, f) for f in fieldnames(Order)])

"""
    add_order!(orders::Dict, message::OrderMessage)

Add an order to an order collection based on a new message.
"""
function add!(orders::Dict{Int,Order}, message::OrderMessage)
    if !(message.type in ['A', 'F'])
        throw(ArgumentError("cannot add order message type ($(message.type)) to orders"))
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
    `update!(orders::Dict{Int,Order}, message::OrderMessage)`

Find and update an order from a collection of orders based on a new message.
"""
function update!(orders::Dict{Int,Order}, message::OrderMessage)
    if haskey(orders, message.refno)
        if message.type in ['E', 'X', 'C']  # execute, execute w/ price, cancel
            orders[message.refno].shares -= message.shares
            if orders[message.refno].shares == 0  # remove order if completed
                delete!(orders, message.refno)
            end
        elseif message.type == 'D'  # delete
            delete!(orders, message.refno)
        end
    else
        @warn "Unable to match message: message number $(message.refno) not found"
    end
end


"""
`Book`

A limit order book.

# Arguments
- `name::String`: the associated security name/ticker
- `nlevels::Int`: the number of levels reported
"""
mutable struct Book
    bids::SortedDict{Int,Int}
    asks::SortedDict{Int,Int}
    sec::Int
    nano::Int
    name::String
    nlevels::Int
end

function Book(name::String, nlevels::Int)
    return Book(SortedDict{Int,Int}(Reverse), SortedDict{Int,Int}(Forward), -1, -1, name, nlevels)
end

function to_csv(book::Book)
    n = book.nlevels
    nbids = length(book.bids)
    nasks = length(book.asks)
    bid_prices = fillto!(join(take(keys(book.bids), n), ","), max(nbids - 1, 0), n - 1)
    ask_prices = fillto!(join(take(keys(book.asks), n), ","), max(nasks - 1, 0), n - 1)
    bid_shares = fillto!(join(take(values(book.bids), n), ","), max(nbids - 1, 0), n - 1)
    ask_shares = fillto!(join(take(values(book.asks), n), ","), max(nasks - 1, 0), n - 1)
    return join([bid_prices, ask_prices, bid_shares, ask_shares], ",") * "\n"
end

function fillto!(s::String, m, n)
    m < 0 && @error "negative number of values provided"
    if m < n
        s *= join(repeat([","], n - m))
    end
    return s
end

"""
`update(book::Book, message::OrderMessage)`

Update an order book from a new message.
"""
function update!(book::Book, message::OrderMessage)
    book.name != message.name && throw(ArgumentError("Book name ($(book.name)) doesn't match message name ($(message.name))"))
    if message.side == 'B'
        if message.price in keys(book.bids)
            if message.type in ['E', 'C', 'X', 'D']
                book.bids[message.price] -= message.shares
                if book.bids[message.price] == 0
                    delete!(book.bids, message.price)
                    @debug "deleted price $(message.price) from bids"
                end
            elseif message.type in ['A', 'F']
                book.bids[message.price] += message.shares
            end
        elseif message.type in ['A', 'F']
            book.bids[message.price] = message.shares
            @debug "added price $(message.price) to bids"
        end
    elseif message.side == 'S'
        if message.price in keys(book.asks)
            if message.type in ['E', 'C', 'X', 'D']
                book.asks[message.price] -= message.shares
                if book.asks[message.price] == 0
                    delete!(book.asks, message.price)
                    @debug "deleted price $(message.price) from asks"
                end
            elseif message.type in ['A', 'F']
                book.asks[message.price] += message.shares
            end
        elseif message.type in ['A', 'F']
            book.asks[message.price] = message.shares
            @debug "added price $(message.price) to bids"
        end
    end
    return book
end
