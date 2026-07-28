# Firebase Authentication integration tests (issue #18), run against the Auth emulator.
#
# The emulator accepts any web API key, so no real key is needed. Each testset uses a
# fresh randomised email so reruns against a persistent emulator stay independent.

@testset "Firebase Auth" begin
    set_webapikey("fake-api-key")

    newemail() = "user_$(rand(UInt32))@example.com"

    @testset "sign up and sign in" begin
        email = newemail()
        signed_up = firebase_signup(email, "helloworld!!")
        @test signed_up["email"] == email
        @test haskey(signed_up, "idToken")
        @test haskey(signed_up, "refreshToken")

        signed_in = firebase_signin(email, "helloworld!!")
        @test signed_in["email"] == email
        @test signed_in["registered"] === true
        @test signed_in["localId"] == signed_up["localId"]

        # Wrong password is rejected.
        @test_throws HTTP.Exceptions.StatusError firebase_signin(email, "wrong-password")

        firebase_deleteuser(signed_in["idToken"])
    end

    @testset "anonymous sign in" begin
        anon = firebase_signinanon()
        @test haskey(anon, "idToken")
        @test haskey(anon, "localId")

        info = firebase_getuserinfo(anon["idToken"])
        @test info["users"][1]["localId"] == anon["localId"]

        firebase_deleteuser(anon["idToken"])
    end

    @testset "user info and profile" begin
        email = newemail()
        data = firebase_signup(email, "helloworld!!")

        info = firebase_getuserinfo(data["idToken"])
        @test info["users"][1]["email"] == email

        updated = firebase_updateprofile("ash", "https://i.imgur.com/zgDkgSR.jpeg",
                                         data["idToken"])
        @test updated["displayName"] == "ash"
        @test updated["photoUrl"] == "https://i.imgur.com/zgDkgSR.jpeg"

        info = firebase_getuserinfo(data["idToken"])
        @test info["users"][1]["displayName"] == "ash"

        firebase_deleteuser(data["idToken"])
    end

    @testset "change password and email" begin
        email = newemail()
        data = firebase_signup(email, "helloworld!!")

        changed = firebase_changepassword("hellopaaji!!", data["idToken"])
        @test haskey(changed, "idToken")
        @test firebase_signin(email, "hellopaaji!!")["registered"] === true

        # The password change invalidates the old one.
        @test_throws HTTP.Exceptions.StatusError firebase_signin(email, "helloworld!!")

        moved = newemail()
        changed = firebase_changeemail(moved, changed["idToken"])
        @test changed["email"] == moved
        @test firebase_signin(moved, "hellopaaji!!")["email"] == moved

        firebase_deleteuser(firebase_signin(moved, "hellopaaji!!")["idToken"])
    end

    @testset "fetch providers" begin
        email = newemail()
        data = firebase_signup(email, "helloworld!!")

        providers = firebase_fetchproviders(email)
        @test providers["registered"] === true
        @test "password" in providers["allProviders"]

        # An address nobody signed up with is not registered.
        unknown = firebase_fetchproviders(newemail())
        @test Base.get(unknown, "registered", false) === false

        firebase_deleteuser(data["idToken"])
    end

    @testset "email verification and password reset" begin
        email = newemail()
        data = firebase_signup(email, "helloworld!!")

        # The emulator does not send mail; it returns the address and stores the code.
        @test firebase_verifyemail(data["idToken"])["email"] == email
        @test firebase_passwordreset(email)["email"] == email

        firebase_deleteuser(data["idToken"])
    end

    @testset "delete account" begin
        email = newemail()
        data = firebase_signup(email, "helloworld!!")
        firebase_deleteuser(data["idToken"])

        # The account is gone, so signing in with it fails.
        @test_throws HTTP.Exceptions.StatusError firebase_signin(email, "helloworld!!")
    end
end
