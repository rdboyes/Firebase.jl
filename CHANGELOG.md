# Changelog

## v0.2.0

This release makes repeated requests much faster, fixes several bugs in the
Realtime Database and Firestore helpers, and removes hard-coded test data that
older versions shipped as default arguments. **It contains breaking changes**, so
please read the section below before upgrading.

### ⚠️ Breaking changes

#### Arguments that used to have hidden defaults are now required

Older versions filled in example values from the original developer's project:
a real Web API key, a real person's email address, an old Google ID token, and
request bodies that wrote to a specific Firestore project. Calling these
functions without arguments could send email to a stranger or write test data.
Those defaults have been removed.

| Function | Before | Now |
|---|---|---|
| `set_webapikey` | `set_webapikey()` used a built-in key | `set_webapikey(key)`, key required |
| `firebase_passwordreset` | defaulted to a hard-coded email | `firebase_passwordreset(email)` |
| `firebase_fetchproviders` | defaulted to a hard-coded email; `continueUri` was `http://localhost:8080/app` | `firebase_fetchproviders(email; continueuri="http://localhost")` |
| `firebase_signinoauth` | defaulted to a hard-coded ID token | `firebase_signinoauth(id_token, provider="google.com")` |
| `firestore_batchget` | defaulted to an example request | `firestore_batchget(batch)` |
| `firestore_batchwrite` | defaulted to an example write | `firestore_batchwrite(batch)` |
| `firestore_commit` | default body wrote an example document | default body is empty, so it only commits the transaction |

The exported global `GOOGLE_ID_TOKEN` has been removed. Any Firebase Auth call
made before `set_webapikey` now throws an error asking you to set the key.

#### `auth_header` chooses the token per service

`auth_header(service=:firestore)` now takes the service the request is for. The
emulator's `Bearer owner` token is used only when *that* service is emulated.
Previously, turning on the Firestore *or* Storage emulator sent the fake token on
every request, including requests to services that were still live. Cloud
Storage helpers now use `auth_header(:storage)`, and the Storage management API
(`cloudstore_listbuckets` and friends), which has no emulator, always gets a
real token.

If you call `auth_header()` yourself for something other than Firestore, pass
the service, for example `auth_header(:database)` or `auth_header(:storage)`.

#### Realtime Database requests are authenticated automatically

When you don't pass an `authheader`, `realdb_*` calls now:

- use the emulator owner token when the database emulator is active;
- otherwise use your service-account token, if you have called `init(...)`;
- otherwise go out unauthenticated, as before.

> **Note:** after `init(...)`, Realtime Database calls act as the admin service
> account and **bypass your security rules**. To act as an end user instead,
> pass their ID token with `query = Dict("auth" => id_token)`, or pass your own
> `authheader`.

Other Realtime Database changes:

- The `query` keyword is now actually sent. Earlier versions ignored it. For
  example, `realdb_get(path; query=Dict("shallow" => true))` now works.
- The unused `pageSize`/`pageToken` URL parameters are no longer sent.
- `realdb_delete(url, authheader=""; query)` no longer accepts a third (body)
  argument, which DELETE ignored anyway.
- Calling any `realdb_*` function before `realdb_init` (or `use_emulator`) now
  throws a clear error.
- The unexported `readdb_download` is renamed to `realdb_download` and is now
  exported.

#### `firestore_getcollectionids` signature

Now `firestore_getcollectionids(url; pagesize=300, pagetoken="")`. The old
`query` keyword, which was ignored, has been removed. Paging settings are sent in
the request body as the API requires. The return value is still the raw response,
including `nextPageToken` when there are more results.

#### `initparsedjson` no longer writes your key to disk

`initparsedjson(jsonstring)` now parses the service-account key in memory.
It used to save the private key as `adminsdkkey.json` in the current directory.
If your code relied on that file existing, write it yourself or call
`init(path)` with your own file.

#### Much less console output

Request functions no longer print URLs, request bodies or `@show` debugging
output. To see request URLs, enable debug logging:

```julia
ENV["JULIA_DEBUG"] = "Firebase"
```

Related changes:

- `init(path)` logs one `@info` line with the project ID instead of printing.
- `use_emulator` no longer prints its configuration; it still returns it.
- `set_webapikey` no longer echoes the key.
- `realdb_init` and `cloudstore_init` return the URL instead of printing it.

#### Wider OAuth scopes

The service-account token now requests `cloud-platform`, `datastore`,
`devstorage.full_control`, `firebase`, `firebase.database` and `userinfo.email`.
Earlier versions requested `datastore` only. One token now works for every
service the package supports. Access is still governed by the service account's
IAM roles.

### Performance

- **The OAuth token is cached.** Earlier versions requested a new token from
  Google before *every* request: one extra JWT signature and network round trip
  each time. The token is now reused until shortly before it expires and is
  shared safely between tasks. Calling `init` with new credentials discards the
  old token.

### Bug fixes

- `get_collection` (and `get` on a collection) no longer throws a `KeyError` on
  a page with no `"documents"` key.
- `firestore_getcollectionids` now sends its paging settings correctly.
- `realdb_download` no longer builds a malformed URL.
- `init` accepts any `AbstractDict`, including the objects returned by
  JSON.jl 1.x.

### Dependencies

- Documenter is no longer a runtime dependency. Test is now test-only.
  Installing Firebase.jl pulls in noticeably fewer packages.

### Upgrading: quick checklist

1. Pass your Web API key explicitly: `set_webapikey("...")`.
2. Pass an email to `firebase_passwordreset` and `firebase_fetchproviders`, and
   an ID token to `firebase_signinoauth`.
3. Pass a request body to `firestore_batchget` and `firestore_batchwrite`.
4. If you call `auth_header()` directly for Storage or the Realtime Database,
   pass the service (`:storage`, `:database`).
5. If you use the Realtime Database after `init(...)` and depend on security
   rules being enforced, pass an end user's ID token via `query`.
6. If you parsed printed output, or relied on `adminsdkkey.json` being created,
   update that code.
