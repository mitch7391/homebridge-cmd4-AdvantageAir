# Native timer as a legacy Valve

This adds one `<aircon name> Countdown` accessory with a Generic Valve service per
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
  12 hours. Subsequent direct API tests on PIC7GS10-A accepted and displayed 1, 29,
  45 and 720 minutes. 721 and 1440 did not create a timer; zero cancelled it.
  Thus the UI picker does not define the API granularity. Integer-minute support
  from 1 through 720 is the adopted policy, not a claim that every value has been
  individually tested on every controller model.

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

SetDuration advertises 60 through 43,200 seconds with a 60-second step. Accepted
whole-second input rounds **up** to the next whole minute: 61 seconds becomes
120, while 45 minutes stays 45. Values below 60, above 43,200, non-integer
seconds or non-numeric input are refused. The transport accepts integer minutes
1 through 720, plus zero only to clear a countdown. Active=0 remains the user
cancellation control; SetDuration=0 is not a cancellation path.

The 30-minute default and existing stored selections are preserved. RemainingDuration
still reports observed native minutes multiplied by 60, including one minute or
zero. Both duration characteristics support up to 12 hours.

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
so this allows one minute boundary, not arbitrary drift. For N=1, only a positive
one-minute countdown confirms a start; zero never satisfies the N-1 allowance.
Zero, a different
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

On first attachment to fresh valid controller data, both new and restored
accessories use `<aircon name> Countdown`. The accessory display name, Accessory
Information Name and existing Valve service display name/Name are aligned and a
changed cached name is saved once. The UUID input, service instance, context and
selected duration are unchanged. This is a naming change for the unreleased
feature, not a general migration mechanism. Countdown avoids the observed Siri
Clock-timer wording collision; actual Siri accessory targeting remains a live
check. Apple Home may retain its own user-assigned name independently.

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

Completed live validation on feature commit c4fcc462f6b3a48d76eeec860b17e9693002df6b
covered both power directions, inactive duration selection, active replacement,
cancellation without power changes, unchanged unrelated controls, and paired
cache/SetDuration restoration. That campaign does not need repeating.

Minute-policy live validation is complete on commit
`d0b09ee4fd978624844322b33428af6dd94ca741`: Home's 45-minute selection
produced exact native 45-minute readback and the tablet displayed On in 45min.
Valve Off cancelled the countdown and AC power remained off. The HAP metadata
and Home duration-picker investigation are also complete and are not reopened
by this naming change.

The remaining live check for the Countdown name is only whether Siri targets
the Home accessory instead of creating a Clock timer. No duration, expiry,
cache or power-direction campaign needs repeating.
