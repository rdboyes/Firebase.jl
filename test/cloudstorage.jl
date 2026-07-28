# Pure unit tests for cloud storage helpers. No network, no credentials.
#
# The Firebase Storage *Management* API (addFirebase / get / list / removeFirebase)
# has no emulator, so it cannot be exercised end to end here — these tests pin down
# the resource names and URLs those calls are built from.

using Firebase
using Test

@testset "Cloud Storage" begin

    @testset "bucket resource names" begin
        @test Firebase._bucket_resource("demo-firebase", "demo-firebase.appspot.com") ==
              "projects/demo-firebase/buckets/demo-firebase.appspot.com"
        # The management API also accepts a project number.
        @test Firebase._bucket_resource("123456789", "my-bucket") ==
              "projects/123456789/buckets/my-bucket"
    end

    @testset "management URLs" begin
        base = "https://firebasestorage.googleapis.com/v1beta"
        @test Firebase._management_url("projects/p/buckets") == "$base/projects/p/buckets"

        res = Firebase._bucket_resource("p", "b")
        @test Firebase._management_url(res) == "$base/projects/p/buckets/b"
        @test Firebase._management_url("$res:addFirebase") ==
              "$base/projects/p/buckets/b:addFirebase"
        @test Firebase._management_url("$res:removeFirebase") ==
              "$base/projects/p/buckets/b:removeFirebase"
    end

    @testset "object path encoding" begin
        # "/" becomes %2F, and a leading slash is not part of the object name.
        @test Firebase._encode_object_path("/audio/data.mp3") == "audio%2Fdata.mp3"
        @test Firebase._encode_object_path("audio/data.mp3") == "audio%2Fdata.mp3"
        @test Firebase._encode_object_path("/data.mp3") == "data.mp3"
        @test Firebase._encode_object_path("a/b/c/d.txt") == "a%2Fb%2Fc%2Fd.txt"
    end

    @testset "content types" begin
        @test Firebase.content_type("data.mp3") == "audio/mpeg"
        @test Firebase.content_type("a/b/photo.PNG") == "image/png"
        @test Firebase.content_type("notes.txt") == "text/plain"
        @test Firebase.content_type("payload.json") == "application/json"
        # Unknown and missing extensions fall back rather than erroring.
        @test Firebase.content_type("archive.sbox") == "application/octet-stream"
        @test Firebase.content_type("README") == "application/octet-stream"
    end
end
