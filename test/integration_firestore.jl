# Cloud Firestore integration tests (issue #16), run against the Firestore emulator.

@testset "Cloud Firestore" begin
    collname = "emulatortest_$(rand(UInt32))"
    collpath = "/$collname"
    docname(id) = "projects/demo-firebase/databases/(default)/documents/$collname/$id"

    strfield(s) = Dict("stringValue" => s)

    @testset "create, read, patch, delete" begin
        res = firestore_createdoc(collpath, Dict("fields" => Dict("greeting" => strfield("hello")));
                                  query="doc1")
        @test res["name"] == docname("doc1")
        @test res["fields"]["greeting"]["stringValue"] == "hello"

        got = get_request("$collpath/doc1")
        @test got["fields"]["greeting"]["stringValue"] == "hello"

        # patch replaces the document's fields
        patched = firestore_patch("$collpath/doc1",
                                  Dict("fields" => Dict("greeting" => strfield("goodbye"))))
        @test patched["fields"]["greeting"]["stringValue"] == "goodbye"
        @test get_request("$collpath/doc1")["fields"]["greeting"]["stringValue"] == "goodbye"

        firestore_deletedoc("$collpath/doc1")
        # The document is gone, so fetching it is a 404.
        @test_throws HTTP.Exceptions.StatusError get_request("$collpath/doc1")
    end

    @testset "list documents" begin
        firestore_createdoc(collpath, Dict("fields" => Dict("n" => strfield("1"))); query="list1")
        firestore_createdoc(collpath, Dict("fields" => Dict("n" => strfield("2"))); query="list2")

        listed = firestore_getdoclist(collpath)
        names = Base.get(listed, "documents", [])
        @test docname("list1") in [d["name"] for d in names]
        @test docname("list2") in [d["name"] for d in names]

        firestore_deletedoc("$collpath/list1")
        firestore_deletedoc("$collpath/list2")
    end

    @testset "typed fields convert back to Julia values" begin
        fields = Dict(
            "str"   => Dict("stringValue" => "text"),
            "int"   => Dict("integerValue" => "42"),
            "float" => Dict("doubleValue" => 1.5),
            "bool"  => Dict("booleanValue" => true),
            "null"  => Dict("nullValue" => nothing),
            "arr"   => Dict("arrayValue" => Dict("values" => [
                Dict("stringValue" => "a"), Dict("integerValue" => "7")])),
            "map"   => Dict("mapValue" => Dict("fields" => Dict(
                "inner" => Dict("stringValue" => "nested")))),
            "time"  => Dict("timestampValue" => "2021-10-03T12:16:53Z"),
        )
        firestore_createdoc(collpath, Dict("fields" => fields); query="typed")

        # Firebase.get with an even number of path elements fetches one document.
        converted = Firebase.get(collname, "typed")
        @test converted["__id__"] == "typed"
        @test converted["str"] == "text"
        @test converted["int"] === 42
        @test converted["float"] == 1.5
        @test converted["bool"] === true
        @test converted["null"] === nothing
        @test converted["arr"] == ["a", 7]
        @test converted["map"]["inner"] == "nested"
        @test converted["time"] == DateTime(2021, 10, 3, 12, 16, 53)

        # An odd number of path elements fetches the whole collection.
        docs = Firebase.get(collname)
        @test "typed" in [d["__id__"] for d in docs]

        # convert_to_dict keys raw documents by id.
        raw = Firebase.get_collection(collname)
        @test haskey(convert_to_dict(raw), "typed")

        firestore_deletedoc("$collpath/typed")
    end

    @testset "listCollectionIds" begin
        # A document with a subcollection underneath it.
        firestore_createdoc(collpath, Dict("fields" => Dict()); query="parent")
        firestore_createdoc("$collpath/parent/child", Dict("fields" => Dict("x" => strfield("1")));
                            query="kid")

        ids = firestore_getcollectionids("$collpath/parent")
        @test "child" in Base.get(ids, "collectionIds", [])

        firestore_deletedoc("$collpath/parent/child/kid")
        firestore_deletedoc("$collpath/parent")
    end

    @testset "runQuery" begin
        firestore_createdoc(collpath, Dict("fields" => Dict("colour" => strfield("red")));
                            query="q1")
        firestore_createdoc(collpath, Dict("fields" => Dict("colour" => strfield("blue")));
                            query="q2")

        query = Dict("structuredQuery" => Dict(
            "from" => [Dict("collectionId" => collname)],
            "where" => Dict("fieldFilter" => Dict(
                "field" => Dict("fieldPath" => "colour"),
                "op" => "EQUAL",
                "value" => Dict("stringValue" => "red"))),
        ))
        results = firestore_runquery("", query)
        found = [r["document"]["name"] for r in results if haskey(r, "document")]
        @test docname("q1") in found
        @test !(docname("q2") in found)

        firestore_deletedoc("$collpath/q1")
        firestore_deletedoc("$collpath/q2")
    end

    @testset "batchGet and batchWrite" begin
        written = firestore_batchwrite(Dict("writes" => [
            Dict("update" => Dict("name" => docname("batch1"),
                                  "fields" => Dict("v" => strfield("one")))),
            Dict("update" => Dict("name" => docname("batch2"),
                                  "fields" => Dict("v" => strfield("two")))),
        ]))
        @test length(written["writeResults"]) == 2

        fetched = firestore_batchget(Dict("documents" =>
            [docname("batch1"), docname("batch2"), docname("nonexistent")]))
        found = Dict(r["found"]["name"] => r["found"]["fields"]["v"]["stringValue"]
                     for r in fetched if haskey(r, "found"))
        @test found[docname("batch1")] == "one"
        @test found[docname("batch2")] == "two"
        @test docname("nonexistent") in [r["missing"] for r in fetched if haskey(r, "missing")]

        firestore_deletedoc("$collpath/batch1")
        firestore_deletedoc("$collpath/batch2")
    end

    @testset "transactions" begin
        @testset "commit" begin
            tx = firestore_beginTransaction()
            @test haskey(tx, "transaction")

            res = firestore_commit(tx["transaction"], Dict("writes" => [
                Dict("update" => Dict("name" => docname("tx1"),
                                      "fields" => Dict("v" => strfield("committed")))),
            ]))
            @test haskey(res, "commitTime")
            @test get_request("$collpath/tx1")["fields"]["v"]["stringValue"] == "committed"

            firestore_deletedoc("$collpath/tx1")
        end

        @testset "rollback" begin
            tx = firestore_beginTransaction()
            res = firestore_rollback(tx["transaction"])
            # A successful rollback returns an empty JSON object.
            @test isempty(res)
        end
    end
end
