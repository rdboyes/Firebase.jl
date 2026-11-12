# Pure unit tests for OAuth token caching. No network: the cached session is primed
# with a fake, unexpired token so `get_token` must return it without contacting Google.

using Firebase
using Test

const _Dates = Firebase.Dates
const _GC = Firebase.GoogleCloud

# Minimal stand-in for service-account credentials (JSONCredentials needs a real
# RSA key). Only `project_id` is read outside GoogleCloud's token request.
struct FakeCredentials <: _GC.credentials.Credentials
    project_id::String
end

@testset "Token caching" begin
    Firebase._set_credentials!(FakeCredentials("demo-token"))
    @test Firebase.SESSION === nothing
    @test projectid() == "demo-token"

    # Prime the session the same way get_token would build it, then fake a token.
    session = _GC.GoogleSession(Firebase.CREDENTIALS, Firebase.OAUTH_SCOPES)
    session.authorization = Dict{Symbol,Any}(:access_token => "cached-token",
                                             :token_type => "Bearer")
    session.expiry = _Dates.now(_Dates.UTC) + _Dates.Hour(1)
    Firebase.SESSION = session

    t1 = get_token()
    t2 = get_token()
    @test t1[:access_token] == "cached-token"
    @test t1 === t2
    @test Firebase.SESSION === session

    # get_token lazily builds a session when none is cached.
    Firebase.SESSION = nothing
    @test_throws Exception get_token()   # FakeCredentials can't mint a real token
    @test Firebase.SESSION isa _GC.GoogleSession

    # Loading new credentials (what every init method does) drops the old token.
    Firebase.SESSION = session
    Firebase._set_credentials!(FakeCredentials("other"))
    @test Firebase.SESSION === nothing

    Firebase._set_credentials!(nothing)
    @test_throws Any get_token()
end

@testset "No hard-coded defaults" begin
    # These used to default to a real API key / a real person's email.
    @test_throws MethodError set_webapikey()
    @test_throws MethodError firebase_passwordreset()
    @test_throws MethodError firebase_fetchproviders()
    @test_throws MethodError firebase_signinoauth()
    @test_throws MethodError firestore_batchget()
    @test_throws MethodError firestore_batchwrite()
end

@testset "initparsedjson keeps the key in memory" begin
    mktempdir() do dir
        cd(dir) do
            # The key is invalid so JSONCredentials fails, but no file may appear.
            @test_throws Exception initparsedjson("""{"type": "service_account"}""")
            @test isempty(readdir(dir))
        end
    end
end
