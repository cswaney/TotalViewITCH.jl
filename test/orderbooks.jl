using TotalViewITCH: add!, update!, to_csv, AddMessage, ExecuteMessage, CancelMessage, DeleteMessage
using Dates
using DataStructures: SortedDict
using Base.Order: Reverse, Forward

date = Date("2010-01-01")
nlevels = 3

@testset "Orders" begin
    # setup
    orders = Dict{Int,Order}()

    # add order
    add_message = AddMessage(
        date,
        0,
        0,
        123456789,
        "AAPL",
        'B',
        125,
        500,
    )
    add!(orders, add_message)
    @test get(orders, 123456789, nothing) == Order("AAPL", 'B', 125, 500)

    # execute order
    execute_message = ExecuteMessage(
        date,
        0,
        0,
        123456789,
        100,
    )
    TotalViewITCH.update!(orders, execute_message)
    @test get(orders, 123456789, nothing) == Order("AAPL", 'B', 125, 400)

    # cancel order
    cancel_message = CancelMessage(
        date,
        0,
        0,
        123456789,
        100,
    )
    TotalViewITCH.update!(orders, cancel_message)
    @test get(orders, 123456789, nothing) == Order("AAPL", 'B', 125, 300)

    # delete
    delete_message = DeleteMessage(
        date,
        0,
        0,
        123456789
    )
    TotalViewITCH.update!(orders, delete_message)
    @test isnothing(get(orders, 123456789, nothing))
end

@testset "Books" begin
    # setup
    book = Book("AAPL", nlevels)

    # add message
    add_message = OrderMessage(
        date,
        0,
        0,
        'A',
        name = "AAPL",
        side = 'B',
        price = 125,
        shares = 500
    )
    TotalViewITCH.update!(book, add_message)
    @test get(book.bids, 125, nothing) == 500

    # execute message
    execute_message = OrderMessage(
        date,
        0,
        0,
        'E',
        name = "AAPL",
        side = 'B',
        price = 125,
        shares = 100
    )
    TotalViewITCH.update!(book, execute_message)
    @test get(book.bids, 125, nothing) == 400

    # cancel message
    cancel_message = OrderMessage(
        date,
        0,
        0,
        'C',
        name = "AAPL",
        side = 'B',
        price = 125,
        shares = 100
    )
    TotalViewITCH.update!(book, cancel_message)
    @test get(book.bids, 125, nothing) == 300

    # delete message
    delete_message = OrderMessage(
        date,
        0,
        0,
        'D',
        name = "AAPL",
        side = 'B',
        price = 125,
        shares = 300
    )
    TotalViewITCH.update!(book, delete_message)
    @test isnothing(get(book.bids, 125, nothing))
end

@testset "Books.IO" begin

    book = Book("", 3)
    book.bids = SortedDict(Base.Order.Reverse, 100 => 500, 99 => 400, 98 => 200)
    book.asks = SortedDict(Base.Order.Forward, 103 => 400, 105 => 300, 106 => 200)
    @test to_csv(book) == "100,99,98,103,105,106,500,400,200,400,300,200"

    book = Book("", 5)
    book.bids = SortedDict(Base.Order.Reverse, 100 => 500, 99 => 400, 98 => 200)
    book.asks = SortedDict(Base.Order.Forward, 103 => 400, 105 => 300, 106 => 200)
    @test to_csv(book) == "100,99,98,,,103,105,106,,,500,400,200,,,400,300,200,,"

    book = Book("", 5)
    @test to_csv(book) == ",,,,,,,,,,,,,,,,,,,"

    book = Book("", 2)
    book.bids = SortedDict(Base.Order.Reverse, 100 => 500, 99 => 400, 98 => 200)
    book.asks = SortedDict(Base.Order.Forward, 103 => 400, 105 => 300, 106 => 200)
    @test to_csv(book) == "100,99,103,105,500,400,400,300"
end
