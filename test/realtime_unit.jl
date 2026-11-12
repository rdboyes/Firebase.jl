# Pure unit tests for Realtime Database request headers. No network.

using Firebase
using Test

const _RTDB_Dates = Firebase.Dates
const _RTDB_GC = Firebase.GoogleCloud

struct FakeRTDBCredentials <: _RTDB_GC.credentials.Credentials
    project_id::String
end

@testset "Realtime DB headers" begin
    Firebase.use_production()
    Firebase._set_credentials!(nothing)

    # No credentials, no emulator: unauthenticated (open rules only).
    @test isempty(Firebase._realdb_headers(""))
    @test isempty(Firebase._realdb_headers(nothing))

    # Explicit headers are used as given, in any of the accepted shapes.
    explicit = "Authorization" => "Bearer mine"
    for h in (explicit, Dict(explicit), [explicit])
        @test Firebase._realdb_headers(h) == [explicit]
    end
    @test_throws ArgumentError Firebase._realdb_headers(42)

    # Emulator: owner token added automatically, but an explicit one still wins.
    use_emulator(database=true, project_id="demo-firebase", detect_env=false)
    @test Firebase._realdb_headers("") == ["Authorization" => "Bearer owner"]
    @test Firebase._realdb_headers(explicit) == [explicit]
    Firebase.use_production()

    # Live with credentials: the cached service-account token is attached.
    Firebase._set_credentials!(FakeRTDBCredentials("demo-rtdb"))
    session = _RTDB_GC.GoogleSession(Firebase.CREDENTIALS, Firebase.OAUTH_SCOPES)
    session.authorization = Dict{Symbol,Any}(:access_token => "svc-token",
                                             :token_type => "Bearer")
    session.expiry = _RTDB_Dates.now(_RTDB_Dates.UTC) + _RTDB_Dates.Hour(1)
    Firebase.SESSION = session
    @test Firebase._realdb_headers("") == ["Authorization" => "Bearer svc-token"]
    @test "firebase.database" in basename.(session.scopes)
    @test "userinfo.email" in basename.(session.scopes)

    Firebase._set_credentials!(nothing)
end
