using TotalViewITCH
using Test
using Dates

@testset verbose = true "TotalViewITCH.jl" begin

    @testset "messages" begin
        include("messages.jl")
    end

    @testset "orderbooks" begin
        # include("orderbooks.jl")
    end

    @testset "database" begin
        # include("database.jl")
    end

    @testset "process" begin
        # include("process.jl")
    end

    # @static if VERSION == v"1.6"
    #     using Documenter
    #     @testset "Docs" begin
    #         DocMeta.setdocmeta!(Flux, :DocTestSetup, :(using Flux); recursive=true)
    #         doctest(Flux)
    #     end
    # end

end


