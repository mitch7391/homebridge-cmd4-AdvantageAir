# Bounded v3/v4 parity review for Beta 1

Baseline: merged v4-beta d943d15d22346f0f2c6af70f5932c1fffd6084f1.
Reference: retained AdvAir.sh, frozen blob c8b6e7d12530dd3d4bb27b71bfa3d063139fcf53.
The legacy script is unchanged. V3 is a functional reference, not a required
native architecture. This review covers the listed controls, not all v3 features.

| Area | Retained v3 | Native v4 and classification |
| --- | --- | --- |
| Sensorless current temperature | CurrentTemperature selects an explicit zone, then MyZone, then constant1 when RSSI is nonzero; otherwise reports info.setTemp. | **Confirmed regression corrected:** explicit all-percentage systems use observed info.setTemp. A nonempty complete zone count, type 0, positive zone numbers, MyZone 0 and unambiguous constant metadata are required. Setpoint must be finite 16–32 C. |
| Sensor-equipped current temperature | Uses measuredTemp with weak RSSI-based capability checks. | **Intentional validation:** selected MyZone/constant sensor must have valid type, error=0, no clash and finite measurement. Missing readings or faults do not become setpoints. RSSI alone is not capability. |
| Zone opening/closing | State write plus local open-zone counting, opening constants/other rooms and sometimes forcing 100%; closing active MyZone may reassign it. | **Intentional design:** state-only writes; no invented airflow algorithm. Refuse active MyZone closure and recheck at dispatch. Manufacturer-documented controller protection supports this choice; firmware/physical timing is not proven by mocks. |
| MyZone selection | Open selected zone, select MyZone, copy zone target to main setpoint. | **Parity with safer coordination:** ordered open/select/target with fresh revalidation and confirmation; no blind replay or implicit reassignment when closing. Disabled MyZone (0) is not enabled by the plugin. |
| Heat/Cool/Off | Heat/Cool turn power on; Off retains stored mode. Dry historically mapped to Auto. | **Parity plus approved improvement:** same Heat/Cool/Off; never expose Dry as Auto. Dry and Ventilation are separate Fan services. Off on an inactive mode fan cannot stop a different active mode. |
| Target temperature | Main target plus active MyZone, or all sensor zones when MyZone disabled; RSSI and sequential writes. | **Parity:** main plus matching temperature zones in one patch; explicit type/number addressing. Whole-degree 16–32 writes are an accepted hardware-driven policy after fractional main/zone disagreement; measured precision is retained. Percentage zones are not target-write recipients. |
| Fan speed | Low/medium/high/auto = 25/50/90/100; write bands 0–33/34–67/68–99/100, autoAA. | **Parity:** same bands, zero means Low not Off, both auto/autoAA read as 100. Linked fan On is independent of AC power; existing Siri ambiguity is not changed. |
| Percentage zones | Nearest 5% writes for sensorless/RSSI-zero zones; separate state control. | **Intentional validated limits:** type 0, 5–100 in 5% increments; zero handled by On/Off rather than invalid value:0. Shared queue and no blind resend remain. This rule does not apply to MyPlace light brightness. |
| Timer | Native countdown represented by Lightbulb brightness (1%=6 minutes, up to 600); reads can clear countdowns. Separate file-backed mode timers can issue commands at expiry. | **Approved improvement:** native Timer Valve, 1–720 minutes with saved duration, observed countdowns and read-only polling. It does not import or replace file-backed mode timers. Legacy polling remains a concurrent writer until explicitly disabled. |

## Constant-zone evidence and release boundary

The retained supplied Aircon API notes assign constant-zone protection to the
controller and forbid closing active MyZone. The official
[MyAir/MyAir+ manual](https://support.advantageair.com.au/resources/myair-and-myair-a-user-manual)
(Constant Zones section, checked 13 October 2026) corroborates installer-set
constants opening automatically for pressure relief. The current forum source
could not be retrieved during this review; the local retained API summary is
secondary evidence of that supplied document, not a fresh original quote.

This is a documented controller responsibility, not merely an inference from v4
code. Retain v4's approach; copying v3's counters would introduce unvalidated
cross-command behaviour. Existing tests establish refusal/revalidation and
readback behaviour, not pressure relief. Existing ordinary live zone acceptance
is not recorded as a last-open-zone protection experiment.

For controller/firmware configurations outside the documented contract, obtain
installer/manufacturer confirmation that API commands retain minimum-airflow
protection, or qualified supervised evidence with installer settings intact.
Record requested state, actual override/readback and safe physical response;
never infer physical airflow from a successful HTTP response. Do not invite
unqualified all-outlets-closed testing on a running unit. If protection is not
established for a candidate installation, that configuration is not release-
qualified; do not silently replace controller safeguards in this plugin.

## Focused evidence and remaining unknowns

New permanent tests reuse the percentage fixture and actual Homebridge/HAP
characteristic handlers with simulated HTTP. They verify setpoint fallback,
no/selected constant, malformed/incomplete topology refusal, sensor fault
preservation, the retained real sensorless payload (including duplicated non-reference
zone numbers), Heat/Cool/Off, target confirmation, linked speed, percentage writes,
zone On/Off and stale-data failure. Existing measured-sensor tests remain.
This does not claim a physical sensorless installation or Apple Home rendering
was demonstrated. Simulator profiles and accepted hardware campaigns are not
repeated solely for this review.

The bounded source review found no other straightforward confirmed regression
in these controls. Installer-specific minimum airflow, newer controller modes,
physical MyZone/percentage behaviour on additional firmware and physical light
responses remain evidence boundaries, not reasons to invent additional features.
See beta1-testing.md for brightness, scene-size and migration checks.
