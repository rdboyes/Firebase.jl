#

function get_singlepage(documentpath; pagesize=300, pagetoken::String="")
    base_url = firestore_url()
    headers = Dict(auth_header())
    project_id = projectid()
    firestore_path = "/projects/$project_id/databases/(default)/documents"
    url = "$base_url$firestore_path/$documentpath"
    query = Dict{String,Any}("pageSize" => pagesize)
    if !isempty(pagetoken)
        query["pageToken"] = pagetoken
    end
    @debug "Firestore request" url
    http_response = HTTP.get(url, headers; query=query)
    response_string = String(http_response.body)
    JSON.parse(response_string)
end

function get_collection(documentpath; pagesize=300)
    docs = []
    pagetoken = ""
    while true
        response = get_singlepage(
            documentpath,
            pagesize=pagesize,
            pagetoken=pagetoken,
        )
        # An empty collection (or an empty trailing page) has no "documents" key.
        append!(docs, Base.get(response, "documents", []))
        !haskey(response, "nextPageToken") && break
        pagetoken = response["nextPageToken"]
    end
    docs
end

get_document(documentpath) = get_singlepage(documentpath)

function get(path...)
    full_path = join(path, '/')
    length(path) % 2 == 0 && return convert_map(get_document(full_path))
    map(convert_map, get_collection(full_path))
end

"""
get_request(url::String)

# Get request which is general in nature and gets any document or collection

# Example
```julia
init("[FIREBASE_ADMIN_SDK].json")
res = get_request("/firebase_test/firebase_get") # document get
res = get_request("/firebase_test/firebase_get/firebase_get_collection") # collection fetch
```
"""
function get_request(url::String)
    header = Dict(auth_header())
    project_id = projectid()
    url = "$(firestore_url())/projects/$project_id/databases/(default)/documents$url"
    @debug "Firestore request" url
    http_response = HTTP.get(url, header)
    response_string = String(http_response.body)
    JSON.parse(response_string)
end

# Each request builder below that has a default body gets its own distinct global:
# a default argument is evaluated at call time, so several functions defaulting to a
# shared global `body` would all pick up whichever value was assigned last.

