"""
`Buffer`

A data structure to manage writing data to CSV files.

The buffer holds lines in an array. When the buffer is full, the lines are concatenated and written to file, and the data array is then emptied.
"""
mutable struct Buffer{T}
    arr::Array{T}
    ptr::Int
    file::String
    function Buffer{T}(n, file) where {T}
        arr = Array{T}(undef, n)
        new(arr, 1, file)
    end
end

import Base.push!
function push!(buffer::Buffer, line)
    buffer.arr[buffer.ptr] = line
    # println("added line to buffer")
    if buffer.ptr == length(buffer.arr)
        println("flushing buffer...")
        write(buffer)
    else
        buffer.ptr += 1
    end
    println("(ptr = $(buffer.ptr))")
end

import Base.write
function write(buffer::Buffer, mode = "a+")
    lines = tocsv.(buffer.arr[1:buffer.ptr])
    open(buffer.file, mode) do io
        write(io, join(buffer.arr[1:buffer.ptr], '\n') * "\n")
    end
    buffer.arr = typeof(buffer.arr)(undef, length(buffer.arr))
    buffer.ptr = 1
end


"""
`Recorder`

    A data structure to manage writing data to CSV files.

    The Recorder holds lines in an array. When the Recorder is full, the lines are concatenated and written to file, and the data array is then emptied.
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
    r.buffer = ""
    r.linecount = 0
    return r
end

import Base.push!
function push!(recorder::Recorder, line)
    recorder.buffer *= line * "\n"
    # println("appended line to Recorder")
    recorder.linecount += 1
    if recorder.linecount == recorder.maxcount
        println("flushing Recorder...")
        write(recorder)
        reset!(recorder)
    end
    # println("(linecount = $(recorder.linecount))")
end

import Base.write
function write(recorder::Recorder; mode = "a+")
    open(recorder.file, mode) do io
        Base.write(io, recorder.buffer)
    end
end
