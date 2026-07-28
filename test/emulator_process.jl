# Optional auto-start of the Firebase Emulator Suite for the integration tests.
#
# `EmulatorProcess.start()` launches `firebase emulators:start` against
# `test/firebase.json` and waits for the ports to accept connections. It is a
# best-effort helper: if the Firebase CLI is missing, an emulator is already
# running, or startup times out, it returns `nothing` and the integration tests
# fall back to their existing self-skip behaviour.
#
# Environment knobs:
#   FIREBASE_EMULATOR_AUTOSTART=false   never spawn an emulator
#   FIREBASE_EMULATOR_TIMEOUT=<seconds> startup wait, default 120 (first run
#                                       downloads the emulator jars)

module EmulatorProcess

using Sockets

const CONFIG      = joinpath(@__DIR__, "firebase.json")
const PROJECT_ID  = "demo-firebase"
const HOST        = "127.0.0.1"

# Must match the ports in firebase.json.
const PORTS = (firestore = 8080, database = 9000, auth = 9099)

const ENV_VARS = (firestore = "FIRESTORE_EMULATOR_HOST",
                  database  = "FIREBASE_DATABASE_EMULATOR_HOST",
                  auth      = "FIREBASE_AUTH_EMULATOR_HOST")

"""
    port_open(host, port) -> Bool

True when something accepts a TCP connection on `host:port`.
"""
function port_open(host, port)
    try
        close(Sockets.connect(host, port))
        return true
    catch
        return false
    end
end

all_up() = all(port_open(HOST, p) for p in PORTS)

# Services whose port is already accepting connections.
open_services() = [k for k in keys(PORTS) if port_open(HOST, PORTS[k])]

# The Firebase CLI ships as a batch shim on Windows, which CreateProcess cannot
# launch directly, so go through cmd.exe there.
emulator_cmd() = Sys.iswindows() ?
    `cmd /c firebase emulators:start --project $PROJECT_ID --config $CONFIG --only firestore,database,auth` :
    `firebase emulators:start --project $PROJECT_ID --config $CONFIG --only firestore,database,auth`

function cli_available()
    try
        cmd = Sys.iswindows() ? `cmd /c firebase --version` : `firebase --version`
        return success(pipeline(cmd, stdout=devnull, stderr=devnull))
    catch
        return false
    end
end

"""
    set_env!()

Point the standard `*_EMULATOR_HOST` variables at the local emulator so both this
package and any other Firebase client in the process pick it up.
"""
function set_env!()
    for k in keys(PORTS)
        ENV[ENV_VARS[k]] = "$HOST:$(PORTS[k])"
    end
end

"""
    start() -> Union{Nothing,Base.Process}

Start the emulator suite and wait for it to become reachable. Returns the process
handle when this call started it (pass it to [`stop`](@ref)), or `nothing` when no
emulator was started — because one was already running, autostart is disabled, the
CLI is unavailable, or startup failed.
"""
function start()
    # Any occupied port means we cannot start our own suite — the CLI refuses to
    # boot when even one of its ports is taken. Reuse whatever is already there and
    # let the integration tests skip the services that are missing.
    already = open_services()
    if !isempty(already)
        if length(already) == length(PORTS)
            @info "Firebase emulator already running; reusing it." host=HOST ports=PORTS
        else
            @warn "Some emulator ports are already in use, so no emulator will be " *
                  "started; tests will use whatever is reachable." host=HOST reachable=already
        end
        set_env!()
        return nothing
    end

    if lowercase(Base.get(ENV, "FIREBASE_EMULATOR_AUTOSTART", "true")) == "false"
        @info "FIREBASE_EMULATOR_AUTOSTART=false; not starting an emulator."
        return nothing
    end

    if !cli_available()
        @info "Firebase CLI not found on PATH; integration tests will self-skip. " *
              "Install it with `npm install -g firebase-tools` (Java is also required)."
        return nothing
    end

    logfile = joinpath(tempdir(), "firebase-emulator-$(getpid()).log")
    @info "Starting Firebase emulator suite..." config=CONFIG log=logfile
    proc = try
        run(pipeline(emulator_cmd(), stdout=logfile, stderr=logfile); wait=false)
    catch err
        @warn "Could not launch the Firebase emulator." exception=err
        return nothing
    end

    timeout = something(tryparse(Float64, Base.get(ENV, "FIREBASE_EMULATOR_TIMEOUT", "")), 120.0)
    deadline = time() + timeout
    while time() < deadline
        if all_up()
            @info "Firebase emulator ready." ports=PORTS
            set_env!()
            return proc
        end
        if process_exited(proc)
            @warn "Firebase emulator exited during startup; integration tests will " *
                  "self-skip. See the log for details." log=logfile
            return nothing
        end
        sleep(1)
    end

    @warn "Firebase emulator did not come up within $(timeout)s; integration tests " *
          "will self-skip. See the log for details." log=logfile
    stop(proc)
    return nothing
end

"""
    stop(proc)

Shut down an emulator suite started by [`start`](@ref). A `nothing` argument is a
no-op, so an emulator that was already running is left alone.
"""
stop(::Nothing) = nothing

function stop(proc::Base.Process)
    process_exited(proc) && return nothing
    @info "Stopping Firebase emulator..."
    try
        if Sys.iswindows()
            # The CLI spawns java children; kill the whole tree.
            run(pipeline(`taskkill /PID $(getpid(proc)) /T /F`,
                         stdout=devnull, stderr=devnull))
        else
            kill(proc, Base.SIGTERM)
        end
    catch err
        @warn "Failed to stop the Firebase emulator cleanly." exception=err
    end
    # Give the emulators a moment to release their ports.
    deadline = time() + 20
    while time() < deadline && !process_exited(proc)
        sleep(0.5)
    end
    return nothing
end

end # module
