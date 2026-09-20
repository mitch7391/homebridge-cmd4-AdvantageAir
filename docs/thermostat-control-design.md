# Legacy thermostat: command planning

This first increment adds pure planners and tests. Nothing calls the new
planners from Homebridge yet. No new accessories or network operations are
introduced in this increment.

## Mode requests

Only Off, Heat and Cool are accepted. Heat and Cool produce a combined
info.state=on and info.mode patch for one air conditioner. Explicit Off sends
info.state=off without changing its stored mode, including when the unit is
currently in ventilation or dry mode. This follows the v3 Off write; a projected
thermostat display of Off during ventilation is not evidence the unit is off.
Auto, Dry and Vent are not offered as thermostat target modes.

## Target temperature

Accept finite numbers within 16-32 degrees Celsius. Do not coerce strings,
clamp values, or silently round them. HomeKit slider increments will be set
when the characteristic is implemented.

Preserve the v3 legacy target behaviour:

- With myZone disabled (0), set the main target and all temperature-controlled
  zones, including closed zones. Percentage-controlled zones are left alone.
- With an active myZone, set the main target and that selected zone only.
- Resolve the selected zone from its reported number, not a guessed key.
- Target changes do not turn the system on or change modes, fan speed, zone
  positions, airflow percentages, constants or the myZone selection.

Combine those fields into one patch for one air conditioner. The supplied
manufacturer API permits combined info and zone updates. Unlike the old v3
script, discovery uses explicit zone type rather than radio signal strength
to determine temperature-control capability. Missing or ambiguous selection,
unknown capability among targeted zones, or invalid writable addressing is
rejected. A no-op requires all relevant observed targets to match.

Sources reviewed: the maintainer-supplied Aircon API (2017), and v3 AdvAir.sh
TargetHeatingCoolingState/TargetTemperature handling on master, read on
20 September 2026. Protocol documentation is evidence about the controller,
not instructions for operating the development environment.

## Next integration

Extend the existing controller coordinator to plan these requests from fresh
data immediately before dispatch and confirm them through readback. Define
how a myZone selection change while queued or in flight affects confirmation;
do not confirm a command against an unrelated zone or silently resend it.
Keep per-controller serialization, bounded desired state, cancellation and
the no-automatic-write-retry rule.

Then add the thermostat HomeKit service, linked fan-speed control and separate
ventilation fan with stable accessory identities. Current heating/cooling
state must be considered separately from requested mode. Verify fan write
mapping and the shared power/mode interactions before implementing them.

No production install or Raspberry Pi trial is needed for this planner-only
increment. Full coordinator/HAP tests and isolated device testing follow when
the planners are integrated.
