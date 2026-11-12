using HTTP,JSON




WEB_API_KEY = nothing

# Every Identity Toolkit call is a JSON POST to /accounts:<endpoint>?key=<WEB_API_KEY>.
# Building the body with JSON.json rather than string interpolation keeps values
# containing quotes or backslashes from producing malformed JSON, and sets the
# Content-Type header the API expects.
function _auth_post(endpoint, payload)
    isnothing(WEB_API_KEY) && throw("Run set_webapikey(key) before calling Firebase Auth")
    header = Dict("Content-Type" => "application/json")
    url = "$(auth_url())/accounts:$endpoint?key=$WEB_API_KEY"
    http_response = HTTP.post(url, header, JSON.json(payload))
    response_string = String(http_response.body)
    JSON.parse(response_string)
end

"""
set_webapikey(key)

Sets the project's Web API key, used by every Firebase Auth call. Find it under
Project settings → General in the Firebase console.

# Example
```julia
set_webapikey("asjdlajsj1j32lj312")
```
"""
function set_webapikey(key::AbstractString)
    global WEB_API_KEY = key
    println("WEB_API_KEY set")
end

"""
firebase_signup(email::String="", password::String="", returnSecureToken::Bool= true)

Sign up with email / password
You can create a new email and password user by issuing an HTTP POST request to the Auth 
signupNewUser endpoint.

# Example

```julia
set_webapikey("WEB_API_KEY")
firebase_signup("user@example.com","hello!!")
#=
Dict{String, Any} with 6 entries:
  "refreshToken" => "AGEhc0AjgXJevwy_rkJ3r4VUHc4EEORngVF-rwEtOuO007AymRqbAzVnn1iAMCZNHqzwnCI1X8fkJ0OPE2fTuGN7ameU6P7SmibwIFs8sOZxUI8C_uklOkk1IG5DFdWXAC45mK_0Hy4tuJXJUvI8Kuy6LS-GERZ5Bc…
  "kind"         => "identitytoolkit#SignupNewUserResponse"
  "localId"      => "GRCBj28Pkhat0mYsJS0BVrlVmJd2"
  "expiresIn"    => "3600"
  "idToken"      => "eyJhbGciOiJSUzI1NiIsImtpZCI6ImRjNGQwMGJjM2NiZWE4YjU0NTMzMWQxZjFjOTZmZDRlNjdjNTFlODkiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vZmlyLWp…
  "email"        => "user@example.com"
=#
```
"""
function firebase_signup(email::String="", password::String="", returnSecureToken::Bool=true)
    _auth_post("signUp", Dict("email" => email, "password" => password,
                              "returnSecureToken" => returnSecureToken))
end

"""
firebase_signin(email::String="data", password::String="data", returnSecureToken::Bool= true)

Sign in with email / password
You can sign in a user with an email and password by issuing an HTTP POST request
to the Auth verifyPassword endpoint.

# Example

```julia
firebase_signin("user@example.com" , "hello1231!!")
#=
Dict{String, Any} with 8 entries:
  "refreshToken" => "AGEhc0C1F9smilhBPdT5TYClumCwdzGI9q43s5r-MsqW-bJTeiIw1doG7zRF_VMX2a0WELR3zRB…
  "kind"         => "identitytoolkit#VerifyPasswordResponse"
  "localId"      => "zgrI4g3ualVJW7IEiRlPFg5jItA2"
  "displayName"  => ""
  "idToken"      => "eyJhbGciOiJSUzI1NiIsImtpZCI6ImRjNGQwMGJjM2NiZWE4YjU0NTMzMWQxZjFjOTZmZDRlNjd…
  "registered"   => true
  "expiresIn"    => "3600"
  "email"        => "user@example.com"
=#
```
"""
function firebase_signin(email::String="", password::String="", returnSecureToken::Bool=true)
  _auth_post("signInWithPassword", Dict("email" => email, "password" => password,
                                        "returnSecureToken" => returnSecureToken))
end


"""
firebase_signinanon(returnSecureToken::Bool= true)

Sign in anonymously
You can sign in a user anonymously by issuing an
HTTP POST request to the Auth signupNewUser endpoint.

# Exampleemail::String="", password::String="", 

```julia
julia> firebase_signinanon()
#=
Dict{String, Any} with 5 entries:
  "refreshToken" => "AGEhc0DiE1zelLdCW2KG9wMRwZKcZI6EuSef4hsIc6uOZp0I3SYUTf0Hib_XgvtgY1yeqgFNqJ0…
  "kind"         => "identitytoolkit#SignupNewUserResponse"
  "localId"      => "3T8r7DD99zO9qKL1k56boC2iiXF2"
  "expiresIn"    => "3600"
  "idToken"      => "eyJhbGciOiJSUzI1NiIsImtpZCI6ImRjNGQwMGJjM2NiZWE4YjU0NTMzMWQxZjFjOTZmZDRlNjd…
=#
```

"""
function firebase_signinanon(returnSecureToken::Bool=true)
  _auth_post("signUp", Dict("returnSecureToken" => returnSecureToken))
end

