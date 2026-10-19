# Beta 1: opt-in installation and hardware feedback

This guide covers installation and hardware feedback for 4.0.0-beta.1.
Check the maintainer's release announcement for the currently available version.
Stable v3 is homebridge-cmd4-advantageair@latest; native v4 is a separate
homebridge-advantageair package. During the initial public beta programme its
latest and beta tags intentionally identify the same approved prerelease.
Latest is a default installation target, not a stability guarantee. This software
is under active development; bugs and incomplete hardware qualification remain.
Do not install an unbuilt GitHub branch.

## Before installing — Homebridge web UI

1. Download a full Homebridge backup including configuration, accessories and
   pairing/storage. Keep it outside the Homebridge host. Record plugin, Cmd4,
   Homebridge, Node and OS versions and the exact installed package source.
2. Save custom legacy scripts and record their paths. Keep existing Cmd4 entries,
   dependencies, bridge identity and pairing data. A backup is not complete until
   you know how to restore it using your installation's supported procedure.
3. Check Node/Homebridge compatibility and other plugins before changing Node.
   Do not combine a platform upgrade with first beta testing if avoidable.
4. Cancel active legacy timers and disable legacy timer polling during native
   Timer testing. File-backed timer state may survive disabling Cmd4.
5. Keep the working controller tablet/app available for normal recovery.

## Install deliberately — Homebridge web UI

After publication, add **homebridge-advantageair**, selecting exactly 4.0.0-beta.1
(or the precise announced version). Do not select the v3 package's update action.
Once the maintainer has verified and separately promoted latest, normal UI
installation should resolve the announced beta. Search by exact package name;
alternate-version selection allows an explicit version. Discovery/indexing and
the installed UI version still require a post-publication check. During the
short beta-only verification interval normal install/update discovery may fail;
wait for the announcement rather than changing registry tags yourself.

If the UI cannot select the new package, use your host's supported npm install
workflow with the explicit specifier homebridge-advantageair@4.0.0-beta.1. For a
standard global npm-managed Homebridge installation only, the command below
targets that same prefix. UI/container/local-prefix installations must use their
documented package-management route; do not mix locations or add sudo blindly.

**Run in the Homebridge host terminal, only for the global npm-managed case,
after publication and backup:**

```sh
npm install -g homebridge-advantageair@4.0.0-beta.1
```

Both latest and beta can move after separate release approval. Normal updates
may offer subsequent beta versions; inspect release notes and preserve backups.
Use the exact announced version for repeatable trials. Preserve the
separately installed v3 package and its existing AdvAir.sh path. Native v4 does
not supply that script and requires neither Cmd4 nor its shell dependencies.

**Existing native development installs under the old package name:** do not
follow the fresh-install path below or pair a replacement bridge. First follow
[the offline cache-owner transition](native-package-transition.md), stopping
Homebridge/children and retaining backups, bridge settings, persist and caches.
Disposable cache tests do not prove real Home pairing, rooms or automations.
Ordinary v3 users must not apply that helper to their Cmd4 cache records.

Add a separate native AdvantageAir platform and controller address through the
plugin settings. Preserve the old Cmd4 configuration. Pair a new child bridge
only when required; never copy another bridge's identity or clear caches to
make the new accessories appear. Native accessories have new identities.
Follow [the migration guide](v3-migration.md) to transfer your Home arrangement
manually while retaining the old accessories as a reference.

## Supported scope and evidence

- Native legacy AC layout: Off/Heat/Cool thermostat, linked FanSpeed, separate
  Ventilation and Dry fans, temperature-zone Switch + TemperatureSensor,
  percentage-zone Lightbulb, MyZone selection and native countdown Timer.
- Individual MyPlace relay and dimmer lights; automatic ID-based discovery and
  optional excludedLightIds. Explicit empty aircons is supported for standalone
  MyPlace. Omitted aircons has no real-device evidence and is rejected.
- Historical packaged control campaigns passed those supported versions. The
  standalone 128-file package then passed Linux Homebridge 2.4.0 / Node 24.21.0
  and Homebridge 1.8.5 / Node 22.23.3 coexistence, restart and cache-owner migration
  with genuine v3 3.12.2; twelve native accessory identities and Timer duration survived. Node 22/24 CI
  remains required for the final release commit; Node 26 is excluded.
