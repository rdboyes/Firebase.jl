# Integration tests that exercise real read/write roundtrips against a running
# Firebase Emulator Suite.
#
# `runtests.jl` starts the emulator automatically via test/emulator_process.jl when
# the Firebase CLI is installed (`npm install -g firebase-tools`, plus a JDK). Each
# service's tests self-skip when that emulator is not reachable, so the default
# `Pkg.test()` run stays green without any emulator or credentials.
#
# To drive the emulator yourself instead, start it and point the standard env vars at
# it (set FIREBASE_EMULATOR_AUTOSTART=false to stop runtests.jl spawning its own):
#
#   firebase emulators:start --project demo-firebase --config test/firebase.json \
#       --only firestore,database,auth,storage
#   export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
#   export FIREBASE_DATABASE_EMULATOR_HOST=127.0.0.1:9000

using Firebase
using Test
using Dates
using HTTP, JSON

@testset "Emulator integration" begin
    hosts = Dict(
        :firestore => Base.get(ENV, "FIRESTORE_EMULATOR_HOST", "localhost:8080"),
        :database  => Base.get(ENV, "FIREBASE_DATABASE_EMULATOR_HOST", "localhost:9000"),
        :auth      => Base.get(ENV, "FIREBASE_AUTH_EMULATOR_HOST", "localhost:9099"),
        :storage   => Base.get(ENV, "FIREBASE_STORAGE_EMULATOR_HOST", "localhost:9199"),
    )
    up = Dict(service => emulator_running(host) for (service, host) in hosts)

    if !any(values(up))
        @info "No Firebase emulator reachable; skipping integration tests." hosts...
    else
        use_emulator(firestore=hosts[:firestore], database=hosts[:database],
                     auth=hosts[:auth], storage=hosts[:storage],
                     project_id="demo-firebase", detect_env=false)
        try
            if up[:firestore]
                include("integration_firestore.jl")
            else
                @info "Firestore emulator not reachable; skipping." host=hosts[:firestore]
            end

            if up[:database]
                @testset "Realtime DB roundtrip" begin
                    hdrs = [auth_header()]                # ["Authorization" => "Bearer owner"]
                    path = "/emulatortest_$(rand(UInt32))"

                    realdb_put(path, hdrs, Dict("first" => "ash"))
                    @test realdb_get(path, hdrs) == Dict("first" => "ash")

                    realdb_patch(path, hdrs, Dict("last" => "rathee"))
                    @test realdb_get(path, hdrs) ==
                          Dict("first" => "ash", "last" => "rathee")

                    realdb_delete(path, hdrs)
                    @test realdb_get(path, hdrs) === nothing
                end
            else
                @info "Realtime DB emulator not reachable; skipping." host=hosts[:database]
            end

            if up[:auth]
                include("integration_auth.jl")
            else
                @info "Auth emulator not reachable; skipping." host=hosts[:auth]
            end

            if up[:storage]
                include("integration_storage.jl")
            else
                @info "Storage emulator not reachable; skipping." host=hosts[:storage]
            end
        finally
            use_production()
        end
    end
end
