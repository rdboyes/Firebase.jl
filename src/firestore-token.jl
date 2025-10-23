using GoogleCloud
using Glob
using REPL
using REPL.TerminalMenus

const FIRESTORE_URL = "https://firestore.googleapis.com/v1"

"""
    initparsedjson( parsedjson)

initialize if the sdk key is in parsed JSON format and the file is saved as adminsdkkey.json

## Example

```md
julia> r = HTTP.get(BASE_URL, header); # returns a response with header and body
HTTP.Messages.Response

julia> response = JSON.json(JSON.parse(String(r.body)))
"{\"client_email\":\"****\",\"client_id\":\"****\",\"auth_uri\":\"https://accounts.google.com/o/oauth2/auth\",\"auth_provider_x509_cert_url\":\"https://www.googleapis.com/oauth2/v1/certs\",\"token_uri\":\"https://oauth2.googleapis.com/token\",\"client_x509_cert_url\":\"https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-jk50g%40volka-bot.iam.gserviceaccount.com\",\"project_id\":\"volka-bot\",\"type\":\"service_account\",\"private_key\":\"****\",\"private_key_id\":\"****\"}"

julia> initparsedjson( response)
Project Admin SDK key is adminsdkkey.json now!!
project_id: ****
client_email: ****
````
"""
function initparsedjson( parsedjson)
    global CREDENTIALS
    open("adminsdkkey.json","w") do f 
        write(f, parsedjson) 
    end
    CREDENTIALS = JSONCredentials("adminsdkkey.json")
    println("Project Admin SDK key is adminsdkkey.json now!!")
    println(CREDENTIALS)
end

"""
    init( julianparseddict::Dict)

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
Project Admin SDK key is adminsdkkey.json now!!
project_id: ****
client_email: ****
````
"""
function init(julianparseddict::Dict)
    global CREDENTIALS
    # credentials need to be in a Dict{Symbol, <:AbstractString} for GoogleCloud.jl
    CREDENTIALS = JSONCredentials(
        Dict(Symbol(k) => string(v) for (k, v) in julianparseddict)
    )
end

function init(filepath)
    global CREDENTIALS
    CREDENTIALS = JSONCredentials(filepath)
    println("Project Admin SDK key is ", filepath, " now!!")
    println(CREDENTIALS)
end

function init()
    global CREDENTIALS
    try
        filenames = glob("*.json", "firebase")
        menu = RadioMenu(filenames, pagesize=4)
        file = request("Choose your admin sdk key for use:", menu)
        
        if file != -1
            println("Project Admin SDK key is ", filenames[file], " now!!")
            CREDENTIALS = JSONCredentials(filenames[file])
        else
            println("Menu canceled.")
        end
    catch e
        println("Either the folder firebase doesn't exist or it's empty")
    end
end

function projectid()
    global CREDENTIALS
    isnothing(CREDENTIALS) && throw("Run Firebase.init() to load credentials first")
    CREDENTIALS.project_id
end

function get_token()
    global CREDENTIALS
    isnothing(CREDENTIALS) && throw("Run Firebase.init() to load credentials first")
    session = GoogleSession(CREDENTIALS, ["datastore"])
    GoogleCloud.authorize(session)
end

function auth_header()
    println(CREDENTIALS)
    token = get_token()
    "Authorization" => "$(token[:token_type]) $(token[:access_token])"
end
