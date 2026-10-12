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

## Running the existing campaign

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

- All 131 installed plugin files must match the supplied tarball.
- Native and legacy compatibility platforms both load with the current config
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
CI prints evidence and process logs on success or failure. Hosted CI for this
uncommitted MyPlace-lights change remains a post-push merge gate; the extended
passing evidence above is from Codespaces.
