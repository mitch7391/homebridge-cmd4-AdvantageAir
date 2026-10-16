---
name: Bug Report
about: Report a native v4 or legacy Cmd4 Advantage Air problem.
title: "[Bug]"
labels: bug
assignees: mitch7391
---

**Integration:** native v4 / legacy Cmd4 / both during migration

**Exact versions:** homebridge-advantageair, homebridge-cmd4-advantageair (if installed),
Homebridge, Node, npm, OS; Cmd4 if applicable

**Migration:** fresh native install / ordinary v3 coexistence / old native-development
cache-owner transition; main or child bridge (do not share pairing identifiers)

**Controller:** model/tablet/firmware; sensor-equipped or sensorless; temperature
and percentage zone counts; MyZone enabled; relay/dimmer light counts if relevant

**Reproduction:** requested action/value, expected outcome, physical response,
controller/tablet readback, elapsed time; repeatable or intermittent

**Overlap:** other controller callers, native/Cmd4 timers or automations active?

**Sanitised evidence:** short logs around one request with plugin Detailed debug
logging enabled; relevant config fields only. Include before/after values for
brightness or zone issues. Do not post full backups or raw getSystemData dumps.
Remove IPs, controller UIDs, personal names/locations, PINs and tokens. Do not
run unsafe all-zones-closed tests to produce an issue report.

**Recovery/rollback:** what restored operation? Did restarting change identities?

**Screenshot:** optional, with identifying details removed.
