# Homebridge 1.8.5 / Node 22 package campaign

Status: passed in Linux Codespaces with Node 22.23.3, Homebridge 1.8.5
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

Run `npm run check:package` using Node 22 first. Then, in the Linux Codespaces
terminal, run `npm run check:homebridge1 -- /absolute/path/to/the/validated.tgz`.
The campaign refuses other Node majors and non-Linux hosts. It installs exactly
Homebridge 1.8.5 and the tarball into a new directory under the system temp folder.
It never links the repository plugin or its Homebridge 2.x development dependency.
Registry access and the normal repository development dependencies are required.

The runner starts the loopback lab simulator with the existing MyZone
fixture and starts the actual Homebridge CLI with isolated storage/configuration.
The disposable unpaired bridge permits local HAP HTTP requests for testing only.
Both controller and HAP traffic stay on 127.0.0.1. No RPi or existing Homebridge
storage is used. Do not pair the temporary bridge to Apple Home.

Coverage:

- All 119 installed plugin files must match the supplied tarball.
- Native and legacy compatibility platforms both load with the current config
  shape. The packaged schema is present and retains the native alias/Home Name.
  Homebridge core does not render the settings schema; this is not a new UI-renderer
  claim and does not replace or repeat previously completed UI acceptance.
- Discover ten native accessories: Thermostat with linked FanSpeed, Ventilation,
  Dry, Timer, grouped MyZone, two temperature-zone Switches, two TemperatureSensors
  and one percentage-zone Lightbulb.
- Read temperatures; write thermostat Heat and target temperature, linked fan
  speed, zone On, percentage Brightness/Off, Ventilation/Dry On, Timer
  duration/activation/cancellation, and MyZone selection.
- Confirm controller state from the simulator after writes rather than treating
  HAP's immediate write acknowledgement as command confirmation.
- Gracefully stop/restart Homebridge; compare cached UUIDs, service UUID/subtypes,
  HAP accessory/instance identifiers, accessory count and saved Timer duration.
  No Apple Home pairing is performed or claimed by this unpaired campaign.

The printed evidence directory retains the tarball manifest, package/install,
simulator and Homebridge logs, cache/storage and `evidence.json`, including exact
Node/Homebridge/plugin versions, tarball SHA-256 and individual passed checks.
The runner stops only child processes it started. On failure retain that directory
for diagnosis; distinguish environment/harness failures from plugin incompatibility.
Do not change the runtime implementation solely to get this test to pass.

A separate CI job pins Node 22.23.3 and runs this same package-based
Homebridge 1.8.5 campaign. The existing Node 22/24 job is unchanged.
CI prints evidence and process logs on success or failure. Its first hosted run
remains pending; the passing evidence above is from Codespaces.
