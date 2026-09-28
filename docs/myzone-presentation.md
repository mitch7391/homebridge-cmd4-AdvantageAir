# Legacy MyZone presentation (provisional grouping)

One new `<aircon name> MyZone` accessory contains one Switch service per eligible
temperature-controlled zone, named `<zone name> MyZone`. It does not replace the
zone open/close switches, temperature sensors, thermostat or fans.

HAP supports repeated Switch services with distinct subtypes. Apple Home decides
the tile layout and grouping controls; this is not a native radio-button selector.
The maintainer observed a tile showing "1 On / 1 Off", opening to two side-by-side
switches. Selection and cache restoration have been live-validated.
An aggregate group-On action can submit several selections: the existing backend
coalesces unsent selections and the last accepted selection wins. Prefer the named
zone switches. Aggregate Off cannot disable MyZone and leaves a reference selected.
If that behaviour makes Home confusing, reassess the presentation, not the backend.

## State and selection

- Discover services only when the existing backend planner accepts a zone. This
  requires installer-configured MyZone, `type > 0`, valid unique reported zone
  numbers and a valid zone target. `myZone = 0` never enables this accessory.
- On selects that reference using the existing coordinator; all sibling switches
  immediately reflect its accepted desired selection. There is no new write path.
- Off on the selected switch sends nothing, logs why it was refused, and returns
  true using HAP write-response support. Off on an unselected switch is a no-op.
- Observations, confirmation failures, partial success, expiry and freshness come
  from the backend. A failed target synchronization must not conceal an observed
  reference change. Sensor-health fields are not a replacement for zone type.

## Cache and lifecycle

The accessory UUID derives from the existing stable aircon identity plus `myzone`.
Each service subtype derives from the existing zone identity plus
`myzone-selection`. Existing zone identity includes the zone key; do not infer
identity from the zone's display name or reported selection number.

Cache restoration initially marks saved switches unavailable. Fresh discovery
reattaches the same services. Renaming or changing an aircon address or a zone's
reported number does not recreate them. Existing service names are preserved,
including configured names; newly eligible zones add services to the same accessory.

Missing or ineligible zones leave their cached services unavailable. Disabling
MyZone in controller data retains the accessory unavailable. No automatic service
deletion, migration or pairing reset occurs. Recent cached data during a failed
read follows the existing coordinator freshness policy; stale data cannot admit
new selections. Shutdown makes every attached switch unavailable.

## Simulator validation

Developer tooling only: use the existing isolated lab, never the production bridge.
The new `dev/lab/fixtures/myzone.json` keeps the percentage fixture's controller
and aircon identities and its existing percentage zone. It adds:

| Zone | Reported number | Initial state | Target |
| --- | --- | --- | --- |
| Living Reference (`z01`) | 1, selected | open | 24 C |
| Bedroom Reference (`z02`) | 7 | closed | 22 C |

The simulator's `/load` appends to a queue; it does not replace the active fixture.
The worker loads `percentage.json` on every fresh simulator start. Always `/reInit`
before selecting MyZone. This deliberately discards simulator memory; it preserves
Homebridge storage and pairing. Do not use a reset to test persistence.

**Scenario reset:** from PowerShell in the updated lab repository, with Node on PATH:

```powershell
& {
    $ErrorActionPreference = 'Stop'
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\dev\lab\myzone.ps1 -Action Reset
    if ($LASTEXITCODE -ne 0) { throw 'MyZone reset failed. Stop here.' }
}
```

The execution-policy override applies only to that PowerShell process; it does not
change machine/user policy. Organization-enforced policy may still block execution;
if it does, stop rather than changing permanent policy. Each invocation checks the
child process exit code so later steps cannot continue after a failed script.

This script uses the same `lab.mjs` manager as `lab.cmd`: stop Homebridge only,
start/check the managed simulator, require running status, reset, load MyZone,
verify controller/aircon identities, three zones, selection 1, Bedroom number 7
and identical consecutive control-state reads, then start Homebridge. Each native
exit status is checked and HTTP calls have five-second timeouts. Failed guards
terminate the invocation. The simulator PID is also checked for continuity.
Fail-fast execution does not roll back a lab reset that has already happened.

