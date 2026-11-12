# Firebase Emulator Suite

Firebase.jl can talk to the local
[Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite) instead
of live Firebase, which is handy for tests and local development.

```julia
using Firebase

# Use the standard *_EMULATOR_HOST environment variables, if set
use_emulator()

# Or name services explicitly (true = default port on localhost)
use_emulator(firestore=true, database=true, auth=true, storage=true,
             project_id="demo-firebase")

# Switch every service back to live Firebase
use_production()
```

When a service is emulated, requests to it use the emulator's owner token, so no
service-account credentials are needed. Services that are not emulated keep using
live Firebase and your real credentials.

| Service     | Environment variable              | Default port |
|-------------|-----------------------------------|--------------|
| Firestore   | `FIRESTORE_EMULATOR_HOST`         | 8080         |
| Realtime DB | `FIREBASE_DATABASE_EMULATOR_HOST` | 9000         |
| Auth        | `FIREBASE_AUTH_EMULATOR_HOST`     | 9099         |
| Storage     | `FIREBASE_STORAGE_EMULATOR_HOST`  | 9199         |

```@autodocs
Modules = [Firebase]
Pages   = ["emulator.jl"]
```
