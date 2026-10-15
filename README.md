# Homebridge Advantage Air

Native Homebridge integration for Advantage Air air conditioning and individual
MyPlace lights. v4 discovers
the existing legacy accessory layout from your controller; new native users do
not need Cmd4, Bash, curl, jq or the old configuration creator.

**Beta 1 candidate: publication is a separate maintainer action.**
Publishing remains disabled. Do not install a raw GitHub checkout and expect a
ready-built plugin; the supported installation path being prepared is a built
npm package.

## Existing v3 users: read this first

See [Migrating from v3](docs/v3-migration.md) before adding native v4.
`homebridge-cmd4-advantageair` remains independently installed for Cmd4, with
its own `AdvAir.sh` and `cmd4AdvantageAir` registration. Native
`homebridge-advantageair` registers only `AdvantageAir` and bundles no backend.
Existing native development users must instead follow the
[stopped-service cache-owner transition](docs/native-package-transition.md).

Temporary side-by-side use is intended for migration/comparison, not permanent
dual operation. Avoid simultaneous conflicting commands. Legacy Timer polling
can write to the controller; follow the timer precautions in the migration guide.

## Native v4 setup

After publication, install `homebridge-advantageair@4.0.0-beta.1` using your
Homebridge installation's supported explicit-package/version workflow. Use the
Homebridge UI beta/alternate-version option if offered for the new package, or
the host-specific npm procedure in the tester guide. Do not rely on discovery
or an unqualified package install finding a beta-only first release.
Install `homebridge-advantageair` independently; do not upgrade or replace v3.
`homebridge-cmd4-advantageair@latest` remains the independent stable package.
Prefer the exact announced beta version for reproducibility.
See [Beta 1 installation, rollback and reporting](docs/beta1-testing.md).

For a maintainer trial before publication, use the built, validated tarball
and the existing isolated test environment. Do not enable npm publishing just
to test installation.

1. Open this plugin's settings and add your controller's IPv4 address and Home
   base **Name** (default `Aircon`). Give each controller a distinct Name.
2. Leave the controller API port at 2025 unless your installation uses another
   port, such as 10211 for Fujitsu anywAIR. Reserve the controller address in your router.
3. Save and restart the plugin/Homebridge as prompted. Homebridge owns child
   bridge settings, pairing and network ports; they are not plugin options.
4. Pair the bridge if necessary and arrange the discovered accessories in Home.

In the **Homebridge web UI configuration editor**, use this native platform
configuration (substitute your controller address):

```json
{
  "platform": "AdvantageAir",
  "name": "Homebridge Advantage Air",
  "devices": [
    {
      "homeName": "Aircon",
      "ipAddress": "192.168.1.100"
    }
  ]
}
```

The visible **Name** is saved as `devices[].homeName`. Missing or blank values
resolve to `Aircon`; explicit values are trimmed. Aircons are numbered within
each controller in natural key order (ac1, ac2, ...): `Aircon`, `Aircon 2`,
`Aircon 3`, or `Downstairs Aircon`, `Downstairs Aircon 2`, etc. Numbering starts
over for each controller. Related Timer, Fan, Dry Mode, FanSpeed and MyZone
names follow their aircon base. Zone names remain controller-supplied.

Resolved aircon base names must be unique across the platform, ignoring case
and surrounding whitespace. For example, a controller named `Aircon 2`
conflicts with the second aircon on a controller named `Aircon`. The complete
discovered set is checked before any rename; conflicts are logged and retain
previously accepted accessory names and operation. No extra suffix is invented.
On startup, renames and new aircon-related accessories wait until every valid
configured controller has supplied a usable discovery inventory. Cached
accessories can reconnect under their previous names during that wait.

Changing Name does not change UUIDs, pairing, services or saved Timer duration.
Apple Home may retain names customised there. Existing development accessories
previously named from controller data (for example AC) now adopt this Name.

The existing platform `name` and controller `devices[].name` remain hidden log
labels and are preserved on settings saves. They are not Home naming inputs.
Controller log labels still default to Controller 1, Controller 2, etc.
The standard settings form uses controller tabs; all child-bridge controls
remain Homebridge-owned.

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

Individual MyPlace lights are discovered automatically by controller/light ID.
Relay lights expose On; dimmers expose On and Brightness. No manual light
entries are needed. Optional per-controller excludedLightIds excludes IDs,
not names. Groups, scenes, gates, garage doors, blinds, windows, other Things
and zone-thermostat redesign are outside Beta 1.

