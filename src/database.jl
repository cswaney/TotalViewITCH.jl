using Mongoc
using Mongoc: BSON, Client, Collection
using Mongoc: insert_many, write_command
using JSON

"""
    build(dir)

Scaffold a database at `dir`. The structure of the database is:

    dir
     |- books
         |- aapl.csv
         |- ...
     |- messages
         |- aapl.csv
         |- ...
     |- trades
         |- aapl.csv
         |- ...
     |- noii
         |- aapl.csv
         |- ...
"""
function build(dir; force = false)
    if isdir(dir)
        if !force
            resp = input("Overwrite existing directory: $(abspath(dir))? (y/n)")
            if lowercase(resp) != "y"
                @info "Database build process cancelled"
                return false
            end
        end
        rm(dir, force = true, recursive = true)
    end
    path = mkdir(dir)
    mkdir(joinpath(path, "books"))
    mkdir(joinpath(path, "messages"))
    mkdir(joinpath(path, "trades"))
    mkdir(joinpath(path, "noii"))
    @info "Created database: $(abspath(dir))"
    return true
end

"""

    url = "mongodb://localhost:27017"
"""
function build_mongo(url; db_name="totalview-itch")

    # connect to client
    client = Client(url)

    # connect database
    db = client[db_name]

    # get/create collections
    messages = db["messages"]
    orderbooks = db["orderbooks"]
    trades = db["trades"]
    noii = db["noii"]

    # create indices
    resp = create_index(
        db,
        messages,
        BSON(
            "ticker" => 1,
            "date" => 1
        ),
        ["unique" => true],
        "ticker_date"
    )

end

function create_index(db, collection::Collection, key::BSON, options::AbstractArray{Pair{String,T}}, name::String) where {T<:Any}
    cmd = BSON(
        "createIndexes" => collection.name,
        "indexes" => [
            BSON(
                "name" => "$(name)_index",
                "key" => key,
                options...
            )
        ]
    )
    resp = write_command(db, cmd)
    if resp["ok"] == 1
        return resp
    else
        # TODO capture the error and raise?
        return println(resp)
    end
end

"""
    teardown(dir; <kwargs>)

Delete a database at `dir`.
"""
function teardown(dir; force = false)
    !isdir(dir) && throw(ArgumentError("Unable to tear down database (directory $(abspath(dir)) not found)."))
    if force
        rm(dir, force = true, recursive = true)
        @info "Database removed"
        return true        
    else
        resp = input("Confirm teardown of database: $(abspath(dir))? (y/n)")
        if lowercase(resp) == "y"
            rm(dir, force = true, recursive = true)
            @info "Database removed"
            return true
        end
        @info "Cancelled database teardown process"
    end
    return false
end

function teardown_mongo(url; db_name="totalview-itch", force = false)
    client = Client(url)
    if !(db_name in Mongoc.get_database_names(client))
        throw(ArgumentError("Unable to tear down database (database $(db_name) not found)."))
    end
    if force
        Mongoc.drop(client["totalview-itch"])
        @info "Database removed"
        return true
    else
        resp = input("Confirm teardown of database: $(db_name))? (y/n)")
        if lowercase(resp) == "y"
            Mongoc.drop(client["totalview-itch"])
            @info "Database removed"
            return true
        end
        @info "Cancelled database teardown process"
    end
    return false
end

function input(prompt)
    println(prompt)
    resp = readline()
    return resp
end

"""
    Recorder

A data structure to manage writing data to CSV files.

The Recorder holds lines in a string. When the Recorder is full, the string is written to file and the string is emptied.

Note that `push!` adds an end-of-line character to `line`. Thus, lines pushed to `Recorder`s should **not** include '\n'.
"""
mutable struct Recorder
    buffer::String
    maxcount::Int
    linecount::Int
    file::String
    function Recorder(maxcount, file)
        new("", maxcount, 0, file)
    end
end

function reset!(r::Recorder)
    @debug "resetting recorder..."
    r.buffer = ""
    r.linecount = 0
    return r
end

import Base.push!
function push!(recorder::Recorder, line)
    @debug "pushing new line to recorder..."
    recorder.buffer *= line
    recorder.linecount += 1
    if recorder.linecount == recorder.maxcount
        write(recorder)
        reset!(recorder)
    end
    @debug "new linecount: $(recorder.linecount)"
end

import Base.write
function write(recorder::Recorder; mode = "a+")
    @debug "writing recorder contents to file..."
    open(recorder.file, mode; lock = true) do io
        Base.write(io, recorder.buffer)
    end
end


"""

A object that stores messages and (async?) inserts into a MongoDB whenever it is full.

### Methods
- ``: reset the message buffer and write statistics.
- `push!`: add a message to the message buffer.
- `write!`: insert messages to MongoDB, update write statistics, and reset the message buffer. 

### Fields
`db`:
`buffer`: a fixed-length array that stores messages.
`ptr`: a pointer to the current location in the buffer.
"""
mutable struct MongoWriter{T<:AbstractMessage,N}
    col::Collection
    buffer::Vector{T} # could be StaticVector?
    ptr::Int

    function MongoWriter{T,N}(col::Collection) where {T<:AbstractMessage,N}
        return new(col, Vector{T}(undef, N), 1)
    end
end

Base.length(w::MongoWriter) = length(w.buffer)

function Base.push!(w::MongoWriter, message)
    w.buffer[w.ptr] = message
    w.ptr += 1
    w.ptr > length(w.buffer) && write(w)
    return
end

function Base.write(w::MongoWriter)
    doc = bsonify.(w.buffer)
    resp = Mongoc.insert_many(w.col, doc)
    # TODO: how to handle failures here?
    reset(w)
    return resp.reply["nInserted"]
end

Base.position() = w.ptr

function Base.reset(w)
    w.ptr = 1
end

bsonify(m::AbstractMessage) = BSON(JSON.json(m)) # using JSON b/c we want inserts to be JSON-compatible