# using Pkg
# Pkg.activate(".")
using Documenter, TotalViewITCH

makedocs(
    sitename="TotalViewITCH.jl",
    modules=[TotalViewITCH],
    pages=[
        "Home" => "index.md",
        "API" => "api.md",
    ]
)

deploydocs(
    repo="github.com/cswaney/TotalViewITCH.jl.git",
    devbranch="dev"
)
