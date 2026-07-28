#

function get_singlepage(documentpath; pagesize=300, pagetoken::String="")
    @show "Firestore.get_singlepage", documentpath, pagesize, pagetoken
    base_url = firestore_url()
    headers = Dict(auth_header())
    project_id = projectid()
    firestore_path = "/projects/$project_id/databases/(default)/documents"
    url = "$base_url$firestore_path/$documentpath"
    query = Dict{String,Any}("pageSize" => pagesize)
    if !isempty(pagetoken)
        query["pageToken"] = pagetoken
    end
    http_response = HTTP.get(url, headers; query=query)
    response_string = String(http_response.body)
    JSON.parse(response_string)
end

function get_collection(documentpath; pagesize=300)
    @show "Firestore.get_collection", documentpath, pagesize
    docs = []
    pagetoken = ""
    while true
        response = get_singlepage(
            documentpath,
            pagesize=pagesize,
            pagetoken=pagetoken,
        )
        isempty(response) && return docs
        push!(docs, response["documents"]...)
        !haskey(response, "nextPageToken") && break
        pagetoken = response["nextPageToken"]
    end
    docs
end

get_document(documentpath) = get_singlepage(documentpath)

function get(path...)
    @show "Firestore.get", path
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
    println(url)
    http_response = HTTP.get(url, header)
    response_string = String(http_response.body)
    JSON.parse(response_string)
end

body = Dict(
    "newTransaction" => Dict(),
    # "transaction" => "",
    # "readTime" => "",
    "documents" => [
    "projects/fir-jl-457eb/databases/(default)/documents/firebase_test/firebase_get",
    "projects/fir-jl-457eb/databases/(default)/documents/firebase_test/firebase_get?collectionID=firebase_get_collection",
    "projects/fir-jl-457eb/databases/(default)/documents/firebase_test/firebase_get/firebase_get_collection/test",
    ],
    "mask" => Dict(
        "fieldPaths" => [
            "first1",
        ]),
    
)

