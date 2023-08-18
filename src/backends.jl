using Mongoc
using JSON

const Writable = Union{Book,OrderMessage,TradeMessage,NOIIMessage}

abstract type Backend end

function ping(b::Backend) end
function check_exists(date::Date, ticker::String, b::Backend)::Bool end
function build(b::Backend)::Bool end
function insert(b::Backend, items, collection, ticker, date)::Int end
function clean(date::Date, ticker::String, b::Backend)::Bool end
function clean(date::Date, b::Backend)::Bool end
function clean(ticker::String, b::Backend)::Bool end
function teardown(b::Backend)::Bool end

"""
    FileSystem <: Backend

...
"""
struct FileSystem <: Backend
    url
end

function ping(b::FileSystem)
    return isdir(b.url) ? Dict("status" => "ok") : Dict("status" => "error")
end

function check_exists(b::FileSystem)
    return isdir(b.url)
end

function check_exists(date::Date, ticker::String, b::FileSystem)
    return isdir(joinpath(b.url, ticker, string(date)))
end

"""
    build(b::Backend; kwargs)

Scaffold a database. The structure of the database is:

    url
     |- books
         |- aapl
            |- 20170101
            |- ...
         |- ...
     |- messages
         |- aapl
            |- 20170101
            |- ...
         |- ...
     |- trades
         |- aapl
            |- 20170101
            |- ...
         |- ...
     |- noii
         |- aapl
            |- 20170101
            |- ...
         |- ...
"""
function build(b::FileSystem; force=false)
    if check_exists(b)
        if force
            teardown(b; force=true)
        else
            resp = input("Overwrite existing database $(abspath(b.url))? (Y/n)")
            if lowercase(resp) != "y"
                @info "Database build process cancelled"

                return false
            end
        end
    end

    path = mkdir(b.url)
    mkdir(joinpath(path, "books"))
    mkdir(joinpath(path, "messages"))
    mkdir(joinpath(path, "trades"))
    mkdir(joinpath(path, "noii"))
    @info "Created database: $(abspath(b.url))"

    return true
end

function insert(items, date, ticker, collection, b::FileSystem)

    if !isdir(joinpath(b.url, collection, ticker))
        mkdir(joinpath(b.url, collection, ticker))
    end

    if !isdir(joinpath(b.url, collection, ticker, string(date)))
        mkdir(joinpath(b.url, collection, ticker, string(date)))
    end

    try
        open(joinpath(b.url, collection, ticker, string(date), "partition.csv"), "a+") do io
            write(io, join(textify.(items), ""))
        end

        return length(items)
    catch e
        throw(e)
    end

    return 0
end

textify(item::Writable) = to_csv(item)

function clean(date::Date, ticker::String, b::FileSystem)
    try
        rm(joinpath(b.url, "messages", ticker, string(date)), recursive=true)
    catch
        @debug "No order message data found for ticker=$ticker, date=$date"
    end
    
    try
        rm(joinpath(b.url, "trades", ticker, string(date)), recursive=true)
    catch
        @debug "No trade message data found for ticker=$ticker, date=$date"
    end
    
    try
        rm(joinpath(b.url, "noii", ticker, string(date)), recursive=true)
    catch
        @debug "No noii message data found for ticker=$ticker, date=$date"
    end
    
    try
        rm(joinpath(b.url, "books", ticker, string(date)), recursive=true)
    catch
        @debug "No book data found for ticker=$ticker, date=$date"
    end

    return true
end

function teardown(b::FileSystem; force=false)
    !check_exists(b) && throw(ErrorException("Database $(abspath(b.url)) not found."))

    if force
        rm(b.url, force=true, recursive=true)
        @info "Database dropped!"

        return true
    else
        resp = input("Confirm teardown of database $(abspath(b.url))? (Y/n)")
        if lowercase(resp) == "y"
            rm(b.url, force=true, recursive=true)
            @info "Database removed"

            return true
        end
        @info "Cancelled database teardown process"
    end

    return false
end

"""
    MongoDB <: Backend

...
"""
struct MongoDB <: Backend
    url
    db_name
end

MongoDB(url; db_name="totalview-itch") = MongoDB(url, db_name)

function ping(b::MongoDB)
    try
        Mongoc.ping(Mongoc.Client(b.url))
        return Dict("status" => "ok")
    catch
        return Dict("status" => "error")
    end
end

function check_exists(b::MongoDB)
    client = Mongoc.Client(b.url)
    return b.db_name in Mongoc.get_database_names(client)
