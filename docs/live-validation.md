# Live validation

## Read-only controller trial

Environment: Raspberry Pi running the official Homebridge image,
Debian 12 Bookworm, Node.js 24.21.0.

The beta client ran from a separate development folder alongside the
existing installation.

Results:

- A single getSystemData request succeeded.
- The controller returned ac1 with six zones.
- Three poller reads succeeded at 30-second intervals.
- Target-temperature changes made externally were observed as 24, 26
  and 24 degrees Celsius.
- The air conditioner remained off throughout the trial.
- Polling stopped automatically after the third attempt.

This validates basic reads and polling on this controller.
It does not validate writes, failure recovery on real hardware,
HomeKit accessories or other controller models.

## Discovery identifier check

A live read confirmed that the controller has a non-empty system.mid,
and ac1 has a non-empty info.uid. The response contained six zones.
No duplicate air conditioner IDs were found.

Identifier values were not printed. Stability across hardware replacement
or reconfiguration has not been established.