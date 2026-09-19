# Zone switch control

The initial legacy layout provides a Switch accessory for each discovered
temperature-controlled zone, alongside its separate temperature sensor.
Percentage-controlled zones, thermostat controls, and alternative layouts are
outside this change.

## Controller responsibility

Electronic constant zones are not permanently-open zones. Advantage Air's
supplied Aircon API text states that the controller decides whether constants
need to open to protect ductwork. The official MyAir manual describes automatic
opening when insufficient zones are open; it does not specify a fixed delay.

Source: https://support.advantageair.com.au/resources/myair-and-myair-a-user-manual

Accordingly, the planner does not count open zones, modify constant settings,
force other rooms open, or change airflow percentages. A close request for a
constant zone is allowed. The controller may override it. Later polling reflects
the controller's actual state without repeatedly resending Close.

The supplied API separately states that the active myZone cannot be closed.
The planner refuses that closure; it does not automatically choose a different
temperature reference room. A missing or ambiguous myZone selection also
prevents a close command. Opening a zone does not require that selection.

A refused HomeKit request produces a warning identifying the controller, zone,
and reason, including an active-myZone refusal. It returns a communication error
to HomeKit and does not send the refused command. The refusal is logged once per
request rather than repeated on each poll.

## Command flow

1. The HomeKit handler starts a seven-second deadline when a write arrives,
   including time spent waiting behind another request for that switch.
2. One executor per controller serializes whole zone operations. The client
   also serializes HTTP requests from polling and commands.
3. Each operation obtains a fresh system response, resolves the zone's stable
   identity, and replans against that response. If the state already matches,
   no write is needed.
4. Otherwise the client sends one encoded `/setAircon?json=...` request for that
   zone. HTTP success or an empty JSON response is not state confirmation.
5. The executor waits one second before each fresh confirmation read, allowing
   at most five attempts within the remaining deadline. It succeeds only when
   the same zone identity reports the requested state.
6. The manager accepts the confirmed response before the HomeKit write resolves.
   Reads arriving during a pending write wait for that result, with their own
   seven-second deadline.

The command itself is never automatically retried. Failed confirmation reads may
be retried within the attempt and time limits. Polls started before or during a
completed command cannot overwrite its result with older data.

## Cancellation and availability

The executor also enforces a seven-second deadline from its own entry point.
Cancellation is passed through the manager, executor, HTTP queue, and active
write request. An expired queued request cannot later send a command. A slow
read may finish after cancellation, but checks after that read prevent it from
initiating a late write. Shutdown cancels waiting operations and stops polling.

Cancellation cannot undo a command already sent to the controller. After a
failed or unconfirmed operation, the manager makes its switch readings
unavailable until a newer valid poll restores them. It does not claim that the
requested change failed to happen physically, nor expose pre-command data as
confirmation.

Cached switches remain unavailable at startup until valid discovery data arrives.
Previously valid switch data expires after 90 seconds without a successful
refresh. Invalid identities also make affected readings unavailable. Accessories
are retained rather than removed solely because of failed or incomplete reads.

## Validation status

Automated coverage includes planning, transport, ordering, confirmation,
controller overrides, cancellation, full HAP request deadlines, cached accessory
restoration, and platform integration with separate temperature sensors.

Live controller reads and temperature sensors have been validated on the isolated
Raspberry Pi test bridge. Zone writes and their confirmation timing still need
live validation: change one ordinary zone, compare HomeKit with the controller,
then restore its original state. Active-myZone reassignment remains unsupported.
