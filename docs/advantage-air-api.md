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
- State and brightness may be combined for that light.

## Implementation rules

- Keep exact protocol field names, including myZone, myLights and myThings.
- Use Advantage Air naming for plugin branding and new implementation names.
- Generate and URL-encode JSON; do not copy malformed documentation examples.
- Preserve last valid state when a read fails or returns incomplete data.
- Track freshness separately so retained data is not presented as a new reading.
- Never remove accessories solely because of a failed or incomplete read.
- Before supporting additional device types, validate sections independently
  so missing aircon data does not block otherwise valid light data.
- Do not log entire responses: they can contain location information,
  identifiers, notification tokens and PINs.
- Sanitise fixtures before adding or updating captured controller data.

## Current implementation

The read-only client validates the response envelope and aircon structure.
It rejects responses with missing reported air conditioners.
It supports request timeouts and shared in-flight reads.

The platform now creates one client and poller per configured controller.
Polling retains the last valid response and records read timestamps and
failure status. Shutdown stops scheduled polling and ignores late results;
an in-flight request can continue until it completes or times out.

Failure and recovery messages are logged, with optional debug summaries.
Accessory creation, control commands and live hardware validation remain
outstanding.
