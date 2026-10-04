# Homebridge Advantage Air

Native Homebridge integration for Advantage Air air conditioning. v4 discovers
the existing legacy accessory layout from your controller; new native users do
not need Cmd4, Bash, curl, jq or the old configuration creator.

**v4 is still in development. This branch is not a published npm beta.**
Publishing remains disabled. Do not install a raw GitHub checkout and expect a
ready-built plugin; the supported installation path being prepared is a built
npm package.

## Existing v3 users: read this first

See [Migrating from v3](docs/v3-migration.md) before upgrading. The package
temporarily retains the unchanged root-level `AdvAir.sh` backend for existing
Cmd4 accessories and accepts the old `cmd4AdvantageAir` helper-platform entry.
It does not convert accessories or restore the old setup UI.

Temporary side-by-side use is intended for migration/comparison, not permanent
dual operation. Avoid simultaneous conflicting commands. Legacy Timer polling
can write to the controller; follow the timer precautions in the migration guide.

## Native v4 setup

Once an npm beta has been explicitly published, install its exact
`4.0.0-beta.x` version using Homebridge UI's alternate-version option, or the
npm `beta` tag. Do not assume the normal `latest` tag selects v4.
The package name remains `homebridge-cmd4-advantageair`.

For a maintainer trial before publication, use the built, validated tarball
and the existing isolated test environment. Do not enable npm publishing just
to test installation.

1. Open this plugin's settings and add your controller's IPv4 address.
2. Leave the controller API port at 2025 unless your installation uses another
   port. Reserve the controller address in your router.
3. Save and restart the plugin/Homebridge as prompted. Homebridge owns child
   bridge settings, pairing and network ports; they are not plugin options.
4. Pair the bridge if necessary and arrange the discovered accessories in Home.

Minimal native platform configuration:

```json
{
  "platform": "AdvantageAir",
  "name": "Homebridge Advantage Air",
  "devices": [
    {
      "ipAddress": "192.168.1.100"
    }
  ]
}
```

Controller `name` is an optional log label, falling back to `Controller 1`,
`Controller 2`, etc. It does not rename Home accessories: their initial names
come from the controller's aircon and zone names.

## Existing legacy layout

- Thermostat with linked fan-speed service, plus separate Ventilation and Dry fans.
- Separate zone Switch and TemperatureSensor accessories for temperature zones.
- Lightbulb On/Brightness control for percentage zones (`type === 0`).
- Grouped MyZone switches only on installer-enabled MyZone systems.
- Native Timer Valve using the controller's countdown, with a saved duration.

The Timer is named `<aircon name> Timer`. During testing, Siri reliably handled
“Turn on AC Timer” and “Turn off AC Timer”. Select durations in Apple Home:
duration-setting Siri phrases were unreliable and could invoke Clock instead.
Siri behaviour can vary across versions.

MyPlace lights/Things and alternative accessory layouts are not implemented in
native v4. Do not assume the complete historical v3 feature set has migrated.

## Currently validated environment and limitations

The maintainer's hardware campaign used Homebridge 2.4.0 and Node 24.21.0.
Automated CI covers Node 22 and 24 with the locked Homebridge 2.x dependency.
These describe the currently validated environment, **not a final beta support
matrix**. Homebridge 1.x compatibility and Node 26 support remain separate
validation work; the existing package engine declaration is not evidence of
completed testing on every permitted combination.

Upgrade from Node 18/20 before migrating to v4. Use a current supported Node
22/24 version compatible with your Homebridge, OS and other plugins.

Hardware evidence is primarily from the maintainer's e-zone system.
MyZone and percentage-zone Apple Home validation used the simulator; broader
hardware compatibility remains to be established. An all-percentage system
without a healthy temperature reference can expose unavailable thermostat
temperature information. The legacy linked fan-speed service remains On
independently of AC power.

The native Timer accepts whole minutes from 1 to 720; Apple Home's fresh
Generic Valve picker showed a 5-minute floor in testing. Missing controller
data retains accessories rather than deleting them. Controller replacement,
zone-key changes and genuine layout changes are not automatic migrations.

One immediate tablet-to-Home overlapping command timed out after valid
preflight and one write. It was not reproduced in three controlled repeats.
Its cause remains undetermined; recurrence should be investigated separately.

## Accessory Information

Native accessories report Advantage Air as Manufacturer and the controller's
valid `system.sysType` as Model, exactly as reported (for example e-zone or
MyAir5). A missing, empty or invalid model leaves existing metadata intact;
before any valid model is received, Homebridge's default remains.

Serial Number is `AA-` followed by the existing accessory UUID without hyphens.
It identifies the virtual accessory without exposing raw controller identifiers.
Firmware Revision is the installed plugin package version, not a controller
component's firmware revision. Name follows the existing accessory display name.
Linked fan-speed and grouped MyZone services share their parent's information.

Metadata is refreshed from valid discovery data without changing accessory
UUIDs, services, saved Timer duration or pairing. No additional controller
requests are made. Apple Home may cache or choose not to display some fields.

## Logs and diagnostics

Normal logs show startup, first data, accessory creation, commands being sent,
failures and recovery. Confirmations, no-op results, read summaries and sanitised
HTTP timing are debug messages. To capture detailed controller diagnostics,
enable that controller's `debug` option **and** Homebridge debug logging.

Do not post raw controller responses: they may contain identifiers, location
data, notification tokens or PINs.

## Development and release gates

Use `npm ci`, `npm run lint`, `npm run build` and `npm test`.
Build before `npm pack`; package validation must inspect the resulting tarball,
including the executable root `AdvAir.sh`. The simulator is maintainer tooling:
see [the developer lab guide](docs/developer-lab.md).

Before the first actual npm beta publication:

- **Release blocker: deliberately reconcile `package.json`'s Apache-2.0 licence
  declaration with the repository MIT licence and retained Apache-2.0 template
  material. This PR does not resolve that mismatch.**
- Complete the real Homebridge UI/configuration and packaged migration checks.
- Record the supported version combinations and remaining hardware limitations.
- Address the previously identified dev-only dependency advisory separately.
- Explicitly authorise publication, choose an unused beta version and publish
  under `beta`, preserving the v3 `latest` tag.

`private: true`, versioning, engine ranges and dependencies remain unchanged
in the migration-compatibility increment.

## History and attribution

The historical Cmd4 setup is documented in [README-v3.md](README-v3.md).
Project acknowledgements and credits remain in that file and CHANGELOG.md.

The frozen legacy backend comes from v3 commit
`d65be40f736e4814c261c1470275f2405df20c94`.
The MIT LICENSE and the Homebridge template's LICENSE.homebridge-template
and TEMPLATE_SOURCE.txt are retained.
