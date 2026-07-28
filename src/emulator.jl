# Emulator configuration
#
# Lets the package talk to the local Firebase Emulator Suite as well as to live
# Firebase. Configuration follows the standard Firebase emulator environment-variable
# convention and is also settable explicitly via `use_emulator`.
#
# | Service     | Env var                           | Default host   | Base URL in emulator mode                         |
# |-------------|-----------------------------------|----------------|---------------------------------------------------|
# | Firestore   | FIRESTORE_EMULATOR_HOST           | localhost:8080 | http://<host>/v1                                  |
# | Realtime DB | FIREBASE_DATABASE_EMULATOR_HOST   | localhost:9000 | http://<host> + ?ns=<project>-default-rtdb        |
# | Auth        | FIREBASE_AUTH_EMULATOR_HOST       | localhost:9099 | http://<host>/identitytoolkit.googleapis.com/v1   |
# | Storage     | FIREBASE_STORAGE_EMULATOR_HOST    | localhost:9199 | http://<host>/v0/b/<bucket>/o/                    |

using Sockets

# host:port strings for each service, or `nothing` when that service is live.
const EMULATOR = Dict{Symbol,Union{Nothing,String}}(
    :firestore => nothing,
    :database  => nothing,
    :auth      => nothing,
    :storage   => nothing,
)

# Project id used when running against the emulator without real credentials.
EMULATOR_PROJECT_ID = nothing

const _DEFAULT_PORTS = Dict{Symbol,Int}(
    :firestore => 8080,
    :database  => 9000,
    :auth      => 9099,
    :storage   => 9199,
)

const _ENV_VARS = Dict{Symbol,String}(
    :firestore => "FIRESTORE_EMULATOR_HOST",
    :database  => "FIREBASE_DATABASE_EMULATOR_HOST",
    :auth      => "FIREBASE_AUTH_EMULATOR_HOST",
    :storage   => "FIREBASE_STORAGE_EMULATOR_HOST",
)

"""
    emulator_active(service::Symbol) -> Bool

Return `true` when `service` (`:firestore`, `:database`, `:auth`, or `:storage`)
is currently pointed at an emulator.
"""
emulator_active(service::Symbol) = !isnothing(EMULATOR[service])

# Resolve one service's host: an explicit "host:port" string wins; `true` (or a
# bare host with no colon) fills in the standard port on `host`; `nothing` leaves
# it to env-var detection.
function _resolve_host(setting, host, service)
    setting === nothing && return nothing
    setting === false && return nothing
    if setting === true
        return "$host:$(_DEFAULT_PORTS[service])"
    end
    s = string(setting)
    return occursin(':', s) ? s : "$s:$(_DEFAULT_PORTS[service])"
end

"""
    use_emulator(; host="localhost", firestore=nothing, database=nothing,
                   auth=nothing, storage=nothing, project_id="demo-firebase",
                   detect_env=true)

Point the package at the local Firebase Emulator Suite.

For each service you may pass an explicit `"host:port"` string, `true` to use the
standard port on `host`, or leave it `nothing`. When `detect_env` is `true`, the
standard `*_EMULATOR_HOST` environment variables are read for any service not given
explicitly. If nothing is specified for a service and no env var is set, that service
stays live.

Calling `use_emulator()` with no arguments enables every service whose env var is set,
falling back to the default ports on `host` only for services you request.

# Example
```julia
use_emulator()                                   # from FIRESTORE_EMULATOR_HOST etc.
use_emulator(firestore=true, database=true)      # localhost:8080 / localhost:9000
use_emulator(firestore="127.0.0.1:8080", project_id="my-demo")
```
"""
function use_emulator(; host="localhost", firestore=nothing, database=nothing,
                        auth=nothing, storage=nothing, project_id="demo-firebase",
                        detect_env=true)
    global EMULATOR_PROJECT_ID
    settings = Dict(:firestore => firestore, :database => database,
                    :auth => auth, :storage => storage)
    for service in (:firestore, :database, :auth, :storage)
        resolved = _resolve_host(settings[service], host, service)
        if resolved === nothing && detect_env
            # Qualify as Base.get: this module exports its own `get` (Firestore).
            envval = Base.get(ENV, _ENV_VARS[service], "")
            resolved = isempty(envval) ? nothing :
                       (occursin(':', envval) ? envval : "$envval:$(_DEFAULT_PORTS[service])")
        end
        EMULATOR[service] = resolved
    end
    EMULATOR_PROJECT_ID = project_id

    # Realtime DB and Storage build their URLs from mutable globals; point them at
    # the emulator so the existing request builders work unchanged.
    if emulator_active(:database)
        global BASE_URL = "http://$(EMULATOR[:database])"
    end
    if emulator_active(:storage)
        global STORE_URL = "http://$(EMULATOR[:storage])/v0/b/$(project_id).appspot.com/o/"
    end

    println("Emulator config: ", EMULATOR, " project_id=", EMULATOR_PROJECT_ID)
    EMULATOR
end

"""
    use_production()

Clear all emulator configuration and route every service back to live Firebase.
"""
function use_production()
    global EMULATOR_PROJECT_ID = nothing
    for service in (:firestore, :database, :auth, :storage)
        EMULATOR[service] = nothing
    end
    EMULATOR
end

"""
    firestore_url() -> String

Base URL for Firestore REST calls: the emulator host when active, otherwise live.
"""
firestore_url() = emulator_active(:firestore) ?
    "http://$(EMULATOR[:firestore])/v1" : "https://firestore.googleapis.com/v1"

"""
    auth_url() -> String

Base URL for Firebase Auth (Identity Toolkit) REST calls.
"""
auth_url() = emulator_active(:auth) ?
    "http://$(EMULATOR[:auth])/identitytoolkit.googleapis.com/v1" :
    "https://identitytoolkit.googleapis.com/v1"

"""
    database_ns() -> String

Realtime Database namespace used for the `?ns=` query parameter in emulator mode.
"""
function database_ns()
    project = isnothing(EMULATOR_PROJECT_ID) ? "demo-firebase" : EMULATOR_PROJECT_ID
    "$(project)-default-rtdb"
end

"""
    emulator_running(hostport::AbstractString) -> Bool

Best-effort check that something is listening on `hostport` (`"host:port"`), used to
gate integration tests. Returns `false` if the connection cannot be established.
"""
function emulator_running(hostport::AbstractString)
    isempty(hostport) && return false
    parts = split(hostport, ':')
    length(parts) == 2 || return false
    host = parts[1]
    port = tryparse(Int, parts[2])
    port === nothing && return false
    try
        sock = Sockets.connect(host, port)
        close(sock)
        return true
    catch
        return false
    end
end
