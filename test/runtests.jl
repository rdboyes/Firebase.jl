using Firebase
using Test
using HTTP, JSON


@testset "Firebase" begin
    # Pure unit tests — always run, no network or credentials required.
    include("emulator.jl")

    # Integration tests against a running emulator — self-skip when none is reachable.
    include("emulator_integration.jl")

    # Legacy live-Firebase tests. These need a private service-account JSON and hit a
    # real project, so they are opt-in via FIREBASE_LIVE_TESTS=true.
    if Base.get(ENV, "FIREBASE_LIVE_TESTS", "") == "true"
        include("realtime.jl")
        include("firestore.jl")
    end
end
