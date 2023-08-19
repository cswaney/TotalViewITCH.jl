using TotalViewITCH
using TotalViewITCH: Buffer, FileSystem, OrderMessage, AddMessage, MongoDB, build, write, flush, reset
using Dates
using Test


@testset "Buffer.FileSystem" begin
    
    date = Date("2017-02-27")
    backend = FileSystem("../data/test")
    build(backend; force=true)

    buffer = Buffer{FileSystem,OrderMessage}(["A"], backend, "messages", date, 2)

    @test_throws KeyError write(buffer, AddMessage(date, 0, 0, 123456789, "AAPL", 'B', 125, 100)) # missing ticker

    write(buffer, AddMessage(date, 0, 0, 123456789, "A", 'B', 125, 100))
    @test buffer.ptrs["A"] == 2 # buffer inserts

    write(buffer, AddMessage(date, 0, 0, 123456789, "A", 'S', 127, 100))
    @test buffer.cnt == 2 # buffer flushes all items
    @test buffer.ptrs["A"] == 1 # buffer resets

    write(buffer, AddMessage(date, 0, 0, 123456789, "A", 'B', 124, 100))
    flush(buffer, "A")
    @test buffer.cnt == 3 # buffer flushes 1 item
    @test buffer.ptrs["A"] == 1 # buffer resets

    write(buffer, AddMessage(date, 0, 0, 123456789, "A", 'S', 128, 100))
    reset(buffer, "A")
    @test buffer.ptrs["A"] == 1 # buffer resets

end


# NOTE: this test requires mongodb running at mongodb://localhost:27017
@testset "Buffer.MongoDB" begin

    date = Date("2017-02-27")
    backend = MongoDB("mongodb://localhost:27017"; db_name="test")
    build(backend; force=true)

    buffer = Buffer{MongoDB,OrderMessage}(["A"], backend, "messages", date, 2)

    @test_throws KeyError write(buffer, AddMessage(date, 0, 0, 123456789, "AAPL", 'B', 125, 100)) # missing ticker

    write(buffer, AddMessage(date, 0, 0, 123456789, "A", 'B', 125, 100))
    @test buffer.ptrs["A"] == 2 # buffer inserts

    write(buffer, AddMessage(date, 0, 0, 123456789, "A", 'S', 127, 100))
    @test buffer.cnt == 2 # buffer flushes all items
    @test buffer.ptrs["A"] == 1 # buffer resets

    write(buffer, AddMessage(date, 0, 0, 123456789, "A", 'B', 124, 100))
    flush(buffer, "A")
    @test buffer.cnt == 3 # buffer flushes 1 item
    @test buffer.ptrs["A"] == 1 # buffer resets

    write(buffer, AddMessage(date, 0, 0, 123456789, "A", 'S', 128, 100))
    reset(buffer, "A")
    @test buffer.ptrs["A"] == 1 # buffer resets

end