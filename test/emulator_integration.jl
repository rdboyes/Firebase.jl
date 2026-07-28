# Integration tests that exercise real read/write roundtrips against a running
# Firebase Emulator Suite.
#
# `runtests.jl` starts the emulator automatically via test/emulator_process.jl when
# the Firebase CLI is installed (`npm install -g firebase-tools`, plus a JDK). These
# tests self-skip when no emulator is reachable, so the default `Pkg.test()` run stays
# green without any emulator or credentials.
#
# To drive the emulator yourself instead, start it and point the standard env vars at
# it (set FIREBASE_EMULATOR_AUTOSTART=false to stop runtests.jl spawning its own):
#
#   firebase emulators:start --project demo-firebase --config test/firebase.json \
#       --only firestore,database,auth
#   export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
#   export FIREBASE_DATABASE_EMULATOR_HOST=127.0.0.1:9000

using Firebase
using Test

@testset "Emulator integration" begin
    fs_host = Base.get(ENV, "FIRESTORE_EMULATOR_HOST", "localhost:8080")
    db_host = Base.get(ENV, "FIREBASE_DATABASE_EMULATOR_HOST", "localhost:9000")

    fs_up = emulator_running(fs_host)
    db_up = emulator_running(db_host)

    if !fs_up && !db_up
        @info "No Firebase emulator reachable; skipping integration tests." fs_host db_host
    else
        use_emulator(firestore=fs_host, database=db_host, project_id="demo-firebase",
                     detect_env=false)
        try
            if fs_up
                @testset "Firestore roundtrip" begin
                    coll = "/emulatortest_$(rand(UInt32))"
                    docid = "doc1"
                    body = Dict("fields" => Dict(
                        "greeting" => Dict("stringValue" => "hello"),
                    ))
                    firestore_createdoc(coll, body; query=docid)

                    res = get_request("$coll/$docid")
                    @test res["fields"]["greeting"]["stringValue"] == "hello"

                    firestore_deletedoc("$coll/$docid")
                end
            else
                @info "Firestore emulator not reachable; skipping Firestore roundtrip." fs_host
            end

            if db_up
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
                @info "Realtime DB emulator not reachable; skipping RTDB roundtrip." db_host
            end
        finally
            use_production()
        end
    end
end
