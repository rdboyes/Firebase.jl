using GoogleCloud
using Glob
using REPL
using REPL.TerminalMenus

# Loaded service-account credentials, or `nothing` when running against the
# emulator (which needs no real OAuth token). The Firestore base URL is resolved
# per-call by `firestore_url()` (see emulator.jl) so it can switch between live and
# emulator hosts at runtime.
CREDENTIALS = nothing

# OAuth scopes requested for the service-account token. One token covers every
# service this package talks to (Firestore, Cloud Storage, the Storage management
# API, Realtime Database), so a single cached session can be shared by all of them.
# The Realtime Database specifically requires userinfo.email + firebase.database.
const OAUTH_SCOPES = ["cloud-platform", "datastore", "devstorage.full_control",
                      "firebase", "firebase.database", "userinfo.email"]

# Cached GoogleSession for `CREDENTIALS`. GoogleCloud.authorize caches the access
# token on the session object until shortly before it expires, so the session must
# be reused across requests; creating a new one per call forces a JWT signing and an
# OAuth round-trip on every request. Guarded by SESSION_LOCK so concurrent tasks do
# not race to refresh the token.
SESSION = nothing
const SESSION_LOCK = ReentrantLock()

# Install new credentials and drop any session/token tied to the old ones.
function _set_credentials!(creds)
    global CREDENTIALS, SESSION
    lock(SESSION_LOCK) do
        CREDENTIALS = creds
        SESSION = nothing
    end
    creds
end

"""
    initparsedjson(jsonstring)

Initialize from a service-account key given as a JSON string, e.g. one read from an
environment variable or a secret manager. The key is parsed in memory and never
written to disk.

## Example

```julia
julia> initparsedjson(ENV["FIREBASE_ADMIN_SDK_JSON"])
```
"""
initparsedjson(jsonstring::AbstractString) = init(JSON.parse(jsonstring))

"""
    init( julianparseddict::AbstractDict)

Initialize if the sdk key is in Julia dict format.

## Example

```md
julia> r = HTTP.get(BASE_URL, header); # returns a response with header and body
HTTP.Messages.Response

julia> response = JSON.parse(String(r.body))
Dict{String, Any} with 10 entries:
  "client_email"                => "****"
  "client_id"                   => "****"
  "auth_uri"                    => "https://accounts.google.com/o/oauth2/auth"
  "auth_provider_x509_cert_url" => "https://www.googleapis.com/oauth2/v1/certs"
  "token_uri"                   => "https://oauth2.googleapis.com/token"
  "client_x509_cert_url"        => "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-jk50g%40volka-bot.iam.gserviceaccount.com"
  "project_id"                  => "****"
  "type"                        => "service_account"
  "private_key"                 => "****"
  "private_key_id"              => "****"

julia> init(response)
````
"""
function init(julianparseddict::AbstractDict)
    # credentials need to be in a Dict{Symbol, <:AbstractString} for GoogleCloud.jl
    _set_credentials!(JSONCredentials(
        Dict(Symbol(k) => string(v) for (k, v) in julianparseddict)
    ))
end

function init(filepath)
    _set_credentials!(JSONCredentials(filepath))
    @info "Loaded Firebase service-account credentials" project_id = CREDENTIALS.project_id
end

function init()
    try
        filenames = glob("*.json", "firebase")
        menu = RadioMenu(filenames, pagesize=4)
        file = request("Choose your admin sdk key for use:", menu)
        
        if file != -1
            println("Project Admin SDK key is ", filenames[file], " now!!")
            _set_credentials!(JSONCredentials(filenames[file]))
        else
            println("Menu canceled.")
        end
    catch e
        println("Either the folder firebase doesn't exist or it's empty")
    end
end

function projectid()
    global CREDENTIALS
    # In emulator mode we may have no real credentials; fall back to the configured
    # emulator project id.
    if isnothing(CREDENTIALS)
        !isnothing(EMULATOR_PROJECT_ID) && return EMULATOR_PROJECT_ID
        throw("Run Firebase.init() to load credentials first")
    end
    CREDENTIALS.project_id
end

"""
    get_token()

Return an OAuth access token for the loaded service account. The token is cached
and reused until shortly before it expires, so repeated calls are cheap.
"""
function get_token()
    global SESSION
    lock(SESSION_LOCK) do
        isnothing(CREDENTIALS) && throw("Run Firebase.init() to load credentials first")
        if isnothing(SESSION)
            SESSION = GoogleSession(CREDENTIALS, OAUTH_SCOPES)
        end
        GoogleCloud.authorize(SESSION)
    end
end

"""
    auth_header(service=:firestore)

`"Authorization" => ...` header for a request to `service`. When that service is
pointed at the emulator, the emulator's fixed owner token is used and no OAuth call
is made. Any other service, including `:management` (the Storage management API,
which has no emulator), gets a real service-account token, so emulating one service
never sends the fake token to a live one.
"""
function auth_header(service::Symbol=:firestore)
    if haskey(EMULATOR, service) && emulator_active(service)
        return "Authorization" => "Bearer owner"
    end
    token = get_token()
    "Authorization" => "$(token[:token_type]) $(token[:access_token])"
end
