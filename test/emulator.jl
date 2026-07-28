# Pure unit tests for emulator configuration and URL construction.
# These require no network and no Firebase credentials, so they always run.

using Firebase
using Test

@testset "Emulator config" begin

    # Ensure a clean starting state.
    Firebase.use_production()

    @testset "production defaults" begin
        @test Firebase.emulator_active(:firestore) == false
        @test Firebase.emulator_active(:database) == false
        @test Firebase.emulator_active(:auth) == false
        @test Firebase.emulator_active(:storage) == false
        @test Firebase.firestore_url() == "https://firestore.googleapis.com/v1"
        @test Firebase.auth_url() == "https://identitytoolkit.googleapis.com/v1"
    end

    @testset "explicit use_emulator" begin
        use_emulator(firestore=true, database=true, auth=true, storage=true,
                     project_id="demo-firebase", detect_env=false)

        @test emulator_active(:firestore)
        @test emulator_active(:database)
        @test emulator_active(:auth)
        @test emulator_active(:storage)

        @test Firebase.firestore_url() == "http://localhost:8080/v1"
        @test Firebase.auth_url() ==
              "http://localhost:9099/identitytoolkit.googleapis.com/v1"
        @test Firebase.database_ns() == "demo-firebase-default-rtdb"

        # Realtime DB / Storage globals are pointed at the emulator.
        @test Firebase.BASE_URL == "http://localhost:9000"
        @test Firebase.STORE_URL ==
              "http://localhost:9199/v0/b/demo-firebase.appspot.com/o/"

        Firebase.use_production()
    end

    @testset "custom host and explicit host:port" begin
        use_emulator(host="127.0.0.1", firestore=true, detect_env=false)
        @test Firebase.firestore_url() == "http://127.0.0.1:8080/v1"
        Firebase.use_production()

        use_emulator(firestore="192.168.1.5:9090", detect_env=false)
        @test Firebase.firestore_url() == "http://192.168.1.5:9090/v1"
        @test emulator_active(:auth) == false   # only firestore requested
        Firebase.use_production()
    end

    @testset "env var detection" begin
        # Save and set the standard Firebase emulator env vars.
        saved = Dict(k => Base.get(ENV, k, nothing) for k in
                     ("FIRESTORE_EMULATOR_HOST", "FIREBASE_DATABASE_EMULATOR_HOST",
                      "FIREBASE_AUTH_EMULATOR_HOST", "FIREBASE_STORAGE_EMULATOR_HOST"))
        try
            ENV["FIRESTORE_EMULATOR_HOST"] = "localhost:8080"
            ENV["FIREBASE_AUTH_EMULATOR_HOST"] = "localhost:9099"
            delete!(ENV, "FIREBASE_DATABASE_EMULATOR_HOST")
            delete!(ENV, "FIREBASE_STORAGE_EMULATOR_HOST")

            use_emulator(project_id="env-demo")   # detect_env defaults to true

            @test emulator_active(:firestore)
            @test emulator_active(:auth)
            @test emulator_active(:database) == false
            @test emulator_active(:storage) == false
            @test Firebase.firestore_url() == "http://localhost:8080/v1"
            @test Firebase.database_ns() == "env-demo-default-rtdb"
        finally
            for (k, v) in saved
                v === nothing ? delete!(ENV, k) : (ENV[k] = v)
            end
            Firebase.use_production()
        end
    end

    @testset "auth_header short-circuit in emulator mode" begin
        # No credentials loaded; emulator mode must not touch GoogleCloud.
        @test Firebase.CREDENTIALS === nothing
        use_emulator(firestore=true, project_id="demo-firebase", detect_env=false)
        @test auth_header() == ("Authorization" => "Bearer owner")
        Firebase.use_production()
    end

    @testset "projectid falls back to emulator project" begin
        @test Firebase.CREDENTIALS === nothing
        use_emulator(firestore=true, project_id="demo-firebase", detect_env=false)
        @test Firebase.projectid() == "demo-firebase"
        Firebase.use_production()

        # Without credentials and without emulator config, projectid errors.
        @test_throws Any Firebase.projectid()
    end

    @testset "firestore URL assembly (emulator)" begin
        use_emulator(firestore=true, project_id="demo-firebase", detect_env=false)
        project = Firebase.projectid()
        url = "$(Firebase.firestore_url())/projects/$project/databases/(default)/documents/coll/doc"
        @test url ==
              "http://localhost:8080/v1/projects/demo-firebase/databases/(default)/documents/coll/doc"
        Firebase.use_production()
    end

    @testset "use_production clears state" begin
        use_emulator(firestore=true, database=true, detect_env=false)
        Firebase.use_production()
        @test Firebase.emulator_active(:firestore) == false
        @test Firebase.emulator_active(:database) == false
        @test Firebase.EMULATOR_PROJECT_ID === nothing
        @test Firebase.firestore_url() == "https://firestore.googleapis.com/v1"
    end
end
