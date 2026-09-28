# Legacy MyZone presentation (provisional grouping)

One new `<aircon name> MyZone` accessory contains one Switch service per eligible
temperature-controlled zone, named `<zone name> MyZone`. It does not replace the
zone open/close switches, temperature sensors, thermostat or fans.

HAP supports repeated Switch services with distinct subtypes. Apple Home decides
the tile layout and grouping controls; this is not a native radio-button selector.
The grouping is provisional until the maintainer validates it in Apple Home.
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

The existing simulator already supports the three backend writes. Its source and
the lab worker are unchanged. Full simulator restarts still load `percentage.json`
by default. Loading this fixture changes simulator memory, not the source fixture
or Homebridge storage. Homebridge-only restarts retain the simulated selection.

From PowerShell in the updated lab repository, with the usual paired runtime:

```powershell
.\lab.cmd stop
if ($LASTEXITCODE -ne 0) { throw 'Lab did not stop.' }
.\lab.cmd simulator start
if ($LASTEXITCODE -ne 0) { throw 'Simulator did not start.' }
$fixturePath = (Resolve-Path -LiteralPath 'dev/lab/fixtures/myzone.json').Path
$loadUrl = 'http://127.0.0.1:52025/?load=' + [uri]::EscapeDataString($fixturePath)
Invoke-WebRequest -Uri $loadUrl -UseBasicParsing | Out-Null
$snapshot = Invoke-RestMethod -Uri 'http://127.0.0.1:52025/getSystemData'
if ($snapshot.aircons.ac1.info.myZone -ne 1 -or $snapshot.aircons.ac1.zones.z02.number -ne 7) {
  throw 'MyZone fixture was not loaded; do not start Homebridge.'
}
.\lab.cmd homebridge start
if ($LASTEXITCODE -ne 0) { throw 'Homebridge did not start.' }
.\lab.cmd status
```

Preserve `dev/lab/local.json`, the runtime directory, cache, username, PIN and all
pairing files. Do not pair the bridge again. Existing accessories remain; the new
references also have the existing separate zone-switch and sensor presentation.

Minimum Apple Home checks:

1. Locate **Simulator AC MyZone**. Record how Home groups the named services and
   whether it offers separate tiles. Living is selected; Bedroom is not. Do not
   confuse these with **Living Reference Zone** / **Bedroom Reference Zone**.
2. Turn Bedroom MyZone On. Living MyZone becomes Off immediately. After confirmation,
   inspect the snapshot below: `myZone = 7`, main target 22, Bedroom open. The
   percentage zone remains 40. Power/mode/fan remain off/heat/low.
3. Turn selected Bedroom MyZone Off. It remains selected; the log explains why.
   Then select Living MyZone; selection returns to 1 and main target to 24.
4. Select Bedroom then Living rapidly. Wait for confirmation; Living is the final
   selection. Report whether Home's grouped tile makes individual selection awkward.
5. Stop/start only Homebridge using the commands below. The same accessory/services
   must return in the same room, with Living still selected and no duplicates.

```powershell
$snapshot = Invoke-RestMethod -Uri 'http://127.0.0.1:52025/getSystemData'
$snapshot.aircons.ac1.info | Select-Object myZone, setTemp, state, mode, fan
$snapshot.aircons.ac1.zones.z02 | Select-Object number, state, setTemp
$snapshot.aircons.ac1.zones.z06 | Select-Object state, value

.\lab.cmd homebridge stop
if ($LASTEXITCODE -ne 0) { throw 'Homebridge did not stop.' }
.\lab.cmd homebridge start
if ($LASTEXITCODE -ne 0) { throw 'Homebridge did not restart.' }
```

Use `lab.cmd logs` for Homebridge logs. End with `lab.cmd stop`; leave all pairing
and storage intact. The fixture resets on a later simulator start; reload it before
Homebridge starts when continuing MyZone testing. The original percentage fixture
and existing test bridge remain available.

Simulator results prove the presentation and software path, not real MyZone
firmware timing or fractional target normalization. The e-zone hardware cannot
validate installer-enabled MyZone. No backend confirmation rule is relaxed here.
