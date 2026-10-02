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

A HomeKit write acknowledges local acceptance of a validated request. It does
not assert that the controller has already completed the change. The Switch
shows the requested value while confirmation is pending; the controller's last
observed value and timestamp remain separate internally.

One ControllerCoordinator per controller owns normal polling, preflight,
physical writes and confirmation. The accessory handler has no independent
command queue or seven-second confirmation deadline. Managers preserve existing
accessory UUIDs and the legacy switch/separate-temperature layout.

Admission requires valid recent data and passes the zone planner, including
myZone protection. Before sending, the coordinator obtains fresh data and
rechecks stable identity, zone capability and protection. A matching fresh state
needs no write. Otherwise it sends exactly one encoded state-only request.

An exact empty-object read response is considered temporarily busy. Preflight,
MyZone snapshots between ordered steps, confirmation and ordinary/startup polls
retry only this known busy condition at one-second intervals within their existing
budgets. Commands retain their single 15-second execution budget (shortened by
intent expiry); polls retain their 10-second budget. Busy reads do not extend either.
Other validation, HTTP, connection and response-body errors retain their failure
handling. No physical write is retried.

Preflight waits for valid fresh data and replans from it, including detecting a
no-op. Unsent superseded requests stop waiting; shutdown prevents later dispatch.
MyZone continues from its confirmed step without replay or rollback. A poll that
recovers within its budget publishes normally without a failure/recovery event;
exhausted polls retain the existing last-good-data/freshness policy. Ordinary polls
defer while commands are running, and valid confirmation snapshots update
temperature accessories as well as switches.

An explicit controller rejection fails the command. An ambiguous transport
failure is reconciled by reads within the operation budget, without resending.
A valid old state is not confirmation and may be followed by a matching state.

## Rapid changes and bounded work

The coordinator keeps at most one unsent desired value per zone state,
thermostat mode, or thermostat temperature, with at most 64 pending control
requests across the controller. A newer unsent value for the same control
replaces an older one. Different controls retain their queue positions.
Already transmitted commands cannot be recalled. Their completion updates the
observed snapshot without overwriting a newer requested value in HomeKit.
Other queued rooms retain their order, preventing a repeatedly changed room
from jumping ahead of them.

Each accepted intent expires after 30 seconds. Each execution, including its
fresh preflight, write and readback, has at most 15 seconds, shortened to the
intent's remaining lifetime. Individual HTTP requests retain a 10-second cap
and receive cancellation from the coordinator. These are engineering limits,
not manufacturer guarantees. They do not make HomeKit wait for confirmation.

A timed-out reader cannot send a write when it eventually returns. Unsent
expired intentions are discarded. An unconfirmed transmitted command cancels
dependent queued intentions instead of sending them into uncertain state.
Shutdown cancels pending work and prevents late publication; restart does not
replay intentions. Cancellation cannot undo an already transmitted command.

## Availability and errors

Immediate refusals are reported to HomeKit and logged with the zone name and
reason. Errors after acknowledgement cannot retroactively reject the original
HomeKit request: they clear the pending value, mark the affected zone unavailable,
and emit one failure message for that intent. Later valid observations restore
availability. Other zones retain their valid observations.

Observed values are never replaced with invented target readings. Pending state
does not refresh sensor timestamps. Without a valid read, observations expire
after 90 seconds. Cached accessories remain unavailable at startup until valid
controller discovery. Failed reads do not remove accessories.

## Validation

The automated suite exercises the real client, platform, HomeKit characteristics
and full HAP write path against a simulated transport. It includes the supplied
7.225-second confirmation trace, rapid reversals, unsent replacement, multiple
rooms, shared temperature refresh, myZone changes before dispatch, constant
zones, write rejection, ambiguous delivery, stale and malformed reads, bounded
expiry, identity changes and shutdown with late reads.

The earlier executor and seven-second HAP waiting tests are replaced by the
coordinator integration tests. Transport cancellation tests are retained.
The coordinated implementation still requires an isolated Raspberry Pi live
trial; automated simulation does not establish compatibility with every device.