"""
firebase_signinoauth(id_token, provider="google.com")

Sign in with OAuth credential
You can sign in a user with an OAuth credential by issuing
 an HTTP POST request to the Auth verifyAssertion endpoint.

This doesn't work today

# Example

```julia
firebase_signinoauth("[GOOGLE_ID_TOKEN]")
```

"""
function firebase_signinoauth(id_token::AbstractString, provider="google.com")
  _auth_post("signInWithIdp",
             Dict("postBody" => "id_token=$id_token&providerId=$provider",
                  "requestUri" => "http://localhost",
                  "returnIdpCredential" => true,
                  "returnSecureToken" => true))
end

"""
firebase_fetchproviders(email; continueuri="http://localhost")

Fetch providers for email
You can look all providers associated with a specified email by 
issuing an HTTP POST request to the Auth createAuthUri endpoint.

# Example

```julia
julia> firebase_fetchproviders("user@example.com")
#= 
Dict{String, Any} with 5 entries:
  "allProviders"  => Any["password"]
  "kind"          => "identitytoolkit#CreateAuthUriResponse"
  "sessionId"     => "k8iBdCSLEeAbhhgKz6E4PC-ltCs"
  "signinMethods" => Any["password"]
  "registered"    => true
=#
```
"""
function firebase_fetchproviders(email::AbstractString; continueuri="http://localhost")
  _auth_post("createAuthUri", Dict("identifier" => email,
                                   "continueUri" => continueuri))
end

"""
firebase_passwordreset(email)

Send password reset email
You can send a password reset email by 
issuing an HTTP POST request to the Auth getOobConfirmationCode endpoint.

# Example

```julia
firebase_passwordreset("user@example.com")
# email will recieve the reset password email
```
"""
function firebase_passwordreset(email::AbstractString)
  _auth_post("sendOobCode", Dict("requestType" => "PASSWORD_RESET", "email" => email))
end

"""
verify_passwordresetcode()

Verify password reset code
You can verify a password reset code by issuing an 
HTTP POST request to the Auth resetPassword endpoint.

# Example

```julia

```
"""
function verify_passwordresetcode(oobcode="")
  _auth_post("resetPassword", Dict("oobCode" => oobcode))
end


"""
confirm_passwordreset(oobcode="", newpassword="")

Confirm a password reset. Applies `newpassword` to the account identified by the
out-of-band code from the reset email.
"""
function confirm_passwordreset(oobcode="", newpassword="")
  _auth_post("resetPassword", Dict("oobCode" => oobcode, "newPassword" => newpassword))
end

FIREBASE_ID_TOKEN = nothing

"""
firebase_changeemail(newemail="",firebase_id_token=  FIREBASE_ID_TOKEN)

Change email
You can change a user's email by issuing an 
HTTP POST request to the Auth setAccountInfo endpoint.

# Example
```julia
data = firebase_signin("user@example.com,"helloworld!!")
firebase_changeemail("user@example.com",data["idToken"])
data = firebase_signin("user@example.com,"helloworld!!")
firebase_changeemail("user@example.com",data["idToken"])
````

"""
function firebase_changeemail(newemail="", firebase_id_token=FIREBASE_ID_TOKEN)
  _auth_post("update", Dict("idToken" => firebase_id_token, "email" => newemail,
                            "returnSecureToken" => true))
end

"""
firebase_changepassword(newpassword="", firebase_id_token=FIREBASE_ID_TOKEN)

Change password
You can change a user's password by issuing an 
HTTP POST request to the Auth setAccountInfo endpoint.

# Example
```julia
data = firebase_signin("user@example.com","helloworld!!")
firebase_changepassword("hellopaaji!!",data["idToken"])
data = firebase_signin("user@example.com","hellopaaji!!")
firebase_changepassword("helloworld!!",data["idToken"])
````

"""
function firebase_changepassword(newpassword="", firebase_id_token=FIREBASE_ID_TOKEN)
  _auth_post("update", Dict("idToken" => firebase_id_token, "password" => newpassword,
                            "returnSecureToken" => true))
end

"""

Update profile
You can update a user's profile (display name / photo URL) by issuing an 
HTTP POST request to the Auth setAccountInfo endpoint.

# TODO: delete attribute
# Example
```julia
data = firebase_signin("user@example.com","helloworld!!")
firebase_updateprofile("ash","https://i.imgur.com/zgDkgSR.jpeg",data["idToken"])
#=       
Dict{String, Any} with 8 entries:
  "kind"             => "identitytoolkit#SetAccountInfoResponse"
  "photoUrl"         => "https://i.imgur.com/zgDkgSR.jpeg"
  "localId"          => "GovyExPqFWS70uynnuBzVnYgLAi2"
  "displayName"      => "ash"
  "passwordHash"     => "UkVEQUNURUQ="
  "emailVerified"    => false
  "providerUserInfo" => Any[Dict{String, Any}("rawId"=>"user@example.com", "photoUrl"=>"https:…
  "email"            => "user@example.com"
=#
  ```
"""
function firebase_updateprofile(displayname="",photourl="",firebase_id_token=FIREBASE_ID_TOKEN)
  _auth_post("update", Dict("idToken" => firebase_id_token, "displayName" => displayname,
                            "photoUrl" => photourl, "returnSecureToken" => true))
