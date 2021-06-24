using TotalViewITCH: add!, update!, to_csv
using Dates

date = Date("2010-01-01")
nlevels = 3

@testset "Orders" begin
    # setup
    orders = Dict{Int,Order}()

    # add order
    add_message = Message(
        date,
        type = "A",
        name = "AAPL",
        side = "B",
        price = 125.00,
        shares = 500,
        refno = 123456789
    )
    add!(orders, add_message)
    @test get(orders, 123456789, nothing) == Order("AAPL", "B", 125.00, 500)

    # execute order
    execute_message = Message(
        date,
        type = "E",
        shares = 100,
        refno = 123456789
    )
    update!(orders, execute_message)
    @test get(orders, 123456789, nothing) == Order("AAPL", "B", 125.00, 400)

    # cancel order
    cancel_message = Message(
        date,
        type = "C",
        shares = 100,
        refno = 123456789
    )
    update!(orders, cancel_message)
    @test get(orders, 123456789, nothing) == Order("AAPL", "B", 125.00, 300)

    # delete
    delete_message = Message(
        date,
        type = "D",
        refno = 123456789
    )
    update!(orders, delete_message)
    @test get(orders, 123456789, nothing) == nothing
end

@testset "Books" begin
    # setup
    book = Book(nlevels, name = "AAPL")

    # add message
    add_message = Message(
        date,
        type = "A",
        name = "AAPL",
        side = "B",
        price = 125.00,
        shares = 500
    )
    update!(book, add_message)
    @test get(book.bids, 125.00, nothing) == 500

    # execute message
    execute_message = Message(
        date,
        type = "E",
        name = "AAPL",
        side = "B",
        price = 125.00,
        shares = 100
    )
    update!(book, execute_message)
    @test get(book.bids, 125.00, nothing) == 400

    # cancel message
    cancel_message = Message(
        date,
        type = "C",
        name = "AAPL",
        side = "B",
        price = 125.00,
        shares = 100
    )
    update!(book, cancel_message)
    @test get(book.bids, 125.00, nothing) == 300

    # delete message
    delete_message = Message(
        date,
        type = "D",
        name = "AAPL",
        side = "B",
        price = 125.00,
        shares = 300
    )
    update!(book, delete_message)
    @test isnothing(get(book.bids, 125.00, nothing))
end

@testset "Books.IO" begin
    bids = Dict(100 => 500, 99 => 400, 98 => 200)
    asks = Dict(103 => 400, 105 => 300, 106 => 200)
    book = Book(bids, asks, 0, 0, "", 3)
    @test to_csv(book) == "100,99,98,103,105,106,500,400,200,400,300,200"
end
