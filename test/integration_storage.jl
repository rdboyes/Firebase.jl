# Cloud Storage integration tests (issue #17), run against the Storage emulator.
#
# cloudstore_sendfile / cloudstore_get resolve local paths relative to the working
# directory, so these tests run inside a temporary directory.

@testset "Cloud Storage roundtrip" begin
    mktempdir() do dir
        cd(dir) do
            remote = "/emulatortest_$(rand(UInt32))/hello.txt"
            local_path = lstrip(remote, '/')
            contents = "hello storage"

            mkpath(dirname(local_path))
            write(local_path, contents)

            @testset "upload" begin
                res = cloudstore_sendfile(remote)
                @test res["name"] == lstrip(remote, '/')
                @test res["bucket"] == "demo-firebase.appspot.com"
                @test parse(Int, res["size"]) == length(contents)
                # The content type sent by cloudstore_sendfile is not asserted here:
                # the storage emulator reports every object as application/octet-stream
                # no matter what the upload declares. `content_type` is covered by the
                # unit tests in test/cloudstorage.jl instead.
            end

            @testset "download" begin
                # Remove the local copy so the download has to produce it.
                rm(dirname(local_path), recursive=true)
                @test !isfile(local_path)

                out = cloudstore_get(remote)
                @test out == local_path
                @test read(local_path, String) == contents
            end

            @testset "download to an explicit destination" begin
                out = cloudstore_get(remote; dest="elsewhere.txt")
                @test out == "elsewhere.txt"
                @test read("elsewhere.txt", String) == contents
            end

            @testset "binary content survives the roundtrip" begin
                binremote = "/emulatortest_$(rand(UInt32))/blob.bin"
                binlocal = lstrip(binremote, '/')
                bytes = UInt8[0x00, 0xff, 0x10, 0x80, 0x7f, 0x00]

                mkpath(dirname(binlocal))
                write(binlocal, bytes)

                res = cloudstore_sendfile(binremote)
                @test parse(Int, res["size"]) == length(bytes)

                rm(dirname(binlocal), recursive=true)
                cloudstore_get(binremote)
                @test read(binlocal) == bytes
            end
        end
    end
end
