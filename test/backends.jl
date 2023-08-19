using TotalViewITCH
using TotalViewITCH: build, ping, check_exists, teardown, clean, insert
using TotalViewITCH: AddMessage
using Mongoc
using Dates
using Test


@testset "Backend.FileSystem" begin

    date = Date("2017-02-27")
    backend = TotalViewITCH.FileSystem("./data")

    @test build(backend; force=true)
    @test ping(backend)["status"] == "ok"
    @test check_exists(backend)
    @test teardown(backend; force=true)
    @test !check_exists(backend)

    build(backend; force=true)
    @test insert(backend, [
        AddMessage(date, 0, 0, 123456789, "A", 'B', 125, 100),
        AddMessage(date, 0, 0, 123456789, "A", 'B', 125, 100)
    ], "messages", "A", date) == 2
    @test clean(date, "A", backend)
    teardown(backend; force=true)

end


# NOTE: this test requires mongodb running at mongodb://localhost:27017
# @testset "Backend.MongDB" begin

#     date = Date("2017-02-27")
#     backend = TotalViewITCH.MongoDB("mongodb://localhost:27017"; db_name="test")

#     @test build(backend; force=true)
#     @test ping(backend)["status"] == "ok"
#     @test check_exists(backend)
#     @test teardown(backend; force=true)
#     @test !check_exists(backend)

#     build(backend; force=true)
#     @test insert(backend, [
#             AddMessage(date, 0, 0, 123456789, "A", 'B', 125, 100),
#             AddMessage(date, 0, 0, 123456789, "A", 'B', 125, 100)
#         ],"messages", "A", date) == 2
#     @test clean(date, "A", backend)
#     teardown(backend; force=true)

# end