end

"""
firebase_getuserinfo(firebase_id_token=FIREBASE_ID_TOKEN)

Get user data
You can get a user's data by issuing an HTTP POST request to the Auth getAccountInfo endpoint.
# Example
```julia
data = firebase_signin("user@example.com","helloworld!!")
firebase_getuserinfo(data["idToken"])
```
"""
function firebase_getuserinfo(firebase_id_token=FIREBASE_ID_TOKEN)
  _auth_post("lookup", Dict("idToken" => firebase_id_token))
end


"""

Link with email/password
You can link an email/password to a current user by issuing an 
HTTP POST request to the Auth setAccountInfo endpoint.

# Example
```julia
data = firebase_signin("user@example.com","helloworld!!")
firebase_linkuserinfo("ash@gmail.com", "hello!!123as",data["idToken"])
data = firebase_signin("ash@gmail.com", "hello!!123as")
firebase_linkuserinfo("user@example.com","helloworld!!",data["idToken"])
```
"""
function firebase_linkuserinfo(email::String="", password::String="",firebase_id_token=FIREBASE_ID_TOKEN)
  _auth_post("update", Dict("idToken" => firebase_id_token, "email" => email,
                            "password" => password, "returnSecureToken" => true))
end


# implmene the linking a account with OAuth here
"""
Link with OAuth credential
You can link an OAuth credential to a user by 
issuing an HTTP POST request to the Auth verifyAssertion endpoint.
"""
function firebase_linkoauth()

end

"""

Unlink provider
You can unlink a provider from a current user by issuing an
HTTP POST request to the Auth setAccountInfo endpoint.

# Example
```julia
set_webapikey("[WEB_API_KEY]")

data = firebase_signup("user@example.com","hello!!123")
#=
Dict{String, Any} with 6 entries:
  "refreshToken" => "AGEhc0A4Y-wFC0S2Cub-7TY2XNfZMYQf-YKzTdQWl9_SjrRpUW4d3QymQy5P1EN4Me8-SE695sPE_MBXoMoqTzKLy76nBvDGmybGmP4wnWLyrJql-HfoVPRtG1emeJ3E61DnDbUIZOvV-Y3GuzpJ57XZojHBM1aoMp…
  "kind"         => "identitytoolkit#SignupNewUserResponse"
  "localId"      => "neXn8Mg562VFgENRtA2SEC0NEBk1"
  "expiresIn"    => "3600"
  "idToken"      => "eyJhbGciOiJSUzI1NiIsImtpZCI6ImRjNGQwMGJjM2NiZWE4YjU0NTMzMWQxZjFjOTZmZDRlNjdjNTFlODkiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vZmlyLWp…
  "email"        => "user@example.com"
=#
firebase_unlinkprovide(data["idToken"], "google.com")
#=
Dict{String, Any} with 6 entries:
  "kind"             => "identitytoolkit#SetAccountInfoResponse"
  "localId"          => "neXn8Mg562VFgENRtA2SEC0NEBk1"
  "passwordHash"     => "UkVEQUNURUQ="
  "emailVerified"    => false
  "providerUserInfo" => Any[Dict{String, Any}("rawId"=>"user@example.com", "providerId"=>"password", "federatedId"=>"user@example.com", "email"=>"user@example.com")]
  "email"            => "user@example.com"
=#
```
"""
function firebase_unlinkprovide(firebase_id_token=FIREBASE_ID_TOKEN, providerdelete="google.com")
  # deleteProvider is a list of provider ids; the id must not be wrapped in brackets.
  providers = providerdelete isa AbstractString ? [providerdelete] : providerdelete
  _auth_post("update", Dict("idToken" => firebase_id_token,
                            "deleteProvider" => providers))
end

"""
firebase_verifyemail(firebase_id_token=FIREBASE_ID_TOKEN)

Send email verification
You can send an email verification for the current user by issuing an HTTP POST request to the Auth getOobConfirmationCode endpoint.

# Example
```julia
data = firebase_signin("user@example.com","helloworld!!")
firebase_verifyemail((data["idToken"])
```
"""
function firebase_verifyemail(firebase_id_token=FIREBASE_ID_TOKEN)
  _auth_post("sendOobCode", Dict("requestType" => "VERIFY_EMAIL",
                                 "idToken" => firebase_id_token))
end

"""
firebase_confirmemailverify(verification_code="")

Confirm email verification using the out-of-band code from the verification email.
"""
function firebase_confirmemailverify(verification_code="")
  _auth_post("update", Dict("oobCode" => verification_code))
end

"""
firebase_deleteuser(firebase_id_token=FIREBASE_ID_TOKEN)

Delete account
You can delete a current user by issuing an HTTP POST
request to the Auth deleteAccount endpoint.
# Example

```julia
data = firebase_signup("user@example.com","hello!!123")
firebase_deleteuser(data["idToken"])
```
"""
function firebase_deleteuser(firebase_id_token=FIREBASE_ID_TOKEN)
  _auth_post("delete", Dict("idToken" => firebase_id_token))
end

