# Maintainer simulator lab (Windows 11)

**Developer/test tooling only.** This is not a plugin setting, production runtime
feature, installer or Windows service. Do not point it at a real controller or
production Homebridge storage. Node 24 and this checkout's installed dependencies
and compiled `dist` are required. No new dependencies are introduced.

## Everyday commands

Open PowerShell in the Windows checkout used for the lab (Codespaces remains the
authoritative development checkout):

```powershell
cd C:\Users\mitch\GitHub\homebridge-cmd4-AdvantageAir
```

| Operation | Windows command | npm equivalent |
| --- | --- | --- |
| Start everything | `.\lab.cmd start` | `npm run lab:start` |
| Stop everything | `.\lab.cmd stop` | `npm run lab:stop` |
| Status | `.\lab.cmd status` | `npm run lab:status` |
| Start simulator | `.\lab.cmd simulator start` | `npm run simulator:start` |
| Stop simulator | `.\lab.cmd simulator stop` | `npm run simulator:stop` |
| Simulator status | `.\lab.cmd simulator status` | `npm run simulator:status` |
| Start Homebridge | `.\lab.cmd homebridge start` | `npm run lab:homebridge:start` |
| Stop Homebridge | `.\lab.cmd homebridge stop` | `npm run lab:homebridge:stop` |
| Homebridge status | `.\lab.cmd homebridge status` | `npm run lab:homebridge:status` |
| Follow Homebridge log | `.\lab.cmd logs` | `npm run lab:logs` |
| Follow Homebridge explicitly | `.\lab.cmd logs homebridge` | `npm run lab:logs:homebridge` |
| Follow simulator log | `.\lab.cmd logs simulator` | `npm run lab:logs:simulator` |

The Windows shortcut uses Node on PATH, or the existing bundled Node installation
on this laptop. It does not need npm or a running Codex session. The underlying
command is `node dev/lab/lab.mjs start` (and likewise stop/status).

Start-all starts the simulator first; stop-all stops Homebridge first. Repeating
start does not launch duplicates or reload the fixture. A running status confirms
the managed process, not that an iPhone has reached it. An individual simulator
stop leaves Homebridge running with unavailable simulated accessories.

After spawning a worker, the manager retries transient control/status timeouts
within one 30-second startup deadline. Authentication and process-identity errors
still fail immediately. If startup expires, inspect status and logs: a worker may
finish later. The manager does not kill that worker or another process on timeout.

## Components and data flow

Apple Home → isolated Homebridge/HAP → v4 accessory/coordinator → HTTP
`/setAircon` → existing AirConServer simulator → `/getSystemData` → confirmation.

- `dev/lab/AirConServer.cjs`: copy of the existing v3 simulator, with v4 JSON
  parsing, local dependency resolution, loopback-only binding and an exported
  server-ready promise for safe lifecycle control. Original source
  blob: `14e04491e99e312899a2c2a9b48c86e9ca9d0083`. Its legacy style is excluded
  individually from ESLint; the new control scripts are linted normally.
- `dev/lab/fixtures/percentage.json`: default startup fixture, derived from the historical
  single-system fixture's existing type-zero z06. It starts **Percentage Test Zone
  On at 40%**. The worker loads it on every fresh simulator start.
- `dev/lab/fixtures/myzone.json`: explicitly selected MyZone scenario with Living
  and Bedroom reference zones plus the percentage zone. Select it using
  `dev/lab/myzone.ps1 -Action Reset`, as described below.
- `dev/lab/lab.mjs`, `worker.mjs`, `paths.mjs`: local start/stop/status controls.
- `dev/lab/diagnostics.mjs`: development-process-only HAP write, admission, payload
  and readback diagnostics. No plugin source or production logging changes.
- Plugin loaded from this checkout's `dist`, dependencies from `node_modules`.

The simulator keeps edits and the loaded fixture queue in memory. Every fresh
simulator start loads the default percentage fixture; Homebridge-only restarts
leave the current scenario and its state alone. Start does not save live edits
back to fixture files. The load endpoint appends fixtures rather than replacing
them, so explicit scenario selection must reset the queue before loading and
verifying the chosen fixture. The MyZone helper performs that sequence without
changing the worker's default fixture path. Future fixtures can live alongside
these two, with an explicit reset/load/verification procedure; there is no generic
scenario selector or automatic switching between scenarios.

## Persistent storage and ports

The maintainer's current permanent runtime is **`C:\Users\mitch\AdvantageAirLab`**,
selected by ignored `dev/lab/local.json`. It is independent of the original Codex
project and its old `percentage-home-trial` directory. Use this permanent runtime
for the existing paired bridge and current logs. This documentation correction
does not change the local setting or move/regenerate any runtime files. It contains:

