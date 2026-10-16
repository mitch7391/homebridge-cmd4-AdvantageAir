# MyPlace light fixtures

The light collections derive from the historical v3 repository at
`d65be40f736e4814c261c1470275f2405df20c94`:

- `lights-small.json`: `test/testData/myAirDataWith3noSensors.txt`, four dimmers.
- `lights-large.json`: `test/testData/myPlaceFull.txt`, 98 outputs: 49 relay-only
  outputs and 49 dimmers. Original state/value/relay presence is retained.

Names and IDs are replaced with deterministic generic values. Only light entry
structure and capability/state combinations are retained. Groups/scenes/Things,
location, IP, account/device IDs and other unrelated private fields are removed.
These files are not verbatim captures. Their minimal system envelopes and empty
`aircons` objects are **synthetic**, testing the legitimate no-AC architecture;
they are not evidence of the wire shape of a standalone MyPlace controller.
The original populated captures both contained AC and Things.

Combined AC/light lab tests overlay these sanitised collections on the existing
MyZone fixture. Delayed, incomplete, busy and malformed observations in tests
are deliberately synthetic failure cases, not claims about captured firmware.

`myplace-extras.json` is the four-output interactive lab profile: two relay
patterns from `lights-large.json` and two dimmer patterns from `lights-small.json`.
Names, IDs, initial states and dimmer levels are synthetic; its empty `aircons`
envelope is not a captured standalone controller response. No groups or Things
are included.
