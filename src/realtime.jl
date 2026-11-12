# Realtime Database

using HTTP, JSON

BASE_URL = nothing

"""
In the examples on this page,
you would replace [PROJECT_ID] with the identifier of your Firebase project.
"""

"""
realdb_init(base_url)

Initialize the realtimedb with baseurl to make things easier

# Example

```julia
realdb_init("https://[PROJECT_ID].asia-southeast1.firebasedatabase.app")
```
"""
function realdb_init(base_url; query = Dict())
    global BASE_URL = base_url
    @debug "Realtime Database URL set" BASE_URL
    BASE_URL
end

# Headers for a Realtime Database request.
#
# An explicit `authheader` (a Pair, a Dict or a vector of Pairs) is always used as
# given. Otherwise the request is authenticated automatically: with the emulator's
# owner token when the database emulator is active, or with the service-account
# OAuth token when credentials have been loaded via `init`. With neither, the request
# is sent unauthenticated and only succeeds against open security rules.
#
# To act as an end user instead, pass their Firebase ID token as
# `query = Dict("auth" => id_token)`.
function _realdb_headers(authheader)
    headers = Pair{String,String}[]
    if authheader isa Pair
        push!(headers, string(first(authheader)) => string(last(authheader)))
    elseif authheader isa Union{AbstractDict,AbstractVector}
        append!(headers, [string(k) => string(v) for (k, v) in authheader])
    elseif !(authheader === nothing || authheader == "")
        throw(ArgumentError("authheader must be a Pair, a Dict or a vector of Pairs"))
    end
    if !any(h -> lowercase(first(h)) == "authorization", headers)
        if emulator_active(:database) || !isnothing(CREDENTIALS)
            push!(headers, auth_header(:database))
        end
    end
    headers
end

function _realdb_request(method, url, authheader, body = nothing; query = Dict())
    isnothing(BASE_URL) && throw("Run realdb_init(url) before using the Realtime Database")
    final_url = "$BASE_URL$url.json"
    q = Dict{String,Any}(string(k) => v for (k, v) in query)
    emulator_active(:database) && (q["ns"] = database_ns())
    headers = _realdb_headers(authheader)
    @debug "Realtime Database request" method final_url
    res = if body === nothing
        HTTP.request(method, final_url, headers; query = q)
    else
        HTTP.request(method, final_url, headers, JSON.json(body); query = q)
    end
    JSON.parse(String(res.body))
end

"""
realdb_get(url, authheader = ""; query = Dict())

GET request to an endpoint. `query` is passed through as URL parameters, e.g.
`Dict("orderBy" => "\\"\$key\\"", "limitToFirst" => 10)` or `Dict("shallow" => true)`.

Requests are authenticated automatically when credentials are loaded (see `init`)
or the emulator is active. Pass `authheader` to override, or
`query = Dict("auth" => id_token)` to act as a signed-in user.

# Example
```julia
realdb_init("https://[PROJECT_ID].asia-southeast1.firebasedatabase.app")
realdb_get("/users/jack/name")
```

"""
realdb_get(url, authheader = ""; query = Dict()) =
    _realdb_request("GET", url, authheader; query = query)


"""
realdb_post(url, authheader = "", body = Dict("name" => "real_db_test"); query = Dict())

POST request to an endpoint.

# Example
```julia
realdb_init("https://[PROJECT_ID].asia-southeast1.firebasedatabase.app")
body = Dict("user_id" => "jack", "text" => "Ahoy!")
realdb_post("/message_list", "", body)
```

## Notes:

According to the REST API documentation for Realtime Database,
a POST is the equivalent of a "push" operation when using the client SDKs.
This push operation always involves adding data under a random ID.
There is no avoiding that for a push.

If you know the name of the node where you want to add data,
you should use a PUT instead. This is the equivalent of using "set"
operation with the client SDKs.

"""
realdb_post(url, authheader = "", body = Dict("name" => "real_db_test"); query = Dict()) =
    _realdb_request("POST", url, authheader, body; query = query)


"""
realdb_patch(url, authheader = "", body = Dict("name" => "real_db_test"); query = Dict())

`PATCH` request to an endpoint.

# Example
```julia
realdb_init("https://[PROJECT_ID].asia-southeast1.firebasedatabase.app")
body = Dict("last" => "Jones")
realdb_patch("/users/jack/name/", "", body)
```
"""
realdb_patch(url, authheader = "", body = Dict("name" => "real_db_test"); query = Dict()) =
    _realdb_request("PATCH", url, authheader, body; query = query)

"""
realdb_delete(url, authheader = ""; query = Dict())

`DELETE` request to an endpoint

# Example
```julia
realdb_init("https://[PROJECT_ID].asia-southeast1.firebasedatabase.app")
realdb_delete("/users/jack/name/last")
```
"""
realdb_delete(url, authheader = ""; query = Dict()) =
    _realdb_request("DELETE", url, authheader; query = query)

"""
realdb_put(url, authheader = "", body = Dict("name" => "real_db_test"); query = Dict())

`PUT` request to a endpoint.

# Example

```julia
realdb_init("https://[PROJECT_ID].asia-southeast1.firebasedatabase.app")
body = Dict("first" => "Ash", "last" => "Sparrow")
realdb_put("/users/jack/name", "", body)
```
"""
realdb_put(url, authheader = "", body = Dict("name" => "real_db_test"); query = Dict()) =
    _realdb_request("PUT", url, authheader, body; query = query)

"""
realdb_download(url, authheader = "", filename = "test"; query = Dict())

GET the data at `url`, asking the server to serve it as a download named
`filename.txt` (the REST API's `download` parameter). Returns the parsed data.
"""
realdb_download(url, authheader = "", filename = "test"; query = Dict()) =
    _realdb_request("GET", url, authheader;
                    query = merge(Dict{String,Any}(string(k) => v for (k, v) in query),
                                  Dict{String,Any}("download" => "$filename.txt")))
