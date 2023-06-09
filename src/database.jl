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
