# Maintainer simulator lab (Windows 11)

**Developer/test tooling only.** This is not a plugin setting, production runtime
feature, installer or Windows service. Do not point it at a real controller or
production Homebridge storage. Node 24 and this checkout's installed dependencies
and compiled `dist` are required. No new dependencies are introduced.

## Everyday commands

Open PowerShell in the normal Windows checkout:

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
start does not launch duplicates or reload the fixture. Status means the managed
process is running, not that an iPhone has reached it. An individual simulator
stop leaves Homebridge running with unavailable simulated accessories.

## Components and data flow

Apple Home → isolated Homebridge/HAP → v4 accessory/coordinator → HTTP
`/setAircon` → existing AirConServer simulator → `/getSystemData` → confirmation.

- `dev/lab/AirConServer.cjs`: copy of the existing v3 simulator, with v4 JSON
  parsing, local dependency resolution, loopback-only binding and an exported
  server-ready promise for safe lifecycle control. Original source
  blob: `14e04491e99e312899a2c2a9b48c86e9ca9d0083`. Its legacy style is excluded
  individually from ESLint; the new control scripts are linted normally.
- `dev/lab/fixtures/percentage.json`: current fixture, derived from the historical
  single-system fixture's existing type-zero z06. It starts **Percentage Test Zone
  On at 40%**. No other scenarios have been added.
- `dev/lab/lab.mjs`, `worker.mjs`, `paths.mjs`: local start/stop/status controls.
- `dev/lab/diagnostics.mjs`: development-process-only HAP write, admission, payload
  and readback diagnostics. No plugin source or production logging changes.
- Plugin loaded from this checkout's `dist`, dependencies from `node_modules`.

The simulator keeps edits in memory. Every fresh simulator start reloads the
fixture (40%); Homebridge-only restarts leave simulator state alone. Start does
not save live edits back to the fixture. Add future fixtures beside the current
one and deliberately change the worker's fixture path when developing a scenario;
there is no scenario framework or automatic fixture switching.

## Persistent storage and ports

On this laptop, ignored `dev/lab/local.json` points to the absolute path of the
existing `percentage-home-trial` directory (under the original Codex project).
This is the **original** test directory; it was not
moved, regenerated or replaced. That directory contains:

- `storage/config.json`: isolated Homebridge configuration.
- `storage/persist/`: existing Apple Home pairing and identifiers — preserve it.
- `storage/accessories/`: existing accessory cache — preserve it.
- `simulator.log`, `simulator-error.log`: appended simulator output/errors.
- `homebridge.log`, `homebridge-error.log`: appended managed Homebridge output/errors.
- `*-control.json`: private management token/PID records; not HomeKit pairing data.
- Older experiment logs/fixtures/notes remain as historical records.

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
| Isolated HomeKit bridge | `192.168.50.20:51889` |
| HomeKit discovery | mDNS, UDP 5353, ciao advertiser |

Bridge name: **AA Percentage Lab**. Its username/PIN are in the preserved
`storage/config.json`. It is already paired: **do not add it again**. Restarting
uses the same identity, so the same room assignments/accessories return. Keep the
laptop awake and on the same LAN as the iPhone. If its IP changes, update only
the isolated config's `bridge.bind`; preserve username, PIN and storage. No
firewall rules or production configuration were changed for this setup.

## Inspect and troubleshoot

```powershell
.\lab.cmd status
.\lab.cmd logs
# Ctrl+C stops log viewing, not the lab.
.\lab.cmd logs simulator
(Invoke-RestMethod http://127.0.0.1:52025/getSystemData).aircons.ac1.zones.z06
```

Log viewing prints the last 40 available lines and follows new lines. It also
works while a component is stopped if its log exists. Missing logs produce a
clear error. It does not start, stop or acquire management control of the lab.

HAP diagnostics use `[AA HOME TRIAL]`: `HAP_WRITE`, `DESIRED_ADMITTED`,
`HAP_ACCEPTED`, `SET_PAYLOAD`, `SIMULATOR_READ`. Existing plugin confirmation logs
complete the trace. The trimmed fixture has no usable temperature-reference zone,
so its simulated thermostat's current temperature is unavailable; that is unrelated
to percentage testing. Leave the three Simulator AC controls alone in this trial.

Stop-all is the safe shutdown command. Homebridge runs its own SIGINT teardown
inside its process; the simulator closes its own server instance. Neither command kills
a process by PID. A per-run secret and matching component/runtime identity are
required before shutdown. Unmanaged listeners or identity/authentication mismatch
produce an error and are left alone. Do not work around this by killing all Node
processes. Inspect the indicated logs instead. Start failures are reported; use
status and stop for any component that did start.

When stopped, Home will eventually mark test accessories unavailable. Start the
lab later to restore them without re-pairing. Physical Advantage Air firmware
percentage retention is still not established by this simulated environment.
