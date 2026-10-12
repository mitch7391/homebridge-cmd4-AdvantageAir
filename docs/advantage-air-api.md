# Advantage Air API notes

## Sources and scope

These notes summarise Advantage Air forum documentation supplied by the
maintainer: Aircon API (2017), additional-device API (2020), and Lights API
(2020).

Aircon source:
https://advantageair.proboards.com/thread/2/sticky-aircon-api-document

The documents describe MyAir5 and later systems with suitable tablet app
versions. They do not establish compatibility with every older controller.
Saved v3 fixtures and future device testing supplement this documentation.

## Shared reads

- HTTP GET /getSystemData, normally on port 2025.
- The response includes aircons, myLights, myThings and system metadata.
- Controller addresses are configured; no IP discovery method is documented.
- No polling interval or rate limit is documented.
- Use one coordinated polling loop per controller.
- Multiple callers must share an in-flight read.

## Air conditioning

- One controller can manage up to four air conditioners.
- Discover air conditioner and zone identifiers from returned data.
- Zone type 0 uses percentage control; other types use temperature control.
- Documented percentage commands: 5–100, in increments of 5.
- Documented temperature commands: 16–32 degrees Celsius.
- Constant zones are managed by the controller to protect airflow.
- A selected myZone has a temperature sensor and cannot be closed.
- Commands use /setAircon?json=... and target one air conditioner.
- Multiple settings for that air conditioner may be combined.

The document mentions empty {} responses while hardware confirms a change,
potentially taking up to four seconds. Which responses this affects is
ambiguous and requires testing.

## Additional devices

- Discover devices under myThings.things.
- channelDipState identifies the device category.
- buttonType describes the displayed control.
- Commands use /setThing?json=... and target one device.
- Documented command values are 0 and 100 only.
- Physical-position feedback for doors and blinds is not established by
  the document. Do not assume a button value confirms physical position.

## Lights

- Discover lights under myLights.lights.
- relay: true identifies an on/off-only light.
- Documented dimming range: 10–100.
- Switching off uses state: "off", not brightness 0.
- Commands use /setLight?json=... and target one light.
- The API notes allow state and brightness together; Beta 1 deliberately sends
  separate On and Brightness intentions through the shared controller queue.
- Preserve the historical light command syntax before URL encoding:
  `{id:"LIGHT_ID",state:on}`, `{id:"LIGHT_ID",state:off}`, or
  `{id:"LIGHT_ID",value:37}`. The `json` query parameter name does not make
  these legacy payloads strict JSON.

### Beta 1 brightness decision and hardware validation

Keep HomeKit Brightness at 0–100 with `minStep: 1`. Do not clamp or round
light brightness to a 10% minimum, 5% steps or another increment. Normal
On/Off continues to use the separate On characteristic and `state:on|off`.
This is an intentional Beta 1 decision, not proof of every controller's range.

Evidence considered in the maintainer-approved decision:

- The retained Lights API notes document 10–100 dimming and `state:"off"`.
- Historical v3 forwarded requested light brightness directly to `/setLight`;
  its explicit 5% rounding applied to AC zone percentages, not lights.
- The reviewed homebridge-myplace behaviour exposes 1% brightness steps and
  does not enforce a 10% minimum.
- Historical controller snapshots contain insufficient low-brightness examples
  to establish the real controller minimum.

Treat the documented 10% lower bound as a known but unverified hardware/firmware
limitation for Beta 1. Keeping requests permissive allows testers to establish
whether modern controllers support lower values rather than hiding that
behaviour behind plugin-side clamping.

On a real dimmable MyPlace light, test **1%, 5%, 9%, 10% and 11%**. For each,
record the requested HomeKit value, physical light response, subsequent
`/getSystemData` brightness value, and whether the controller accepts, clamps,
quantises or rejects the request. Record the controller/tablet firmware version
alongside the observations where available.

Treat **0% separately from Off**. Normal Off remains `state:off`; do not redesign
the plugin around `value:0` unless later real-hardware evidence requires it.
These are pending beta hardware checks, not simulator-confirmed capabilities.
No implementation change or new validation run is required by this decision.

## Implementation rules

- Keep exact protocol field names, including myZone, myLights and myThings.
- Use Advantage Air naming for plugin branding and new implementation names.
- Generate and URL-encode the established per-endpoint payload: strict JSON for
  native AC commands, and the historical syntax above for `/setLight`.
- Preserve last valid state when a read fails or returns incomplete data.
- Track freshness separately so retained data is not presented as a new reading.
- Never remove accessories solely because of a failed or incomplete read.
- Validate light entries independently so incomplete light observations cannot
  inherit freshness from healthy AC data. Explicit `aircons: {}` is supported
  when the controller does not report missing AC systems; omitted `aircons`
  remains unproven and is rejected. Retain empty/busy and malformed-response guards.
- Do not log entire responses: they can contain location information,
  identifiers, notification tokens and PINs.
- Sanitise fixtures before adding or updating captured controller data.

## Current implementation

The platform creates one client/coordinator per configured controller, sharing
polling, command serialization, freshness, deadlines and confirmation. Native
AC accessories and individual MyPlace light accessories are implemented. Lights
are discovered automatically from `myLights.lights`; optional per-controller
`excludedLightIds` uses IDs, not names. Groups, scenes and Things are ignored.

Light identity combines controller ID and light ID, independent of name or IP.
Relay evidence exposes On; dimmer evidence exposes On and Brightness. Established
dimmer capability is retained when readings become incomplete, with unavailable
readings reported rather than fabricated state. Missing observations never imply
Off or permission to remove cached accessories. Ambiguous writes are read back
without blind resend. Shutdown stops admission and cancels queued work.

The existing physical AC acceptance remains valid. Packaged simulator compatibility
passed on Homebridge 2.4.0 / Node 24.21.0 and Homebridge 1.8.5 / Node 22.23.3.
Standalone lab and manual Apple Home sanity checks do not replace physical MyPlace
light acceptance: that remains a beta-tester responsibility, including firmware
readback, offline/recovery behaviour and the low-brightness checks above.
