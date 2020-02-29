using Revise
using Pkg
Pkg.activate(".")
using TotalViewITCH
using Dates

file = "/Users/colinswaney/Data/itch/bin/S031413-v41.txt"
version = 4.1
date = Date("2013-03-14")
nlevels = 3
tickers = ["ALT"]
dir = "/Users/colinswaney/Desktop/Development/TotalViewITCH/data"
process(file, version, date, nlevels, tickers, dir)
