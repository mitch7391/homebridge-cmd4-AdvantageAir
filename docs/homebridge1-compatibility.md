# Homebridge 1.8.5 / Node 22 package campaign

Original AC-only campaign: passed in Linux Codespaces with Node 22.23.3, Homebridge 1.8.5
and the actual packed plugin 4.0.0-beta.1.
Archive SHA-256: `9012f2ce3ca72727ca7066c5ce4985c87866b8887c89344e38886de73ee26c19`.

All seven campaign checks passed: installation/file integrity, native and legacy
platform startup, representative supported-control reads/writes, and clean
restart with the same ten accessory UUIDs, service identities, HAP AIDs/IIDs
and retained 45-minute Timer duration.

Two tooling defects were corrected: the simulator reassigned a const variable,
and harness On-read assertions expected true rather than accepting true or 1.
No plugin runtime fix was necessary. Existing Homebridge 2.4.0 acceptance remains
valid. This proves 1.8.5 compatibility, not every allowed patch or 1.8.0 itself.

## MyPlace-lights package evidence

The extended campaign passed with the same 131-file Linux tarball on both
Homebridge 2.4.0 / Node 24.21.0 and Homebridge 1.8.5 / Node 22.23.3.
Archive SHA-256: `e61b0e00312e74351328005aef1f0b3a09d68ee64e68730a4a1a14f71566f306`.
The package-content check and stored `AdvAir.sh` mode 0755 passed.

All nine extended checks passed, including relay/dimmer writes, external light
updates via normal polling, graceful shutdown/restart, unchanged twelve UUIDs,
service identities and HAP AIDs/IIDs, no duplicate accessories, retained dimmer
state/value and the saved 45-minute Timer duration. Harness corrections covered
CRLF archive listings, waiting for command confirmation before an external edit,
and sorting the accessory comparison by AID; identity checks remain intact.
No plugin runtime fix was required by the Linux campaign. This is simulator/HAP
evidence, not physical MyPlace light or every-firmware acceptance.

## Standalone package evidence

The focused standalone campaign passed on Windows with Node 24.19.0,
Homebridge 2.4.0 and genuine v3 `homebridge-cmd4-advantageair@3.12.2` installed
beside the native 128-file package. Archive SHA-256:
`90de79002d02577fd09261e527e49fab49c776aec7edea0917b4e5a6d8c66a22`.
Both platforms registered independently. All twelve native accessories survived
ordinary restart and an offline old-owner-to-new-owner cache transition with
unchanged UUIDs, service identities, HAP AIDs/IIDs and 45-minute Timer duration.
Temperature reads and the Timer-duration write passed; established controller
control campaigns were not repeated for this package-identity change.

Windows process termination initially bypassed graceful teardown. The disposable
harness now invokes Homebridge's actual SIGTERM handler over IPC on Windows;
Linux still sends SIGTERM normally. All three Homebridge shutdowns then passed.
No plugin runtime correction was required. This does not test real Apple Home
pairing, rooms or automations.

The same 128-file archive subsequently passed the focused Linux campaigns on
Homebridge 2.4.0 / Node 24.21.0 (npm 11.19.0) and Homebridge 1.8.5 /
Node 22.23.3 (npm 10.9.9), with genuine v3 3.12.2 installed. Both verified twelve
native accessories, distinct registrations, graceful shutdown/restart and offline
cache-owner migration with unchanged UUIDs/service subtypes/HAP AIDs/IIDs and
45-minute Timer duration. The q deprecation notice was non-fatal.
The new release-preparation package adds tester guidance and metadata safeguards;
its inventory is validated separately without repeating this full runtime campaign.

## Running the existing campaign

The evidence above predates the standalone npm rename and remains historical
functional evidence, not a claim that the renamed package was already tested.
The current harness installs genuine `homebridge-cmd4-advantageair@3.12.2`
alongside `homebridge-advantageair`, with unqualified legacy/native platform
configuration, and verifies distinct registration ownership. After an ordinary
restart it also reconstructs old native cache ownership, applies the offline
helper and verifies another restart without identity or saved-state loss.
Append `--standalone` after the explicit Homebridge version for focused
startup/read/Timer-duration/restart/ownership-transition coverage without
repeating the established control-write campaign. No real pairing is exercised.

Run `npm run check:package` using Node 22 first. Then, in the Linux Codespaces
terminal, run `npm run check:homebridge1 -- /absolute/path/to/the/validated.tgz`.
The default Homebridge 1.8.5 campaign requires Node 22 and Linux. To select the
established Homebridge 2.4.0 campaign, use the same command with `2.4.0` after
the archive path, under supported Node 22 or 24. It installs the selected exact
Homebridge version and tarball into a new directory under the system temp folder.
It never links the repository plugin or its Homebridge 2.x development dependency.
Registry access and the normal repository development dependencies are required.

The runner starts the loopback lab simulator with the existing MyZone
fixture with one relay and one dimmer overlaid, and starts the actual Homebridge CLI with isolated storage/configuration.
The disposable unpaired bridge permits local HAP HTTP requests for testing only.
Both controller and HAP traffic stay on 127.0.0.1. No RPi or existing Homebridge
storage is used. Do not pair the temporary bridge to Apple Home.

Coverage:

- The complete native inventory, derived from the clean build and explicit
  allowlist, must match the supplied tarball and installed files; the
  shell backend and inert compatibility handler must be absent.
- V3's legacy platform and v4's native platform both load with the current config
  shape. The packaged schema is present and retains the native alias/Home Name.
  Homebridge core does not render the settings schema; this is not a new UI-renderer
  claim and does not replace or repeat previously completed UI acceptance.
- Discover twelve native accessories: Thermostat with linked FanSpeed, Ventilation,
  Dry, Timer, grouped MyZone, two temperature-zone Switches, two TemperatureSensors,
  one percentage-zone Lightbulb, one relay light and one dimmable light.
- Read temperatures; write thermostat Heat and target temperature, linked fan
  speed, zone On, percentage Brightness/Off, Ventilation/Dry On, Timer
  duration/activation/cancellation, MyZone selection, relay On/Off and dimmer
  On/Brightness; verify external light changes arrive through normal polling.
- Confirm controller state from the simulator after writes rather than treating
  HAP's immediate write acknowledgement as command confirmation.
- Gracefully stop/restart Homebridge; compare cached UUIDs, service UUID/subtypes,
  HAP accessory/instance identifiers, accessory count, saved Timer duration and
  retained dimmer state/value.
  No Apple Home pairing is performed or claimed by this unpaired campaign.

The printed evidence directory retains the tarball manifest, package/install,
simulator and Homebridge logs, cache/storage and `evidence.json`, including exact
Node/Homebridge/plugin versions, tarball SHA-256 and individual passed checks.
The runner stops only child processes it started. On failure retain that directory
for diagnosis; distinguish environment/harness failures from plugin incompatibility.
Do not change the runtime implementation solely to get this test to pass.

A separate CI job pins Node 22.23.3 and runs this same package-based
Homebridge 1.8.5 campaign. The existing Node 22/24 job is unchanged.
CI prints evidence and process logs on success or failure. The final release
preparation commit still requires green hosted CI. Historical MyPlace and
standalone Linux evidence above came from Codespaces; it does not claim a
release-preparation compatibility rerun.
