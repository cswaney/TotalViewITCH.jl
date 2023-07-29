using TotalViewITCH
using TotalViewITCH: SystemEventMessage, MongoWriter
using DataStructures: SortedDict
using Mongoc
using Dates
using Test


"""Note: these tests require access to a MongoDB database."""


client = Mongoc.Client("mongodb://localhost:27017")
db = client["test"]
writer = MongoWriter{SystemMessage,3}(db["messages"])


@testset "MongoWriter.Message" begin
    
    date = Date("2023-01-01")
    messages = [
        SystemEventMessage(date, 0, 0, 'O'),
        SystemEventMessage(date, 0, 0, 'S'),
        SystemEventMessage(date, 0, 0, 'Q'),
        SystemEventMessage(date, 0, 0, 'M'),
        SystemEventMessage(date, 0, 0, 'E'),
        SystemEventMessage(date, 0, 0, 'C'),
    ]

    push!(writer, messages[1])
    @test writer.ptr == 2
    push!(writer, messages[2])
    push!(writer, messages[3])
    @test writer.ptr == 1    
    push!(writer, messages[1])
    reset(writer)
    @test writer.ptr == 1

end

client = Mongoc.Client("mongodb://localhost:27017")
db = client["test"]
writer = MongoWriter{Book,3}(db["books"])

@testset "MongoWriter.Book" begin

    book = Book("", 3)
    book.bids = SortedDict(Base.Order.Reverse, 100 => 500, 99 => 400, 98 => 200)
    book.asks = SortedDict(Base.Order.Forward, 103 => 400, 105 => 300, 106 => 200)
    push!(writer, book)
    
    @test TotalViewITCH.position(writer) == 2

    book = Book("", 3)
    book.bids = SortedDict(Base.Order.Reverse, 100 => 500, 99 => 400, 98 => 200)
    book.asks = SortedDict(Base.Order.Forward, 103 => 400, 105 => 300, 106 => 200)
    push!(writer, book)
    
    book = Book("", 3)
    book.bids = SortedDict(Base.Order.Reverse, 100 => 500, 99 => 400, 98 => 200)
    book.asks = SortedDict(Base.Order.Forward, 103 => 400, 105 => 300, 106 => 200)
    push!(writer, book)

    @test TotalViewITCH.position(writer) == 1

end
