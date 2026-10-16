# Legacy percentage-controlled zones

The maintainer-supplied Advantage Air specification is authoritative: `type === 0`
is percentage-controlled; positive integer types use the existing temperature-zone
layout. RSSI, measured temperature and sensor errors do not select the layout.

New percentage zones receive one Lightbulb named `<zone name> Zone`. Its On
characteristic reads/writes `state` (`open` / `close`); Brightness reads/writes
`value`. They have independent pending controls in the existing coordinator.

## Percentage and zero handling

- Positive integer HomeKit requests are rounded to the nearest 5%, bounded to
  5–100%. The returned write response and desired reading use that normalized value.
- HomeKit advertises 0–100 with a 1% step. Normalization happens in our handler:
  HAP's own 5% step rounding would turn a small positive request into zero.
- Brightness zero requests Close through the existing state planner, including
  its active-myZone protection. It sends no value write and returns the retained
  percentage. On becomes false; the stored percentage remains meaningful while off.
- A positive Brightness request sends only `value`; it does not open a closed zone.
  Apple Home may separately send On when operating its Lightbulb interface. That
  independent request is processed normally and must be checked during live testing.
- Ordinary On/Off writes send only `state`. Unknown or invalid percentages fault
  Brightness without disabling an otherwise valid On control.

Fresh preflight re-resolves the stable identity and checks type and value. Each
physical write is sent once. Existing readback confirmation, busy handling,
ambiguous-delivery reconciliation, expiry, shutdown and failure behaviour apply.
Rapid percentage changes supersede only that zone's pending percentage request.
State, other zones and other controller controls retain their own pending slots.

## Identity and cache

UUIDs use the existing stable zone identity plus `zone-percentage`. Controller MID,
aircon UID and zone key define identity. An aircon address or display-name change
does not recreate the accessory. A zone key itself remains part of its identity;
this change does not invent name-based or number-based zone migration.

Cached Lightbulbs start unavailable until validated discovery. Missing data or a
changed capability retains the accessory unavailable, without replacing it with
a Switch. It recovers if the same percentage zone returns. Existing cached
temperature-zone Switches remain usable through the already-supported sensor
dropout case, even if the controller temporarily reports type zero. No Lightbulb
is added beside that Switch. This deliberately avoids automatic layout migration.
Existing separate temperature-sensor lifecycle behaviour is unchanged.

## Validation boundary

Automated tests exercise real Homebridge characteristics against a simulated
controller, plus an HTTP transport test. They cover mixed types, normalization,
zero, independent state/value requests, fresh addressing, no-ops, rejection,
ambiguous delivery, timeouts, staleness and cached capability changes.

Real hardware must still establish whether a closed zone retains its percentage,
whether value-only writes preserve its state, and how Apple Home presents zero
and normalized values. Use a genuinely configured type-zero zone for that check;
removing a sensor from an existing cached Switch is intentionally not migration.
