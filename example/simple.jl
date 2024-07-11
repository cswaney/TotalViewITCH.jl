"""
A simple example demonstrating how to parse and read data for a single ticker.

To run with MongoDB backend, first start a local MongoDB server:
```shell
docker run -p 27017:27017 -v ./data/db:/data/db mongo:latest
```
"""

using TotalViewITCH: Parser, Backend, FileSystem, MongoDB, find
using Dates

# Storing results in local file system
parser = Parser{FileSystem}("./data/test")
parser("./data/bin/S031413-v41.txt", Date("2013-03-14"), ["A", "B"], 4.1)
df = find(parser.backend, "messages", "A", Date("2013-03-14"))

# Storing results in MongoDB
backend = MongoDB("mongodb://localhost:27017", "test")
parser = Parser(backend)
parser("./data/bin/S031413-v41.txt", Date("2013-03-14"), ["A", "B"], 4.1)
res = find(backend, "messages", "A", Date("2013-03-14"))
dat = Dict.(res)