Preserve `dev/lab/local.json`, the runtime directory, cache, username, PIN and all
pairing files. Do not pair the bridge again. Existing accessories remain; the new
references also have the existing separate zone-switch and sensor presentation.

Completed Apple Home checks (do not repeat solely for this workflow correction):

1. Locate **Simulator AC MyZone**. Record how Home groups the named services and
   whether it offers separate tiles. Living is selected; Bedroom is not. Do not
   confuse these with **Living Reference Zone** / **Bedroom Reference Zone**.
2. Turn Bedroom MyZone On. Living MyZone becomes Off immediately. After confirmation,
   the controller snapshot showed `myZone = 7`, main target 22, Bedroom open. The
   percentage zone remains 40. Power/mode/fan remain off/heat/low.
3. Turn selected Bedroom MyZone Off. It remains selected; the log explains why.
   Then select Living MyZone; selection returns to 1 and main target to 24.
4. Select Bedroom then Living rapidly. Wait for confirmation; Living is the final
   selection. Report whether Home's grouped tile makes individual selection awkward.
5. Stop/start only Homebridge using the commands below. The same accessory/services
   must return in the same room, with Living still selected and no duplicates.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\dev\lab\myzone.ps1 -Action RestartHomebridge
    if ($LASTEXITCODE -ne 0) { throw 'MyZone persistence test failed. Stop here.' }
}
```

**Separate persistence test:** wait for commands to be confirmed before that block.
It never starts, resets or reloads the simulator. It requires the same running
managed simulator across a Homebridge-only restart and compares control state.
A missing/replaced simulator fails the test: its previous memory cannot be recovered
by restarting it. Full `lab.cmd stop/start` reloads the default fixture and is not
a persistence test. Neither procedure deletes cache, storage or pairing data.

`lab.cmd logs` follows `homebridge.log` (stdout) only. Homebridge warnings, including
"MyZone Off refused", are saved in `homebridge-error.log` (stderr) in the same
runtime directory. The stdout follower prints that directory. Inspect the stderr
file there; absence from stdout does not mean a warning was not emitted.

To end a session:

```powershell
& {
    $ErrorActionPreference = 'Stop'
    .\lab.cmd stop
    if ($LASTEXITCODE -ne 0) { throw 'Lab shutdown did not complete.' }
}
```

## Regression checks and validation boundaries

`npm test` includes a real HTTP fixture-queue regression. Loading percentage then
MyZone reproduces the stale first read; reset then MyZone must give three correct
consecutive reads. This check exercises HTTP behaviour, not worker startup.

Explicit managed-lifecycle check, on a machine with free simulator ports:

```bash
node --test test/lab/managedSimulator.test.mjs
```

It invokes the actual `lab.mjs simulator start/status/stop` path with a new temporary
runtime and refuses occupied ports 52025/52026. It checks the worker's default fixture,
reset/load/read sequence and repeated start preserving memory. It starts no Homebridge
bridge. It is outside `npm test` so ordinary tests do not compete with a running lab
for fixed ports. Its small temporary runtime is retained for diagnostics. A spawn
restriction is a blocked check, not a passed lifecycle test.

Operator control-flow check (no real lab is started):

```powershell
& {
    $ErrorActionPreference = 'Stop'
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\lab\myzoneOperator.test.ps1
    if ($LASTEXITCODE -ne 0) { throw 'Operator control-flow checks failed.' }
}
```

This executes the exact operator script with mocked CLI and HTTP boundaries. It
checks missing/starting processes, failed native commands, wrong fixture identity,
unstable reads and the rule that failed preconditions prevent Homebridge startup.
Report it separately from real process-management and Apple Home validation.

`test/api/labStartup.test.mjs` exercises the actual manager with mocked process,
network and clock boundaries. It covers transient control timeouts, the shared
30-second startup deadline, and refusal of unmanaged or mismatched processes.
It runs with the normal test suite; it is not a real Windows startup timing test.

Keep test output visible: run `npm run lint` and `npm test` normally. If also using
`tee` to save a log, enable Bash `pipefail` so test failures are still failures.

Simulator results prove the presentation and software path, not real MyZone
firmware timing or fractional target normalization. The e-zone hardware cannot
validate installer-enabled MyZone. No backend confirmation rule is relaxed here.
