using DataStructures: SortedDict
using Base.Order
using Base.Iterators

"""
    Order

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

function add!(orders::Dict{Int,Order}, message::OrderMessage)
    """
        add_order!(orders::Dict, message::OrderMessage)
    
    Add an order to an order collection based on a new message.
    """
    !(message.type in ['A', 'F']) && throw(ArgumentError("Unable to add order (invalid message type $(message.type))"))
    order = Order(
        message.name,
        message.side,
        message.price,
        message.shares
    )
    haskey(orders, message.refno) && throw(ErrorException("Unable to add order (duplicate reference number $(message.refno))"))
    orders[message.refno] = order
end


function update!(orders::Dict{Int,Order}, message::OrderMessage)
    """
        `update!(orders::Dict{Int,Order}, message::OrderMessage)`
    
    Find and update an order from a collection of orders based on a new message.
    """
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
        @warn "Unable to update order (missing reference number $(message.refno))"
    end
end


"""
    Book

A limit order book.

# Arguments
- `name::String`: the associated security name/ticker
- `nlevels::Int`: the number of levels reported in tabular format.
"""
mutable struct Book
    bids::SortedDict{Int,Int}
    asks::SortedDict{Int,Int}
    sec::Int
    nano::Int
    name::String
    nlevels::Union{Nothing,Int}
end

function Book(name::String, nlevels::Int)
    return Book(SortedDict{Int,Int}(Reverse), SortedDict{Int,Int}(Forward), -1, -1, name, nlevels)
end

function Boook(name)
    return Book(SortedDict{Int,Int}(Reverse), SortedDict{Int,Int}(Forward), -1, -1, name, nothing)
end

function to_csv(book::Book)
    n = book.nlevels
    nbids = length(book.bids)
    nasks = length(book.asks)
    bid_prices = fillto!(join(take(keys(book.bids), n), ","), max(nbids - 1, 0), n - 1)
    ask_prices = fillto!(join(take(keys(book.asks), n), ","), max(nasks - 1, 0), n - 1)
    bid_shares = fillto!(join(take(values(book.bids), n), ","), max(nbids - 1, 0), n - 1)
    ask_shares = fillto!(join(take(values(book.asks), n), ","), max(nasks - 1, 0), n - 1)
    return join([book.sec, book.nano, bid_prices, ask_prices, bid_shares, ask_shares], ",") * "\n"
end

function fillto!(s::String, m, n)
    m < 0 && throw(DomainError(m, "negative number of values provided"))
    if m < n
        s *= join(repeat([","], n - m))
    end
    return s
end

function update!(book::Book, message::OrderMessage)
    """
        `update(book::Book, message::OrderMessage)`
    
    Update an order book from a new message.
    """
    book.name != message.name && throw(ArgumentError("Unable to update order book (book name ($(book.name)) doesn't match message name ($(message.name))"))
    ismissing(message.sec) && throw(ArgumentError("Unable to update order book (message is missing seconds timestamp)"))
    ismissing(message.nano) && throw(ArgumentError("Unable to update order book (message is missing nanoseconds timestamp)"))
    book.sec = message.sec
    book.nano = message.nano
    if message.side == 'B'
        if message.price in keys(book.bids)
            if message.type in ['E', 'C', 'X', 'D']
                book.bids[message.price] < message.shares && throw(ErrorException("Message shares exceed available shares (name=$(message.name), price=$(message.price), shares=$(message.shares))"))
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
        else
            throw(ErrorException("Unable to update order book (non-add message price $(message.price) not in bids)"))
        end
    elseif message.side == 'S'
        if message.price in keys(book.asks)
            if message.type in ['E', 'C', 'X', 'D']
                book.asks[message.price] < message.shares && throw(ErrorException("Message shares exceed available shares (name=$(message.name), price=$(message.price), shares=$(message.shares))"))
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
        else
            throw(ErrorException("Unable to update order book (non-add message price $(message.price) not in asks)"))
        end
    else
        throw(ArgumentError("Unable to update order book (unknown message side $(message.side))"))
    end
    return book
end
