STORE_URL = nothing

# Firebase Storage Management API. Unlike the object endpoints below, this API
# manages the *link* between a Google Cloud Storage bucket and a Firebase project.
# It has no emulator, so these calls always go to live Firebase.
const STORAGE_MANAGEMENT_URL = "https://firebasestorage.googleapis.com/v1beta"

# Resource name of a linked bucket, as used throughout the management API.
_bucket_resource(project_id, bucket) = "projects/$project_id/buckets/$bucket"

_management_url(path) = "$STORAGE_MANAGEMENT_URL/$path"

function _management_request(method, path; query=nothing, body=nothing)
    header = Dict(auth_header())
    url = _management_url(path)
    http_response = if body === nothing
        query === nothing ? HTTP.request(method, url, header) :
                            HTTP.request(method, url, header; query=query)
    else
        query === nothing ? HTTP.request(method, url, header, JSON.json(body)) :
                            HTTP.request(method, url, header, JSON.json(body); query=query)
    end
    JSON.parse(String(http_response.body))
end

"""
cloudstore_init(url)

Set cloud storage url initialize

# Example

```julia
cloudstore_init("https://firebasestorage.googleapis.com/v0/b/[PROJECT_ID].appspot.com/o")
```
"""
function cloudstore_init(url)
    global STORE_URL = url
    println("Cloud Storage set:", STORE_URL)
end

"""
cloudstore_listbuckets(; project_id=projectid(), pagesize=nothing, pagetoken=nothing)

Lists the linked storage buckets for a project.

Note that the Storage Management API identifies the project by its *project number*,
so `project_id` may need to be the numeric id rather than the textual one.

# Example
```julia
init("[PROJECT_SDK].json")
cloudstore_listbuckets()
#=
Dict{String, Any} with 1 entry:
  "buckets" => Any[Dict{String, Any}("name"=>"projects/123456789/buckets/my-app.appspot.com")]
=#
```
"""
function cloudstore_listbuckets(; project_id=projectid(), pagesize=nothing, pagetoken=nothing)
    query = Dict{String,Any}()
    pagesize === nothing || (query["pageSize"] = pagesize)
    pagetoken === nothing || (query["pageToken"] = pagetoken)
    _management_request("GET", "projects/$project_id/buckets";
                        query=isempty(query) ? nothing : query)
end

"""
cloudstore_getbucket(bucket; project_id=projectid())

Gets a single linked storage bucket. `bucket` is the bucket id, e.g.
`"my-app.appspot.com"`.

# Example
```julia
init("[PROJECT_SDK].json")
cloudstore_getbucket("my-app.appspot.com")
```
"""
cloudstore_getbucket(bucket; project_id=projectid()) =
    _management_request("GET", _bucket_resource(project_id, bucket))

"""
cloudstore_addfirebase(bucket; project_id=projectid())

Links a Google Cloud Storage bucket to a Firebase project.

# Example
```julia
init("[PROJECT_SDK].json")
cloudstore_addfirebase("my-existing-gcs-bucket")
```
"""
cloudstore_addfirebase(bucket; project_id=projectid()) =
    _management_request("POST", "$(_bucket_resource(project_id, bucket)):addFirebase";
                        body=Dict())

"""
cloudstore_removefirebase(bucket; project_id=projectid())

Unlinks a linked Google Cloud Storage bucket from a Firebase project. The bucket and
its contents are not deleted, they just stop being reachable through Firebase.

# Example
```julia
init("[PROJECT_SDK].json")
cloudstore_removefirebase("my-app.appspot.com")
```
"""
cloudstore_removefirebase(bucket; project_id=projectid()) =
    _management_request("POST", "$(_bucket_resource(project_id, bucket)):removeFirebase";
                        body=Dict())

# Extension-based content types. Previously this shelled out to `file --mime-type`,
# which does not exist on Windows.
const _CONTENT_TYPES = Dict(
    ".txt"  => "text/plain",
    ".csv"  => "text/csv",
    ".html" => "text/html",
    ".json" => "application/json",
    ".pdf"  => "application/pdf",
    ".xml"  => "application/xml",
    ".png"  => "image/png",
    ".jpg"  => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".gif"  => "image/gif",
    ".svg"  => "image/svg+xml",
    ".webp" => "image/webp",
    ".mp3"  => "audio/mpeg",
    ".wav"  => "audio/wav",
    ".ogg"  => "audio/ogg",
    ".mp4"  => "video/mp4",
    ".zip"  => "application/zip",
)

"""
    content_type(path) -> String

Best-effort content type for `path`, from its extension. Falls back to
`"application/octet-stream"`.
"""
content_type(path) =
    Base.get(_CONTENT_TYPES, lowercase(splitext(path)[2]), "application/octet-stream")

# Object paths are percent-encoded with "/" as %2F in the Firebase Storage REST API.
_encode_object_path(path) = join(split(lstrip(path, '/'), "/"), "%2F")

"""
cloudstore_sendfile(file2upload)

Send a file to cloud storage to store. The local file is read from `file2upload`
relative to the current directory, and stored under the same path in the bucket.

# Example

```julia
init("[PROJECT_SDK].json")
cloudstore_init("https://firebasestorage.googleapis.com/v0/b/[PROJECT_ID].appspot.com/o/")
cloudstore_sendfile("/audio/data.mp3")
```
"""
function cloudstore_sendfile(file2upload="/test/onedance.mp3")
    localpath = lstrip(file2upload, '/')
    header = Dict("Content-Type" => content_type(localpath), auth_header())
    body = read(localpath)
    # Uploads go to the collection endpoint with ?name=, which is what honours the
    # Content-Type header; posting to /o/<path> stores everything as octet-stream.
    final_url = "$(rstrip(STORE_URL, '/'))?name=$(_encode_object_path(file2upload))"
    println("FINAL_URL:", final_url)
    http_response = HTTP.post(
        final_url,
        header,
        body
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end

# STORE_URL = "https://firebasestorage.googleapis.com/v0/b/fir-jl-457eb.appspot.com/o/"

"""
cloudstore_get(file2download; token=nothing, dest=nothing)

Get a file from cloud storage and write it to disk. Returns the path written.

`token` is the object's download token, required when the bucket's rules do not
allow unauthenticated reads. `dest` overrides the local destination path, which
otherwise mirrors the remote path.

# Example
```julia
init("[PROJECT_SDK].json")
cloudstore_init("https://firebasestorage.googleapis.com/v0/b/[PROJECT_ID].appspot.com/o/")
cloudstore_get("/audio/data.mp3")
cloudstore_get("/data.mp3"; dest="local-copy.mp3")
```
"""
function cloudstore_get(file2download=""; token=nothing, dest=nothing)
    final_url = "$STORE_URL$(_encode_object_path(file2download))?alt=media"
    token === nothing || (final_url *= "&token=$token")
    println("Final URL:", final_url)
    res = HTTP.get(final_url, Dict(auth_header()))
    outpath = dest === nothing ? lstrip(file2download, '/') : dest
    dirtocreate = dirname(outpath)
    isempty(dirtocreate) || mkpath(dirtocreate)
    open(outpath, "w") do out
        write(out, res.body)
    end
    outpath
end
