using Firebase
using Test
using HTTP, JSON

include("emulator_process.jl")

@testset "Firebase" begin
    # Pure unit tests — always run, no network or credentials required.
    include("emulator.jl")
    include("cloudstorage.jl")

    # Integration tests against an emulator. If one is already running we reuse it;
    # otherwise we try to start the Firebase Emulator Suite ourselves and shut it
    # down afterwards. When neither is possible the tests self-skip.
    emulator = EmulatorProcess.start()
    try
        include("emulator_integration.jl")
    finally
        EmulatorProcess.stop(emulator)
    end

    # Legacy live-Firebase tests. These need a private service-account JSON and hit a
    # real project, so they are opt-in via FIREBASE_LIVE_TESTS=true.
    if Base.get(ENV, "FIREBASE_LIVE_TESTS", "") == "true"
        include("realtime.jl")
        include("firestore.jl")
    end
end