# mask gets particular fields looks like
# weird field in mask is just ignored and nothing happens
"""
firestore_batchget(batch)

Gets multiple documents. `batch` is a BatchGetDocumentsRequest body, e.g.
`Dict("documents" => ["projects/<id>/databases/(default)/documents/<path>", ...])`.
Documents returned by this method are not guaranteed 
to be returned in the same order that they were requested.

# Example
```julia
init("[FIREBASE_ADMIN_SDK].json")
pid = projectid()
res = firestore_batchget(Dict("documents" => [
    "projects/\$pid/databases/(default)/documents/users/alice",
]))
```
"""
function firestore_batchget(batch)
    header = Dict(auth_header())
    project_id = projectid()
    body = JSON.json(batch)
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents:batchGet"
    @debug "Firestore request" final_url
    http_response =  HTTP.request(
        "POST",
        final_url,
        header,
        body,
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end


# study types of writes from here https://firebase.google.com/docs/firestore/reference/rest/v1/Write
# study the effect of labelss, and update masks
# Labels associated with this batch write.
# mask gets particular fields looks like
# weird field in mask is just ignored and nothing happens
"""
firestore_batchwrite(batch)

Applies a batch of write operations.
The documents.batchWrite method does not apply the write operations atomically
and can apply them out of order. Method does not allow more than one write per document. 
Each write succeeds or fails independently. See the BatchWriteResponse for the success 
status of each write.

If you require an atomically applied set of writes, use documents.commit instead.

# Example
```julia
init("[FIREBASE_ADMIN_SDK].json")
pid = projectid()
res = firestore_batchwrite(Dict("writes" => [Dict("update" => Dict(
    "name" => "projects/\$pid/databases/(default)/documents/users/alice",
    "fields" => Dict("first" => Dict("stringValue" => "Alice")),
))]))
```
"""
function firestore_batchwrite(batch)
    header = Dict(auth_header())
    project_id = projectid()
    body = JSON.json(batch)
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents:batchWrite"
    @debug "Firestore request" final_url
    http_response =  HTTP.request(
        "POST",
        final_url,
        header,
        body,
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end

_BEGINTRANSACTION_BODY = Dict(
    "options" => Dict(

    )
)

# study transaction options and what is transactions used for here
"""
firestore_beginTransaction()

Starts a new transaction.
"options"
The options for the transaction. Defaults to a read-write transaction.

# Example
```julia
init("[FIREBASE_ADMIN_SDK].json")
firestore_beginTransaction()
```
"""
function firestore_beginTransaction()
    header = Dict(auth_header())
    project_id = projectid()
    # body = JSON.json(batch)
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents:beginTransaction"
    @debug "Firestore request" final_url
    http_response =  HTTP.request(
        "POST",
        final_url,
        header,
        # body,
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end

# commits a particular transaction that was started or is happening 
# this one is particularly interesting
"""
firestore_commit(transactionid="", body=Dict())

Commits a transaction, while optionally applying the writes in `body` (`Dict("writes" => [...])`).

# Example
```julia
init("[FIREBASE_ADMIN_SDK].json")
data = firestore_beginTransaction()
firestore_commit(data["transaction"])
```
"""
function firestore_commit(transactionid="", body=Dict{String,Any}())
    header = Dict(auth_header())
    project_id = projectid()
    # Copy rather than mutate: `body` may be the shared default, or a caller's dict
    # too narrowly typed to hold the transaction id.
    payload = Dict{String,Any}(body)
    payload["transaction"] = transactionid
    body = JSON.json(payload)
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents:commit"
    @debug "Firestore request" final_url
    http_response =  HTTP.request(
        "POST",
        final_url,
        header,
        body,
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end


    # Create Document
# body = """{
#         "fields": {
#           "test": {
#             "stringValue": "1"
#           }
#         }
#       }
#       """
_CREATEDOC_BODY = Dict(
    "fields" => Dict(
        "test" => Dict(
            "stringValue" => "1"
        )
    )
)
# above :The request body contains an instance of Document.


# how two add field to the 
# dpcument id is supposed to be a query parameter as of now it's hardcoded
"""
firestore_createdoc(url, body)


# Example

```julia
init("[FIREBASE_ADMIN_SDK].json")
firestore_createdoc("/firebase_test/firebase_post/two") 
firestore_createdoc("/firebase_test/firebase_post/three";query ="hello") # with document id name in query
```
"""
function firestore_createdoc(url, body=_CREATEDOC_BODY; query="")
    header = Dict(auth_header())
    project_id = projectid()
    body = JSON.json(body)
    query = Dict{String,Any}("documentId" => query)
    # mask part doesn't work yet
        # query = JSON.json(query)
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents$url"
    @debug "Firestore request" final_url
    http_response = HTTP.post(
        final_url,
        header,
        body;query=query
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end


# implement query properly for documentid and mask in here

"""
firestore_deletedoc(url)

Deletes a document

# Example
```julia
init("[FIREBASE_ADMIN_SDK].json")
firestore_createdoc("/firebase_test/firebase_post/three";query ="hello") # creates the document and then we delete it
firestore_deletedoc("/firebase_test/firebase_post/three/hello")
```
"""
function firestore_deletedoc(url)
    header = Dict(auth_header())
    project_id = projectid()
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents$url?currentDocument.exists=true"
    @debug "Firestore request" final_url
    http_response = HTTP.delete(
        final_url,
        header,
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end


"""
firestore_getdoclist(url)

Lists documents

# Example
```julia
init("[FIREBASE_ADMIN_SDK].json")
firestore_getdoclist("/firebase_test")
```
"""
function firestore_getdoclist(url)
    header = Dict(auth_header())
    project_id = projectid()
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents$url"
    @debug "Firestore request" final_url
    http_response =  HTTP.get(
        final_url,
        header,
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end



"""
firestore_getcollectionids(url; pagesize=300, pagetoken="")

Lists the collection IDs directly underneath the document at `url`. Returns the raw
response: `"collectionIds"` and, when there are more results, `"nextPageToken"`,
which can be passed back as `pagetoken` to fetch the next page.

# Example
```julia
init("[FIREBASE_ADMIN_SDK].json")
firestore_getcollectionids("/firebase_test/firebase_post")
```
"""
function firestore_getcollectionids(url; pagesize=300, pagetoken="")
    header = Dict("Content-Type" => "application/json", auth_header())
    project_id = projectid()
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents$url:listCollectionIds"
    # listCollectionIds takes its paging settings in the JSON request body.
    payload = Dict{String,Any}("pageSize" => pagesize)
    isempty(pagetoken) || (payload["pageToken"] = pagetoken)
    @debug "Firestore request" final_url
    http_response = HTTP.post(final_url, header, JSON.json(payload))
    JSON.parse(String(http_response.body))
end


# Doesn't work really
_PARTITIONQUERY_BODY = Dict(
    "partitionCount" => "1",
    "pageToken" => "",
    "pageSize" => 300,
    "structuredQuery" => Dict(
        "where" => Dict(
            "fieldFilter" => Dict(
                "field" => Dict("fieldPath" => "test"),
                "op" => "EQUAL",
                "value" => Dict("integerValue" => 1)
            )
        ),
        "from" => [Dict("collectionId" => "new1")]
    )
)

"""
firestore_partitionquery(url)

Partitions a query by returning partition cursors that can be used
to run the query in parallel. The returned partition cursors are 
split points that can be used by documents.runQuery as starting/end points for the query results.
"""
function firestore_partitionquery(url, body=_PARTITIONQUERY_BODY)
    header = Dict(auth_header())
    project_id = projectid()
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents$url:partitionQuery"
    body = JSON.json(body)
    @debug "Firestore request" final_url
    http_response = HTTP.post(
        final_url,
        header,
        body
        ;
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end



_PATCH_BODY = Dict(
    "fields" => Dict(
        "test1" => Dict(
            "stringValue" => "1"
        )
    )
)

# need to implement query parameters like updatemask ,mask currentDocument

"""
firestore_patch()

Updates or inserts a document.

# Example

```julia
init("[FIREBASE_ADMIN_SDK].json")
firestore_patch("/firebase_test/firebase_patch")
```
"""
function firestore_patch(url, body=_PATCH_BODY)
    header = Dict(auth_header())
    project_id = projectid()
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents$url"
    body = JSON.json(body)
    # query = Dict{String,Any}("documentId" => query)
    # mask part doesn't work yet
        # query = JSON.json(query)
    @debug "Firestore request" final_url
    http_response = HTTP.patch(
        final_url,
        header,
        body
        ;
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end

"""
firestore_rollback(transactionid,body=body)

Rolls back a transaction.

# Example

```julia
init("[FIREBASE_ADMIN_SDK].json")
data = firestore_beginTransaction()
# firestore_commit(data["transaction"])
firestore_rollback(data["transaction"])
```

# Output
If successful, the response body will be empty.

"""

_ROLLBACK_BODY = Dict("transaction" => "")
function firestore_rollback(transactionid, body=_ROLLBACK_BODY)
    header = Dict(auth_header())
    project_id = projectid()
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents:rollback"
    payload = Dict{String,Any}(body)
    payload["transaction"] = transactionid
    body = JSON.json(payload)

    @debug "Firestore request" final_url
    http_response = HTTP.post(
        final_url,
        header,
        body
        ;
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)

end

_RUNQUERY_SELECT_BODY = Dict(
    "newTransaction" => Dict(),
    "structuredQuery" => Dict(
        "select" => Dict(
         "fields" => [
          Dict(
           "fieldPath" => "test"
          ),
         ]
        )
    )
)

_RUNQUERY_BODY = Dict(
    "newTransaction" => Dict(),
    "structuredQuery" => Dict(
        "where" => Dict(
            "fieldFilter" => Dict(
                "field" => Dict("fieldPath" => "test"),
                "op" => "EQUAL",
                "value" => Dict("stringValue" => "1")
            )
        ),
        "from" => [Dict("collectionId" => "new")]
    )
)
# very specific as shown above is successfully run and it works by choosing 1/3 or 2/3 as the variables are changed

"""
firestore_runquery()

Runs a query.

# Example
```julia
init("[FIREBASE_ADMIN_SDK].json")
firestore_runquery("/firebase_test/firebase_post")
```
"""
function firestore_runquery(url, body=_RUNQUERY_BODY)
    header = Dict(auth_header())
    project_id = projectid()
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents$url:runQuery"
    body = JSON.json(body)
    @debug "Firestore request" final_url
    http_response = HTTP.post(
        final_url,
        header,
        body
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end