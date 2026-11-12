
push!(LOAD_PATH,"../src/")
using Firebase
using Documenter

DocMeta.setdocmeta!(Firebase, :DocTestSetup, :(using Firebase); recursive=true)

makedocs(;
    modules=[Firebase],
    authors="Ashwani Rathee",
    repo=Remotes.GitHub("rdboyes", "Firebase.jl"),
    sitename="Firebase.jl",
    format=Documenter.HTML(;
        prettyurls=Base.get(ENV, "CI", "false") == "true",
        canonical="https://rdboyes.github.io/Firebase.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Cloud Firestore" => "firestore.md",
        "Cloud Authentication" => "authentication.md",
        "Realtime Database" => "realtime.md",
        "Cloud Storage" => "storage.md",
        "Emulator" => "emulator.md",
        "Utility Functions" => "utility.md",
    ],
)

deploydocs(;
    repo="github.com/rdboyes/Firebase.jl",
    devbranch="main",
    push_preview = true
) 