- Hardware evidence is mainly the maintainer's e-zone AC. MyZone, percentage
  zones and MyPlace lights have simulator/HAP coverage; four simulated lights
  also passed manual Apple Home checks. Physical MyPlace lights remain a beta
  tester responsibility. Sensorless HAP tests do not prove every physical system.

## Hardware feedback

For each trial record the exact plugin/Homebridge/Node version, controller model
and firmware, sensor layout and whether Cmd4/native operation overlapped. Use
one command at a time first. Report requested value, controller/app readback,
physical response and elapsed time separately; an accepted HomeKit write is
not a guarantee of completed physical action.

- Sensorless: current temperature should equal the observed AC setpoint, not
  ambient temperature. Check Heat/Cool/Off, a target change, fan and a percentage
  zone while retaining the installer's normal safe airflow configuration.
- Sensor-equipped: compare the selected MyZone/constant sensor with the tablet.
  Real sensor faults must remain visible; do not create faults deliberately.
- MyZone: verify open/select/target order and refusal to close the active zone.
  Select another reference zone explicitly before closing it.
- Lights: relay On/Off; dimmer On/Off and brightness; external tablet updates;
  retained brightness while off; restart without duplicate accessories.
- On a real dimmer try 1%, 5%, 9%, 10% and 11%. For each record requested HomeKit
  value, physical response and subsequent getSystemData brightness: accepted,
  clamped, quantised or rejected. The older API notes say 10–100; Beta 1 deliberately
  keeps 0–100 / minStep 1, without clamping or 5%/10% rounding. Test 0 separately;
  normal Off must use state:off, not an assumption that value:0 is equivalent.
- Timer: check native duration, start/cancel and countdown readback with legacy
  Timer polling disabled. Apple Home's picker may impose its own minimum.
- Large homes: collect whole-house scene/Siri outcomes. The 98-output stress
  result proves safe bounding, not eventual completion beyond the 64-pending,
  30-second-expiry queue. Do not assume every light changed without readback.

Controller-managed constant zones are documented, but simulator tests do not
prove pressure relief or response timing on a particular firmware. Preserve
installer settings. Any minimum-airflow verification needs installer/manufacturer
confirmation or a qualified supervised procedure; do not deliberately close all
outlets on a running system to test this beta. Report existing observations of
controller overrides with model/firmware and readback, not guessed guarantees.

## Reporting — GitHub issue form

State native v4 or legacy Cmd4 (or both). Include reproduction steps, expected
and observed outcomes, exact versions, and sanitised debug logs around one
failure. Plugin Detailed debug logging does not require Homebridge -D.
For light issues include relay/dimmer capability and sanitised ID/readback; for
AC include sensor/percentage layout and selected MyZone/constant information.
Remove addresses, controller UIDs, names, locations, PINs and notification tokens.
Do not post full raw controller dumps or Homebridge backups publicly.

Known limits include Things/gates/doors/blinds/windows, groups/scenes, alternative
zone thermostats, mode-specific file timers and automatic Home arrangement
migration. Siri may confuse linked fan-speed requests with other Fan services;
this is not evidence of a failed controller transport. Node 26 and plugin-card
registry presentation remain separate follow-up work.

## Rollback — Homebridge web UI

Stop native control and disable the native platform/child bridge before restoring
exclusive Cmd4 operation. Preserve its storage if you may resume the beta later.
Allow in-flight activity to settle and check old file-backed timer state before
reactivating Cmd4. The independently installed v3 backend continues serving Cmd4. Native v4
rollback does not require downgrading one package into the other.

For ordinary v3 users, disable/remove the separate native platform and, if desired,
uninstall only homebridge-advantageair using the same package manager. Keep v3
and Cmd4 at the recorded versions and paths. For existing native development
users rolling back the identity transition, restore the matching old native
package, configuration and pre-transition cache together while stopped; follow
the dedicated transition guide rather than installing v3 in place of native v4.
Restore the saved configuration
and pairing/storage through the supported backup procedure if required. Never
clear shared caches, delete pairing, or restore another bridge's identity as a
shortcut. Recheck the legacy state_cmd path and dependencies. Keep both the
pre-beta backup and any later Home arrangement changes until rollback is accepted.
