module Firebase

# Includes
include("emulator.jl")
include("firestore.jl")
include("firestore-token.jl")
include("firebaseauth.jl")
include("convert.jl")
include("cloudstorage.jl")
include("realtime.jl")

# Imports
using HTTP
using GoogleCloud
using JSON
using Glob

# Emulator configuration
export use_emulator
export use_production
export emulator_active
export emulator_running

# Utils
export get
export get_collection, get_singlepage,get_document, get_request
export convert_to_dict
export convert_field
export convert_timestamp
export convert_map
export convert_array

# Firebase Authentication related
export set_webapikey
export firebase_signup
export firebase_signin
export firebase_signinanon
export firebase_signinoauth
export firebase_fetchproviders
export firebase_passwordreset
export verify_passwordresetcode
export confirm_passwordreset
export firebase_changeemail
export firebase_changepassword
export firebase_updateprofile
export firebase_getuserinfo
export firebase_linkuserinfo
export firebase_unlinkprovide
export firebase_verifyemail
export firebase_confirmemailverify
export firebase_deleteuser

# Cloud Firestore
export init
export initparsedjson
export projectid
export get_token
export auth_header
export firestore_batchget
export firestore_batchwrite
export firestore_beginTransaction
export firestore_createdoc
export firestore_commit
export firestore_deletedoc
export firestore_getcollectionids
export firestore_getdoclist
export firestore_partitionquery
export firestore_patch
export firestore_rollback
export firestore_runquery

# Realtime Database
export realdb_init
export realdb_get
export realdb_post
export realdb_delete
export realdb_put
export realdb_patch

# Cloud Storage
export cloudstore_init
export cloudstore_get
export cloudstore_sendfile


end # module
