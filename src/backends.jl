using Mongoc
using JSON
using CSV
using DataFrames

const Writable = Union{Book,OrderMessage,TradeMessage,NOIIMessage}

abstract type Backend end

function ping(b::Backend) end
function check_exists(date::Date, ticker::String, b::Backend)::Bool end
function build(b::Backend)::Bool end
function insert(b::Backend, items, collection, ticker, date)::Int end
function find(b::Backend, collection, ticker, date) end
function clean(date::Date, ticker::String, b::Backend)::Bool end
function clean(date::Date, b::Backend)::Bool end
function clean(ticker::String, b::Backend)::Bool end
function teardown(b::Backend)::Bool end

"""
    FileSystem <: Backend

A backend for storing data to the local file system.

Data is stored with the following directory structure:

root
|- collection
   |- ticker
      |- date
         |- partition.csv
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
    return isdir(joinpath(b.url, "messages", ticker, string(date)))
end

"""
    build(b::Backend; kwargs)

Scaffold a database. By default, the program prompts the user to overwrite
existing files. Set `force=true` to overwrite existing files without prompting.
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
            else
                teardown(b; force=true)
            end
        end
    end

    path = mkdir(b.url)
    mkdir(joinpath(path, "orderbooks"))
    mkdir(joinpath(path, "messages"))
    mkdir(joinpath(path, "trades"))
    mkdir(joinpath(path, "noii"))
    @info "Created database: $(abspath(b.url))"

    return true
end

function insert(b::FileSystem, items, collection, ticker, date)

    
    if length(items) > 0
        if collection in ["messages", "orderbooks"]
            if !isdir(joinpath(b.url, collection, "ticker=$ticker"))
                mkdir(joinpath(b.url, collection, "ticker=$ticker"))
            end
        
            if !isdir(joinpath(b.url, collection, "ticker=$ticker", "date=$date"))
                mkdir(joinpath(b.url, collection, "ticker=$ticker", "date=$date"))
            end
        else
            if !isdir(joinpath(b.url, collection, "date=$date"))
                mkdir(joinpath(b.url, collection, "date=$date"))
            end
        end

        try
            if collection in ["messages", "orderbooks"]
                open(joinpath(b.url, collection, "ticker=$ticker", "date=$date", "partition.csv"), "a+") do io
                    write(io, join(textify.(items), ""))
                end
            else
                open(joinpath(b.url, collection, "date=$date", "partition.csv"), "a+") do io
                    write(io, join(textify.(items), ""))
                end
            end
            n = length(items)
            @info "Inserted $n items to collection: $(collection)"

            return length(items)
        catch e
            throw(e)
        end
    end

    @info "Inserted 0 items to collection: $collection"

    return 0
end

const headers = Dict(
    "messages" => [
        "date",
        "sec",
        "nano",
        "type",
        "event",
        "ticker",
        "side",
        "price",
        "shares",
        "refno",
        "newrefno",
        "mpid",
    ]
)

const types = Dict(
    "messages" => Dict(
        "date" => Date,
        "sec" => Int64,
        "nano" => Int64,
        "type" => Char,
        "event" => Char,
        "ticker" => String7,
        "side" => Char,
        "price" => Int64,
        "shares" => Int64,
        "refno" => Int64,
        "newrefno" => Int64,
        "mpid" => String7,
    ),
    "orderbooks" => Dict(
        
    ),
    "noii" => Dict(
        
    ),
    "trades" => Dict(

    )
)

"""
    find(b::FileSystem, collection, ticker, date)

Finds all data for the provided collection, ticker and date and returns a
`DataFrame`.
"""
function find(b::FileSystem, collection, ticker, date)
    try
        if collection in ["messages", "orderbooks"]
            df = CSV.File(joinpath(b.url, collection, "ticker=$ticker", "date=$date", "partition.csv"), header=headers[collection]) |> DataFrame
        else
            df = CSV.File(joinpath(b.url, collection, "date=$date", "partition.csv"), header=headers[collection]) |> DataFrame
        end

        return df
    catch
        throw(e)
    end
end

textify(item::Writable) = to_csv(item)

"""
    clean(date::Date, ticker::String, b::FileSystem)

Remove all data found for the provided date and ticker.
"""
function clean(date::Date, ticker::String, b::FileSystem)
    try
        rm(joinpath(b.url, "messages", "ticker=$ticker", "date=$date"), recursive=true)
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

"""
    teardown(b::FileSystem)

Remove all database files. Set `force=true` to skip the default confirmation
prompt.
"""
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
            @info "Database dropped!"

            return true
        end
        @info "Cancelled database teardown process."
    end

    return false
end

"""
    MongoDB <: Backend

A backend for storing data to MongoDB.

The default database name is "totalview-itch", which contains the following 
collections:

- messages
- orderbooks
- noii
- trades

All collections are indexed by ticker and date fields.
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
            bsonify(Dict(
                "ticker" => ticker,
                "date" => date,
            ))
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
                @info "Database build process cancelled."

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

function insert(b::MongoDB, items, collection, ticker::String, date::Date)
    client = Mongoc.Client(b.url)

    if length(items) > 0
        try
            doc = bsonify.(items)
            resp = Mongoc.insert_many(client[b.db_name][collection], doc)
            n = resp.reply["nInserted"]
            @info "Inserted $n items to collection: $(collection)"

            return n
        catch e
            throw(e)
        end
    end

    @info "Inserted 0 items to collection: $collection"

    return 0
end

function find(b::MongoDB, collection, ticker, date)
    client = Mongoc.Client(b.url)

    try
        doc = bsonify(Dict(
            "ticker" => ticker,
            "date" => string(date)
        ))
        res = Mongoc.find(client[b.db_name][collection], doc)

        return res
    catch e
        throw(e)
    end
end

bsonify(item) = Mongoc.BSON(JSON.json(item)) # using JSON b/c we want inserts to be JSON-compatible

function create_index(db, collection::Mongoc.Collection, key::Mongoc.BSON, options::AbstractArray{Pair{String,T}}, name::String) where {T<:Any}
    cmd = Mongoc.BSON(
        "createIndexes" => collection.name,
        "indexes" => [
            Mongoc.BSON(
                "name" => "$(name)_index",
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