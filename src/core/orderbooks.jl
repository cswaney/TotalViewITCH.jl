"""
Order

Data structure representing a limit order.
"""
struct Order
    name::String
    side::String
    price::Int
    shares::Int
end


"""
Book

Data structure representing an order book.
"""
struct Book
    bids::Dict{Int,Int}
    asks::Dict{Int,Int}
    sec::Int
    nano::Int
    nlevels::Int
end

function Book(date::Date, name::String, nlevels::Int)
    return Book(Dict{Int,Int}(), Dict{Int,Int}(), -1, -1, nlevels)
end

function create_books(date::Date, names::Array{String,1}, nlevels::Int)
    books = Dict{String,Book}()
    for name in names
        books[name] = Book(date, name, nlevels)
    end
    return books
end

"""
update(book::Book, order::Order)

Update an order book from a new message.
"""
function update!(book::Book, message::Message)
    if message.side == 'B'
        if message.price in keys(book.bids)
            if message.type in ['E', 'C', 'X', 'D']
                book.bids[message.price] -= message.shares
                if book.bids[message.price] == 0
                    delete!(book.bids, message.price)
                end
            elseif message.type in ['A', 'F']
                book.bids[message.price] += message.shares
            end
        elseif message.type in ['A', 'F']
            book.bids[message.price] = message.shares
        end
    elseif message.side == 'S'
        if message.price in keys(book.asks)
            if message.type in ['E', 'C', 'X', 'D']
                book.asks[message.price] -= message.shares
                if book.asks[message.price] == 0
                    delete!(book.asks, message.price)
                end
            elseif message.type in ['A', 'F']
                book.asks[message.price] += message.shares
            end
        elseif message.type in ['A', 'F']
            book.asks[message.price] = message.shares
        end
    end
end


"""

Write a list of order book snapshots to a text file.
"""
function write(books, name::String, group::String) end

function write(book::Book) end
