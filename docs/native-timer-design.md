# Native timer as a legacy Valve

This adds one `<aircon name> Timer` accessory with a Generic Valve service per
air conditioner reporting valid native countdown fields. It is the native
one-shot timer, not v3's separate fan/cool/heat software timers.

## Evidence and scope

The maintainer's PIC7GS10-A e-zone controller campaign established:

- `info.countDownToOn` and `info.countDownToOff` contain integer minutes, with
  one direction running at a time. AC On schedules Off; AC Off schedules On.
- Natural expiry changes power and clears the countdown without client cleanup.
- Reaching the scheduled power state early clears the timer without resumption.
- Native bin cancellation clears the countdown without changing power.
- `{}` is a documented transient hardware-confirmation response, observed at
  natural expiry and manual power changes.
- The tablet offers 30, 60, 90, 120, 150 and 180 minutes, then whole hours up to
  12 hours. These are proven UI selections, not proof of the API's entire range.

Historical v3 `AdvAir.sh` writes the appropriate countdown field through
`/setAircon`. Its six-minute Brightness conversion and client cleanup reads are
not copied. The real evidence establishes that the controller owns expiry.

The existing temperature zones, percentage Lightbulbs, thermostat, linked fan
speed, Vent/Dry fans and grouped MyZone are complete and remain unchanged.
The native Valve timer was the next substantive legacy-layout increment.
This increment does not implement other layouts, settings UI or release work.

## HomeKit mapping

| Characteristic | Meaning |
| --- | --- |
| ValveType | Generic Valve |
| IsConfigured | Configured |
| Active | Accepted pending intent, otherwise whether an observed countdown is running; never AC power |
| InUse | Confirmed observed countdown is running; not optimistic |
| RemainingDuration | Observed native minutes multiplied by 60; zero when neither countdown runs |
| SetDuration | Selected duration in seconds, stored in accessory context; does not shrink with remaining time |

Default selection is 30 minutes. The plugin does not infer the original duration
of a tablet-started timer from its remaining time. Its last selected duration
stays unchanged; RemainingDuration still shows the external timer correctly.

SetDuration advertises 30 minutes to 12 hours with minute resolution. Accepted
values round **up** to the tablet selections above: 31 minutes becomes 60, and
3.5 hours becomes 4. The planner rejects non-integer seconds, non-positive values
and values over 12 hours. HomeKit enforces the advertised characteristic bounds;
Active=0 is the cancellation control. No fractional minutes are transmitted.
RemainingDuration independently accepts whole-minute observations below 30
minutes, down to one minute. HAP's default one-hour duration maximum is extended
to 12 hours on both duration characteristics.

While inactive, setting duration only remembers the selection. Activation starts
the selected timer. Repeating Active=1 preserves an already-running timer;
editing duration while active replaces it. Deactivation clears only the active
countdown field and retains the selected duration for next time.

There is no local countdown scheduler and no timer-originated power write.
Ordinary polling can display an observation up to one poll interval old; HomeKit
may also render its own elapsed-time animation. Neither controls physical expiry.

## Commands and confirmation

Timer commands use the existing coordinator and serialized client request path.
Admission requires valid current data; preflight resolves the stable aircon
identity and re-reads power/countdown state before choosing direction or no-op.
One absolute countdown-only patch is sent at most once. Timer intents have their
own per-aircon queue key. Unsent replacements coalesce without replacing mode,
temperature, fan, MyZone or zone intents. A sent operation is reconciled before
its successor runs. Existing expiry, shutdown and failure/cancellation policies
apply unchanged.

Start/replacement confirmation requires the requested direction to be running
with N or N-1 minutes remaining. The existing whole-operation limit is 15 seconds,
so this allows one minute boundary, not arbitrary drift. Zero, a different
direction, greater values or a two-minute discrepancy cannot confirm a start.
This is observed-state confirmation, not proof of causation where an external
timer coincidentally has the same value. Cancellation requires both fields zero;
it does not require power to remain unchanged if someone changes power elsewhere.

An explicit controller rejection fails. Ambiguous delivery is reconciled by
fresh reads, never by resending. `{}` during confirmation uses the existing
bounded retry path. An ordinary busy poll retains last-good data until the
existing 90-second freshness limit. No timer-specific busy handling is added.
Malformed, simultaneous opposing, or power-inconsistent countdowns are
unavailable; they never trigger cleanup writes.

## Identity, cache and logs

UUID input is `[stableAirconIdentity, 'native-timer']`; names and aircon addressing
are not identity. Context markers are `advantageAirTimer` and
`advantageAirTimerDuration`. A restored Valve waits for fresh valid data, preserves
its service and chosen duration, and is retained unavailable if capability or
identity disappears. It is not deleted or replaced. No migration of other roles
is attempted.

Creation and command dispatch use normal logs; confirmations/no-ops use the
existing debug path. Admission refusal and command failure remain warnings.

## Validation and remaining live checks

Focused tests cover normalization, native observations, transport, fresh power
and addressing, queue replacement, rejection/ambiguous delivery, minute-boundary
confirmation, timeout, stale data, shutdown, natural/early cancellation
observations, HAP writes, cache serialization and restoration, and coexistence
with the existing layouts. An HTTP integration test uses an isolated test-only
controller model and the existing MyZone fixture; it includes `{}` readback.

The unchanged `dev/lab/AirConServer.cjs` was also attempted. Starting its native
timer throws `TypeError: Assignment to constant variable` in the countdown
handler (reassignment of `setStatementObj`). That is a pre-existing lab defect,
not a passed timer test. No simulator/worker/operator code is changed. Do not use
the paired simulator lab to validate native timer writes until that separate
issue is addressed. The HTTP model is not a substitute for Apple Home validation.

Minimum remaining real-controller/Home test:

1. Record power, mode, target, fan and both countdown fields. Start with no pending
   native timer; if one is already running, defer this test rather than replace it.
2. On the isolated test bridge, verify one Timer Valve appears inactive. Choose
   30 minutes while inactive: no native timer should start. Activate, check the
   tablet's direction against AC power, and confirm RemainingDuration/InUse after
   controller readback. Mode, target, fan and zones must remain unchanged.
3. Change duration once (for example 45 minutes should normalize to 60), confirm
   the new countdown, then turn the Valve off. Both countdowns must clear and AC
   power must remain unchanged. The chosen SetDuration must remain stored.
4. At a suitable time with the opposite AC power state, activate and cancel once
   to check the other direction. Restore the initial power state afterward.
5. Restart only the isolated Homebridge instance once. Check the same Valve and
   selected duration return without re-pairing. Finish with both countdowns zero.

The completed native natural-expiry/early-attainment investigation does not need
repeating. Apple Home's Valve controls/duration picker and these plugin-originated
writes have not yet been validated on the maintainer's paired real controller.
