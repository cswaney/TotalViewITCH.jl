using TotalViewITCH
using TotalViewITCH: build, ping, check_exists, teardown, clean, insert
using TotalViewITCH: AddMessage
using Mongoc
using Dates
using Test

# NOTE: this test requires mongodb running at mongodb://localhost:27017

@testset "Backend.FileSystem" begin

    date = Date("2017-02-27")
    backend = TotalViewITCH.FileSystem("data/test")

    @test build(backend; force=true)
    @test ping(backend)["status"] == "ok"
    @test check_exists(backend)
    @test teardown(backend; force=true)
    @test !check_exists(backend)

    build(backend; force=true)
    @test insert([
        AddMessage(date, 0, 0, 123456789, "A", 'B', 125, 100),
        AddMessage(date, 0, 0, 123456789, "A", 'B', 125, 100)
    ], date, "A", "messages", backend) == 2
    @test clean(date, "A", backend)

end

@testset "Backend.MongDB" begin

    date = Date("2017-02-27")
    backend = TotalViewITCH.MongoDB("mongodb://localhost:27017"; db_name="test")

    @test build(backend; force=true)
    @test ping(backend)["status"] == "ok"
    @test check_exists(backend)
    @test teardown(backend; force=true)
    @test !check_exists(backend)

    build(backend; force=true)
    @test insert([
            AddMessage(date, 0, 0, 123456789, "A", 'B', 125, 100),
            AddMessage(date, 0, 0, 123456789, "A", 'B', 125, 100)
        ], date, "A", "messages", backend) == 2
    @test clean(date, "A", backend)

end