# mask gets particular fields looks like
# weird field in mask is just ignored and nothing happens
"""
firestore_batchget(batch=body)

Gets multiple documents
Documents returned by this method are not guaranteed 
to be returned in the same order that they were requested.

# Example
```julia
init("[FIREBASE_ADMIN_SDK].json")
res = firestore_batchget()
```
"""
function firestore_batchget(batch=body)
    header = Dict(auth_header())
    project_id = projectid()
    println(batch)
    body = JSON.json(batch)
    println("Batch:", body)
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents:batchGet"
    http_response =  HTTP.request(
        "POST",
        final_url,
        header,
        body,
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end


body = Dict(
    "writes" => [
        Dict(
            "update" => Dict(
                "name" => "projects/fir-jl-457eb/databases/(default)/documents/firebase_test/firebase_get",
                "fields" => Dict(
                    "first" => Dict(
                        "stringValue" => "ashwani",
                        ),
                        "last" => Dict(
                            "stringValue" => "rathee",
                            )
                )
            ),
            "updateMask" => Dict(
                "fieldPaths" => [
                    "first",
                    "last",
                ]
            )
        )
    ],
    "labels" => Dict(
        string => "ABC"
    )
)

# study types of writes from here https://firebase.google.com/docs/firestore/reference/rest/v1/Write
# study the effect of labelss, and update masks
# Labels associated with this batch write.
# mask gets particular fields looks like
# weird field in mask is just ignored and nothing happens
"""
firestore_batchwrite(batch=body)

Applies a batch of write operations.
The documents.batchWrite method does not apply the write operations atomically
and can apply them out of order. Method does not allow more than one write per document. 
Each write succeeds or fails independently. See the BatchWriteResponse for the success 
status of each write.

If you require an atomically applied set of writes, use documents.commit instead.

# Example
```julia
init("[FIREBASE_ADMIN_SDK].json")
res = firestore_batchwrite()
```
"""
function firestore_batchwrite(batch=body)
    header = Dict(auth_header())
    project_id = projectid()
    println(batch)
    body = JSON.json(batch)
    println("Batch:", body)
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents:batchWrite"
    http_response =  HTTP.request(
        "POST",
        final_url,
        header,
        body,
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end

body = Dict(
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
    # println(batch)
    # body = JSON.json(batch)
    # println("Batch:", body)
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents:beginTransaction"
    http_response =  HTTP.request(
        "POST",
        final_url,
        header,
        # body,
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end

body = Dict(
    "writes" => [
        Dict(
            "update" => Dict(
                "name" => "projects/fir-jl-457eb/databases/(default)/documents/firebase_test/firebase_get",
                "fields" => Dict(
                    "first" => Dict(
                        "stringValue" => "ashwani",
                        ),
                        "last" => Dict(
                            "stringValue" => "rathee",
                            )
                )
            ),
            "updateMask" => Dict(
                "fieldPaths" => [
                    "first",
                    "last",
                ]
            )
        )
    ],

    "transaction" => "EZTktxl/jJ9GIlkA3ModskgtczlV2HUqlqGQbh6U8YClsJvU07MTX5/8q0Fhd3hAvi0aSvm4NLF2H8FNiEzspxJLVM4NOZVDsClQgpuLqwkA9uFrQM81VXxzYzGLLvU0hssZZg=="
)

# commits a particular transaction that was started or is happening 
# this one is particularly interesting
"""
firestore_commit(transactionid="",body =body)

Commits a transaction, while optionally updating documents.

# Example
```julia
init("[FIREBASE_ADMIN_SDK].json")
data = firestore_beginTransaction()
firestore_commit(data["transaction"])
```
"""
function firestore_commit(transactionid="", body=body)
    header = Dict(auth_header())
    project_id = projectid()
    body["transaction"] = transactionid
    body = JSON.json(body)
    println("Body:", body)
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents:commit"
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
body = Dict(
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
function firestore_createdoc(url, body=body;query=query)
    header = Dict(auth_header())
    project_id = projectid()
    body = JSON.json(body)
    println("Body:", body)
    query = Dict{String,Any}("documentId" => query)
    # mask part doesn't work yet
        # query = JSON.json(query)
        # println(query)
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents$url"
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
    http_response =  HTTP.get(
        final_url,
        header,
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end



"""
firestore_getcollectionids(url;query="")

Lists all the collection IDs underneath a document.

# Example
```julia
init("[FIREBASE_ADMIN_SDK].json")
firestore_getcollectionids("/firebase_test/firebase_post")
```
"""
function firestore_getcollectionids(url;query="")
    header = Dict(auth_header())
    project_id = projectid()
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents$url:listCollectionIds"
    pagesize = 300
    pagetoken = ""
    if !isempty(pagetoken)
        query["pageToken"] = pagetoken
    end
    query = Dict{String,Any}("pageSize" => pagesize, "pageToken" => pagetoken)

    # this query content is supposed to be request body
    http_response = HTTP.post(
        final_url,
        header;
        query=query,
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end


# Doesn't work really
body = Dict(
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
function firestore_partitionquery(url, body=body)
    header = Dict(auth_header())
    project_id = projectid()
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents$url:partitionQuery"
    body = JSON.json(body)
    println("Body:", body)
    http_response = HTTP.post(
        final_url,
        header,
        body
        ;
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end



body = Dict(
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
function firestore_patch(url, body=body)
    header = Dict(auth_header())
    project_id = projectid()
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents$url"
    body = JSON.json(body)
    println("Body:", body)
    # query = Dict{String,Any}("documentId" => query)
    # mask part doesn't work yet
        # query = JSON.json(query)
        # println(query)
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

body = Dict("transaction" => "")
function firestore_rollback(transactionid, body=body)
    header = Dict(auth_header())
    project_id = projectid()
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents:rollback"
    body["transaction"] = transactionid
    body = JSON.json(body)
    println("Body:", body)

    http_response = HTTP.post(
        final_url,
        header,
        body
        ;
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)

end

body = Dict(
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

body = Dict(
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
function firestore_runquery(url, body=body)
    header = Dict(auth_header())
    project_id = projectid()
    final_url = "$(firestore_url())/projects/$project_id/databases/(default)/documents$url:runQuery"
    body = JSON.json(body)
    println("Body:", body)
    println("FINAL_URL:", final_url)
    http_response = HTTP.post(
        final_url,
        header,
        body
    )
    response_string = String(http_response.body)
    JSON.parse(response_string)
end