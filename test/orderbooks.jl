using TotalViewITCH: add!, update!, to_csv, AddMessage, ExecuteMessage, CancelMessage, DeleteMessage
using Dates
using DataStructures: SortedDict
using Base.Order: Reverse, Forward

date = Date("2010-01-01")
nlevels = 3

@testset "Orders" begin

    orders = Dict{Int,Order}()

    # non-add
    non_add_message = OrderMessage(date, 0, 0, 'U')
    @test_throws ArgumentError TotalViewITCH.add!(orders, non_add_message)

    # add order
    add_message = AddMessage(date, 0, 0, 123456789, "AAPL", 'B', 125, 500)
    TotalViewITCH.add!(orders, add_message)
    @test get(orders, 123456789, nothing) == Order("AAPL", 'B', 125, 500)

    # duplicate
    @test_throws ErrorException TotalViewITCH.add!(orders, add_message)

    # delete order
    delete_message = DeleteMessage(date, 0, 0, 123456789)
    TotalViewITCH.update!(orders, delete_message)
    @test isnothing(get(orders, 123456789, nothing))

    # execute order
    TotalViewITCH.add!(orders, add_message)
    execute_message = ExecuteMessage(date, 0, 0, 123456789, 100)
    TotalViewITCH.update!(orders, execute_message)
    @test get(orders, 123456789, nothing) == Order("AAPL", 'B', 125, 400)

    # execute order (exhaustive)
    execute_message = ExecuteMessage(date, 0, 0, 123456789, 400)
    TotalViewITCH.update!(orders, execute_message)
    @test isnothing(get(orders, 123456789, nothing))

    # cancel order
    TotalViewITCH.add!(orders, add_message)
    cancel_message = CancelMessage(date, 0, 0, 123456789, 100)
    TotalViewITCH.update!(orders, cancel_message)
    @test get(orders, 123456789, nothing) == Order("AAPL", 'B', 125, 400)

    # cancel order (exhaustive)
    cancel_message = CancelMessage(date, 0, 0, 123456789, 400)
    TotalViewITCH.update!(orders, cancel_message)
    @test isnothing(get(orders, 123456789, nothing))

    # missing order
    delete_message = DeleteMessage(date, 0, 0, 123456789)
    @test_logs (:warn, "Unable to update order (missing reference number 123456789)") update!(orders, delete_message)
end

@testset "Books" begin

    # setup
    book = Book("AAPL", nlevels)

    # non-matching message
    non_matching_message = OrderMessage(date, 0, 0, 'A'; name="AA", side='B', price=125, shares=500)
    @test_throws ArgumentError TotalViewITCH.update!(book, non_matching_message)

    # add message (bid)
    add_message = OrderMessage(date, 0, 0, 'A'; name="AAPL", side='B', price=125, shares=500)
    TotalViewITCH.update!(book, add_message)
    @test get(book.bids, 125, nothing) == 500

    # execute (bid, missing)
    execute_message = OrderMessage(date, 0, 0, 'E'; name="AAPL", side='B', price=120, shares=100)
    @test_throws ErrorException TotalViewITCH.update!(book, execute_message)

    # execute message (bid, under)
    execute_message = OrderMessage(date, 0, 0, 'E'; name="AAPL", side='B', price=125, shares=100)
    TotalViewITCH.update!(book, execute_message)
    @test get(book.bids, 125, nothing) == 400

    # execute message (bid, exhaust)
    execute_message = OrderMessage(date, 0, 0, 'E'; name="AAPL", side='B', price=125, shares=400)
    TotalViewITCH.update!(book, execute_message)
    @test isnothing(get(book.bids, 125, nothing))

    # execute message (bid, over)
    execute_message = OrderMessage(date, 0, 0, 'E'; name="AAPL", side='B', price=125, shares=100)
    @test_throws ErrorException TotalViewITCH.update!(book, execute_message)

    # add message (ask)
    add_message = OrderMessage(date, 0, 0, 'A'; name="AAPL", side='A', price=130, shares=500)
    TotalViewITCH.update!(book, add_message)
    @test get(book.asks, 130, nothing) == 500

    # execute (ask, missing)
    execute_message = OrderMessage(date, 0, 0, 'E'; name="AAPL", side='A', price=135, shares=100)
    @test_throws ErrorException TotalViewITCH.update!(book, execute_message)

    # execute message (ask, under)
    execute_message = OrderMessage(date, 0, 0, 'E'; name="AAPL", side='A', price=130, shares=100)
    TotalViewITCH.update!(book, execute_message)
    @test get(book.asks, 130, nothing) == 400

    # execute message (ask, exhaust)
    execute_message = OrderMessage(date, 0, 0, 'E'; name="AAPL", side='A', price=130, shares=400)
    TotalViewITCH.update!(book, execute_message)
    @test isnothing(get(book.asks, 130, nothing))

    # execute message (ask, over)
    execute_message = OrderMessage(date, 0, 0, 'E'; name="AAPL", side='A', price=130, shares=100)
    @test_throws ErrorException TotalViewITCH.update!(book, execute_message)

end

@testset "Books.IO" begin

    book = Book("", 3)
    book.bids = SortedDict(Base.Order.Reverse, 100 => 500, 99 => 400, 98 => 200)
    book.asks = SortedDict(Base.Order.Forward, 103 => 400, 105 => 300, 106 => 200)
    @test to_csv(book) == "100,99,98,103,105,106,500,400,200,400,300,200\n"

    book = Book("", 5)
    book.bids = SortedDict(Base.Order.Reverse, 100 => 500, 99 => 400, 98 => 200)
    book.asks = SortedDict(Base.Order.Forward, 103 => 400, 105 => 300, 106 => 200)
    @test to_csv(book) == "100,99,98,,,103,105,106,,,500,400,200,,,400,300,200,,\n"

    book = Book("", 5)
    @test to_csv(book) == ",,,,,,,,,,,,,,,,,,,\n"

    book = Book("", 2)
    book.bids = SortedDict(Base.Order.Reverse, 100 => 500, 99 => 400, 98 => 200)
    book.asks = SortedDict(Base.Order.Forward, 103 => 400, 105 => 300, 106 => 200)
    @test to_csv(book) == "100,99,103,105,500,400,400,300\n"
end
