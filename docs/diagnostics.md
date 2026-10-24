# Advantage Air logging

Normal logs report controller startup, first valid data, communication failure
and recovery, newly registered accessories, refused or failed commands, and
successful command confirmation. Restored accessories retain their existing
identities and produce the existing debug cache-loading message.

## Command messages

`Controller Bedroom Zone Controller confirmed: Closed` means a fresh controller
response matched the requested state after a write. It is not a claim that a
physical damper position has been independently measured. Accepting a request
in HomeKit does not produce this success message.

During a rapid reversal, confirmation of the earlier command is debug-only and
labelled `Earlier command confirmed`. The final confirmed request is logged at
info level. A request already satisfied by fresh preflight data sends no write
and produces only an `Already in requested state` debug message.

## Debug diagnostics

Enable **Detailed debug logging** for a controller in plugin settings, or
**Detailed debug logging for all controllers**. Selected diagnostics are emitted
at info level with a `[Debug]` prefix; Homebridge Debug Mode (`-D`) is not required.

`Controller read` summaries appear once per valid observed response. Pending
switch updates do not produce extra read messages. Empty busy replies and
invalid responses are not counted as valid reads.

`AA timing` events describe actual HTTP dispatch, response headers, completed
JSON bodies, and transport/JSON failures. Each event has a per-client request
ID, endpoint path, and elapsed milliseconds since dispatch. The Homebridge log
timestamp and configured controller name provide context. Queue waiting is not
included in that duration.

Body events report only the JSON shape, such as `object` or `empty-object`.
An explicit false write response is marked `rejected: true`. A body event does
not assert that system-data validation or command confirmation succeeded.
Error reasons are fixed categories: connect, http, body, json, timeout, or
cancelled. Requests cancelled before dispatch have no HTTP timing events.

Diagnostics exclude controller addresses, URL query strings, command payloads,
raw response contents, and underlying exception text. Normal accessory logs
include configured controller and zone names. Diagnostic observer exceptions
are ignored so they cannot change request outcomes or interrupt discovery.

Do not use the old `zone-trial-timing.mjs` preload with native diagnostics;
otherwise both layers emit timing logs. Keeping that untracked helper on disk
does not activate it.

## Scope and validation

Diagnostics do not alter scheduling. Normal polling remains at 30 seconds;
confirmation retries busy or unchanged responses after one second and eligible
transient read failures after two seconds. See the
[coordinator timing policy](zone-control-design.md#rapid-changes-and-bounded-work)
for the separate queue, preflight and confirmation deadlines. Slower-controller
hardware qualification remains distinct from automated simulator evidence.

Automated tests cover timing sanitisation and failure categories, body-wait
duration, observer exceptions, default-off logging, accessory creation and
cache restoration, one summary per observed read, and accurate confirmation
messages during reversals, unchanged requests, rejection, and expiry.

The coordinator was tested on the maintainer's e-zone controller, including
rapid and multiple zone requests. Completed live debug/UI acceptance is recorded
in [package readiness](package-readiness.md#remaining-release-gates); it is no
longer a pending pre-merge check. These observations do not establish compatibility
with all Advantage Air controllers.
