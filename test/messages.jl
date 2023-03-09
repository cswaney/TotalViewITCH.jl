using TotalViewITCH: split_message, complete_message!, add!, to_csv
using TotalViewITCH: AddMessage, ReplaceMessage, DeleteMessage
using TotalViewITCH: TimestampMessage, SystemEventMessage, TradeActionMessage
using Dates

date = Date("2010-01-01")

@testset "Messages" begin
    
    @test_throws ArgumentError split_message(AddMessage(date, 0, 0, 0, "AAPL", 'B', 125, 100; type='A', mpid="-"))

    @test split_message(ReplaceMessage(date, 0, 0, 123456789, 987654321, 100, 125)) == (
        OrderMessage(date, 0, 0, 'D'; refno=123456789),
        OrderMessage(date, 0, 0, 'G'; refno=123456789, newrefno=987654321, price=125, shares=100),
    )

    # complete_message! throws error for unsupported messages
    # complete_replace_message! throws error for non-replace message
    # complete_replace_message! correctly updates replace messages
    # complete_replace_add_message! throws error for non-replace-add message
    # complete_replace_add_message! correctly updates replace-add messages
    # complete_execute_message! throws error for non-execute message
    # complete_execute_message! correctly updates execute messages
    # complete_delete_message! throws error for non-delete message
    # complete_delete_message! correctly updates delete messages

end

# @testset "Messages" begin
#     # setup
#     orders = Dict{Int,Order}()
#     add_message = Message(
#         date,
#         type = "A",
#         name = "AAPL",
#         side = "B",
#         price = 125,
#         shares = 500,
#         refno = 123456789
#     )
#     add!(orders, add_message)

#     # delete message
#     delete_message = Message(
#         date,
#         type = "D",
#         refno = 123456789
#     )
#     complete!(delete_message, orders)
#     @test delete_message == Message(
#         date,
#         type = "D",
#         name = "AAPL",
#         side = "B",
#         price = 125,
#         shares = 500,
#         refno = 123456789
#     )

#     # replace message
#     replace_message = Message(
#         date,
#         type = "U",
#         price = 115,
#         shares = 200,
#         refno = 123456789,
#         newrefno = 987654321
#     )
#     _, delete_message, add_message = split_message(replace_message)
#     complete!(delete_message, orders)
#     complete!(add_message, orders)
#     @test delete_message == Message(
#         date,
#         type = "D",
#         name = "AAPL",
#         side = "B",
#         price = 125,
#         shares = 500,
#         refno = 123456789
#     )
#     @test add_message == Message(
#         date,
#         type = "A",
#         name = "AAPL",
#         side = "B",
#         price = 115,
#         shares = 200,
#         refno = 987654321
#     )

#     # execute message
#     execute_message = Message(
#         date,
#         type = "E",
#         shares = 100,
#         refno = 123456789
#     )
#     complete!(execute_message, orders)
#     @test execute_message == Message(
#         date,
#         type = "E",
#         name = "AAPL",
#         side = "B",
#         price = 125,
#         shares = 100,
#         refno = 123456789
#     )

#     # cancel message
#     cancel_message = Message(
#         date,
#         type = "C",
#         shares = 100,
#         refno = 123456789
#     )
#     complete!(cancel_message, orders)
#     @test cancel_message == Message(
#         date,
#         type = "C",
#         name = "AAPL",
#         side = "B",
#         price = 125,
#         shares = 100,
#         refno = 123456789
#     )
# end

@testset "Messages.IO" begin
    add_message = AddMessage(date, 0, 0, 123456789, "AAPL", 'B', 125, 100)
    @test to_csv(add_message) == "2010-01-01,0,0,A,-,AAPL,B,125,100,123456789,-1,-\n"
end