Light brightness is intentionally 0–100% in 1% steps without a 10% clamp.
Normal Off uses the separate state command. Hardware validation below 10%
remains for beta testers; see the test guide.

## Currently validated environment and limitations

The maintainer's hardware campaign used Homebridge 2.4.0 and Node 24.21.0.
Automated CI covers Node 22 and 24 with the locked Homebridge 2.x dependency.
The packaged plugin also passed Homebridge 1.8.5 with Node 22.23.3 startup,
controls and cache restoration. CI preserves that exact compatibility job.
Declared ranges are Node ^22.10.0 or ^24.0.0 and Homebridge ^1.8.0 or ^2.0.0;
these results do not test every allowed patch. Node 26 is outside the beta range.

Upgrade from Node 18/20 before migrating to v4. Use a current supported Node
22/24 version compatible with your Homebridge, OS and other plugins.

Hardware evidence is primarily from the maintainer's e-zone system.
MyZone and percentage-zone Apple Home validation used the simulator; broader
hardware compatibility remains to be established. On explicitly sensorless,
all-percentage systems, thermostat CurrentTemperature displays the observed
AC setpoint, as in v3: it is not a measured room temperature. Sensor-equipped
systems retain measured readings and report reference-sensor faults rather
than substituting a target. The linked fan-speed service remains On independently
of AC power.

Dry is a separate Fan accessory, deliberately not thermostat Auto. Select another
MyZone before closing its active zone. V4 does not automatically reassign MyZone
or force another room open. Constant-zone protection remains with the controller's
installer-configured safeguards as documented by Advantage Air. Do not alter
those settings to test this plugin.

Standalone MyPlace with explicit aircons: {} is supported; payloads omitting
that object remain unproven. Large light installations have bounded queue
protection (64 pending intentions, 30-second expiry), not guaranteed completion
of a whole-house scene. Physical light behaviour and Siri targeting need beta evidence.

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
HTTP timing are selected detailed diagnostics, marked `[Debug]` in the log. To capture detailed controller diagnostics,
enable that controller's Detailed debug logging option **or** the platform-wide
Detailed debug logging for all controllers option. Homebridge/child-bridge Debug
Mode (`-D`) is not required. Selected diagnostics use the normal visible log
channel; Homebridge `-D` alone does not enable them. With both plugin options
off, these controller diagnostics are suppressed. Effective selection is `platform.debug === true || device.debug === true`.
Turning the global option off and saving/restarting restores the saved individual
selections; it never clears or rewrites those selections.

Do not post raw controller responses: they may contain identifiers, location
data, notification tokens or PINs.

## Development and release gates

Use `npm ci`, `npm run lint`, `npm run build` and `npm test`.
`npm pack` now cleans and builds through `prepack`. Run `npm run check:package`
to verify the actual tarball, native entry point, tester/migration guides and
absence of the legacy backend/registration. The simulator is maintainer tooling:
see [the developer lab guide](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/blob/v4-beta/docs/developer-lab.md).

Before the first actual npm beta publication:

- Package metadata uses MIT, matching the project licence and historical v3
  releases. The separate Apache-2.0 template licence and attribution remain
  included. See [package readiness](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/blob/v4-beta/docs/package-readiness.md) for release gates.
- Preserve completed functional acceptance; require green final CI and release
  package checks. Existing native-development transitions additionally need a
  backed-up Apple Home pairing/room/automation check on the actual installation.
- Record the supported version combinations and remaining hardware limitations.
- Review production and development audits separately; dev-only findings are not
  automatically runtime beta blockers.
- Explicitly authorise publication, choose an unused beta version and publish
  under `beta`, preserving the v3 `latest` tag.

`private: true` still disables publication. Beta-only defaults and a prepublish
guard are prepared; neither authorises publication. See the
[maintainer procedure](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/blob/v4-beta/docs/beta-publication.md).

## History and attribution

The historical Cmd4 setup is documented in [README-v3.md](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/blob/v4-beta/README-v3.md).
Project acknowledgements and credits remain in that file and the
[changelog](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/blob/v4-beta/CHANGELOG.md).

The repository-only historical backend (excluded from native npm) comes from v3 commit
`d65be40f736e4814c261c1470275f2405df20c94`.
The MIT LICENSE and the Homebridge template's LICENSE.homebridge-template
and TEMPLATE_SOURCE.txt are retained.
