# Legacy linked fan speed

This increment adds a Fan service, subtype fan-speed, to the existing thermostat
accessory and links it to the Thermostat service. The accessory UUID is unchanged.
Cached thermostats gain the service on valid discovery and existing fan services
are reused. No separate ventilation accessory is created in this increment.

The mapping preserves v3 AdvAir.sh RotationSpeed handling (master reviewed on
21 September 2026): 0-33 maps Low, 34-67 Medium, 68-99 High, 100 Auto. Displayed
values are respectively 25, 50, 90 and 100 percent. These are mode selectors,
not claims about measured motor speed. Auto sends autoAA, as v3 did; readback
accepts both auto and autoAA. This must be verified on the real controller.

The linked FanSpeed service changes info.fan only. It never changes power, HVAC
mode, temperature, zone state or myZone. Its required On characteristic preserves
the legacy always-on speed-control presentation when data is available. An On/Off
write is acknowledged as On and sends no controller command. Zero speed selects
Low, not power off. HomeKit write responses preserve the normalized speed value.
Actual ventilation power control belongs to the later separate fan accessory.

Fan requests use the same coordinator, fresh preflight, stable aircon identity,
serialized HTTP transport, optimistic target and exact readback process as the
other controls. Repeated unsent speed changes coalesce independently of mode,
temperature and zone requests. Unknown speed data is unavailable. Rejection,
expiry, stale data and shutdown use existing policies. Logging follows normal
dispatch, debug confirmation and warning failures including requested speed.

Live check: record the original fan setting and power/mode/target, exercise Low,
Medium, High and Auto one at a time, then restore the original speed. Confirm
info.fan changes without other settings changing. Do not repeat thermostat tests.