- `storage/config.json`: isolated Homebridge configuration.
- `storage/persist/`: existing Apple Home pairing and identifiers — preserve it.
- `storage/accessories/`: existing accessory cache — preserve it.
- `simulator.log`, `simulator-error.log`: appended simulator output/errors.
- `homebridge.log`, `homebridge-error.log`: appended managed Homebridge output/errors.
- `*-control.json`: private management token/PID records; not HomeKit pairing data.

`AA_LAB_HOME` can override the runtime directory. Without an override/local.json,
the default is `../advantage-air-lab`, outside the repository. The tools require
an existing isolated `storage/config.json`; they do not silently create a new
bridge identity. For this already-paired laptop, leave the local setting alone.
Never commit runtime storage, pairing files, management tokens or local.json.

| Purpose | Address / port |
| --- | --- |
| Simulator | `127.0.0.1:52025` (laptop only) |
| Simulator management | `127.0.0.1:52026` (authenticated) |
| Homebridge management | `127.0.0.1:52027` (authenticated) |
| Isolated HomeKit bridge | Laptop LAN address configured in `storage/config.json`, port `51889` |
| HomeKit discovery | mDNS, UDP 5353, ciao advertiser |

The bridge name, username/PIN and network binding are in the preserved
`C:\Users\mitch\AdvantageAirLab\storage\config.json`. It is already paired:
**do not add it again**. Restarting uses the same identity and preserves room
assignments; accessories require their matching scenario to become responsive. Keep the
laptop awake and on the same LAN as the iPhone. If its IP changes, update only
the isolated config's `bridge.bind`; preserve username, PIN and storage. No
production configuration changes are needed for scenario selection.

## Inspect and troubleshoot

```powershell
.\lab.cmd status
.\lab.cmd logs
# Ctrl+C stops log viewing, not the lab.
.\lab.cmd logs simulator
```

Log viewing prints the last 40 available lines and follows new lines. It also
works while a component is stopped if its log exists. Missing logs produce a
clear error. It does not start, stop or acquire management control of the lab.

HAP diagnostics use `[AA HOME TRIAL]`: `HAP_WRITE`, `DESIRED_ADMITTED`,
`HAP_ACCEPTED`, `SET_PAYLOAD`, `SIMULATOR_READ`. Existing plugin confirmation logs
complete the trace. The default percentage fixture has no usable temperature-reference
zone, so its simulated thermostat's current temperature is unavailable; that is unrelated
to percentage testing. The MyZone fixture adds temperature-reference zones. Interpret
accessory availability against the selected scenario, not the default fixture alone.

Stop-all is the safe shutdown command. Homebridge runs its own SIGINT teardown
inside its process; the simulator closes its own server instance. Neither command kills
a process by PID. A per-run secret and matching component/runtime identity are
required before shutdown. Unmanaged listeners or identity/authentication mismatch
produce an error and are left alone. Do not work around this by killing all Node
processes. Inspect the indicated logs instead. Start failures are reported; use
status and stop for any component that did start.

When stopped, Home will eventually mark test accessories unavailable. Start the
lab later without re-pairing; select MyZone explicitly if that is the scenario you
need, because a fresh simulator starts with percentage.json. Physical Advantage Air firmware
percentage retention is still not established by this simulated environment.

## Selecting the MyZone scenario

See [MyZone operator procedure](myzone-presentation.md) for the guarded scenario reset
and the separate Homebridge-only persistence test. `dev/lab/myzone.ps1 -Action Reset`
ensures the managed simulator is running before HTTP calls, clears the fixture queue
with `/reInit`, loads MyZone and verifies consecutive reads before starting Homebridge.
The simulator's load endpoint appends fixtures; loading MyZone after the worker's
default percentage fixture without resetting does not immediately replace it.

`-Action RestartHomebridge` preserves simulator memory and fails if the simulator is
missing or its PID changes. A full lab restart reloads the default percentage fixture
and cannot establish persistence of the prior simulated state. Keep all pairing data.

Homebridge warnings use stderr and are in `homebridge-error.log`; `lab.cmd logs`
currently follows `homebridge.log` (stdout) only. Check both when diagnosing a refusal.

The linked MyZone procedure invokes `.ps1` files through `powershell.exe -NoProfile
-ExecutionPolicy Bypass -File ...` and checks the exit code. This permits the script
for that process without changing permanent machine/user policy. Enforced Group Policy
can still prevent execution; stop if blocked rather than changing policy globally.
