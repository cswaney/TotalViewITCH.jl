using Revise
using Pkg
Pkg.activate(".")
using TotalViewITCH
using Dates

file = "./data/bin/S031413-v41.txt"
version = 4.1
date = Date("2013-03-14")
nlevels = 3
tickers = ["ALT"]
dir = "./data/csv"
process(file, version, date, nlevels, tickers, dir)