end

function check_exists(date::Date, ticker::String, b::MongoDB)
    client = Mongoc.Client(b.url)
    try
        res = Mongoc.find_one(
            client[b.db_name]["messages"],
            Mongoc.BSON(
                "ticker" => ticker,
                "date" => date,
            )
        )

        return !isnothing(res)
    catch e
        throw(e)
    end
end

function build(b::MongoDB; force=false)
    if check_exists(b)
        if force
            teardown(b; force=true)
        else
            resp = input("Overwrite existing database $(b.db_name)? (Y/n)")
            if lowercase(resp) != "y"
                @info "Database build process cancelled"

                return false
            end
        end
    end

    client = Mongoc.Client(b.url)
    db = client[b.db_name]
    messages = db["messages"]
    trades = db["trades"]
    noii = db["noii"]
    books = db["books"]

    try
        resp = create_index(
            db,
            messages,
            Mongoc.BSON(
                "ticker" => 1,
                "date" => 1
            ),
            ["unique" => false],
            "ticker_date"
        )

        resp = create_index(
            db,
            trades,
            Mongoc.BSON(
                "ticker" => 1,
                "date" => 1
            ),
            ["unique" => false],
            "ticker_date"
        )

        resp = create_index(
            db,
            noii,
            Mongoc.BSON(
                "ticker" => 1,
                "date" => 1
            ),
            ["unique" => false],
            "ticker_date"
        )

        resp = create_index(
            db,
            books,
            Mongoc.BSON(
                "ticker" => 1,
                "date" => 1
            ),
            ["unique" => false],
            "ticker_date"
        )

        @info "Created database: $(b.db_name)"
        return true
    catch e
        throw(e)
    end
end

function insert(items, date, ticker, collection, b::MongoDB)
    client = Mongoc.Client(b.url)
    try
        doc = bsonify.(items)
        resp = Mongoc.insert_many(client[b.db_name][collection], doc)

        return resp.reply["nInserted"]
    catch e
        throw(e)
    end

    return 0
end

bsonify(item::Writable) = Mongoc.BSON(JSON.json(item)) # using JSON b/c we want inserts to be JSON-compatible

function find(date::Date, ticker, collection, b::MongoDB)
    client = Mongoc.Client(b.url)
    Mongoc.find(client[b.db_name][collection],
        Mongoc.BSON(
            "ticker" => ticker,
            "date" => string(date)
        )
    )
end

function create_index(db, collection::Mongoc.Collection, key::Mongoc.BSON, options::AbstractArray{Pair{String,T}}, ticker::String) where {T<:Any}
    cmd = Mongoc.BSON(
        "createIndexes" => collection.ticker,
        "indexes" => [
            Mongoc.BSON(
                "ticker" => "$(ticker)_index",
                "key" => key,
                options...
            )
        ]
    )
    try
        resp = Mongoc.write_command(db, cmd)
        return resp["ok"] == 1
    catch e
        throw(e)
    end
end

function clean(date::Date, ticker::String, b::MongoDB)
    client = Mongoc.Client(b.url)
    try
        Mongoc.delete_many(
            client[b.db_name]["messages"],
            Mongoc.BSON(
                "ticker" => ticker,
                "date" => string(date)
            )
        )
        Mongoc.delete_many(
            client[b.db_name]["trades"],
            Mongoc.BSON(
                "ticker" => ticker,
                "date" => string(date)
            )
        )
        Mongoc.delete_many(
            client[b.db_name]["noii"],
            Mongoc.BSON(
                "ticker" => ticker,
                "date" => string(date)
            )
        )
        Mongoc.delete_many(
            client[b.db_name]["books"],
            Mongoc.BSON(
                "ticker" => ticker,
                "date" => string(date)
            )
        )

        return true
    catch e
        throw(e)
    end
end

function teardown(b::MongoDB; force=false)
    client = Mongoc.Client(b.url)

    if !check_exists(b)
        throw(ErrorException("Database $(b.db_name) not found."))
    end

    if force
        try
            Mongoc.drop(client[b.db_name])
            @info "Database dropped!"

            return true
        catch e
            throw(e)
        end
    else
        resp = input("Confirm teardown of database $(b.db_name))? (Y/n)")
        if lowercase(resp) == "y"
            try
                Mongoc.drop(client[b.db_name])
                @info "Database dropped!"

                return true

            catch e
                throw(e)
            end
        end
        @info "Cancelled database teardown process"
    end

    return false
end