# Migrating from v3 to native v4

This guide describes the compatibility-bearing v4 development package.
An npm beta is not yet published. Follow the announced beta installation
instructions when it is; do not substitute an unbuilt GitHub branch.

## What the upgrade preserves

v3 HomeKit accessories belong to `homebridge-cmd4`. Their configured
`state_cmd` calls this package's `AdvAir.sh`. v4 temporarily includes that
unchanged executable at the same package-root path, so existing paths continue
to work **when the package is upgraded in the same installation location**.

The frozen source is v3 commit
`d65be40f736e4814c261c1470275f2405df20c94`, Git blob
`c8b6e7d12530dd3d4bb27b71bfa3d063139fcf53`, mode `100755`.
Its historical whitespace and acknowledgements are intentionally preserved.

Cmd4, its existing polling/queue configuration, Bash, curl, jq and a writable
temporary directory remain required for legacy accessories only. Existing
older Cmd4 installations may have a queue patch previously installed by the
v3 configuration creator; this package neither installs nor replaces it.

The old `cmd4AdvantageAir` platform alias is accepted by an inert compatibility
handler that logs a migration notice. It does not create accessories, poll,
write, convert configuration or activate native v4 from old device settings.
The configuration creator, custom UI and CheckConfig tools are not restored.

Native v4 uses platform `AdvantageAir`. New native users need none of this
legacy setup.

## Before upgrading

- Back up Homebridge configuration and pairing/storage, including the existing
  Cmd4 entries and any local script customisations.
- Check the actual `state_cmd` path. A changed npm prefix, container or
  Homebridge installation can invalidate it. The upgrade replaces any
  customised copy at the packaged `AdvAir.sh` path.
- Upgrade away from Node 18/20 first. Node 22/24 are the current v4 targets;
  check your Homebridge, Cmd4 and other plugins against the chosen version.
  Current validation is primarily Homebridge 2.x/Node 24, not a completed
  Homebridge 1.x or Node 26 compatibility claim.
- Know how to stop/disable the Advantage Air entries or their dedicated Cmd4
  bridge. Do not disable unrelated Cmd4 accessories unnecessarily.
- Check whether you use v3 features absent from native v4, such as MyPlace
  lights/Things, mode-specific legacy timers or alternative zone layouts.
  These are not automatically replaced.

## Transition

1. Upgrade the package in its existing installation location. Existing Cmd4
   accessories retain their backend; the old helper platform is inert.
2. Add a **separate** native `AdvantageAir` platform configuration using the
   plugin settings or the README's minimal example. Do not overwrite the
   existing Cmd4 configuration or repurpose the old helper entry.
   For the same naming convention, manually enter the base **Name** you configured
   in v3 (historically defaulting to `Aircon`) into native v4's Name field.
   This is saved separately as `homeName`; the retained legacy configuration
   stays untouched. Additional aircons use Name 2, Name 3, etc. Arbitrary Cmd4
   accessory renames made after ConfigCreator ran are not reconstructed.
   The existing v3/Cmd4 accessories remain available as a reference during migration.
3. Save/restart as prompted. Use Homebridge's own child-bridge controls if
   desired. Do not copy another bridge's username, port or pairing information.
4. Compare the old and new accessory sets. Rename/move the new accessories in
   Home and update scenes/automations deliberately.
5. Test native v4, then disable and eventually remove the old Advantage Air
   Cmd4 entries when satisfied. Remove the obsolete helper-platform entry too.
   Preserve Cmd4 itself if it still serves unrelated accessories.

There is no automatic transfer of v3 UUIDs, rooms, scenes or automations.
Both accessory sets may remain paired temporarily; inactive accessories can
show unavailable. No cache clearing or re-pairing is required merely to retain
the legacy backend.

## Temporary overlap and Timer precautions

Temporary concurrent v3/v4 operation is acceptable for migration/comparison,
not recommended as a permanent configuration. Each integration has its own
queue and cached state. Additional traffic and overlapping commands can cause
transient contention, delayed updates or unconfirmed requests. Avoid deliberately
issuing simultaneous/conflicting commands; no cross-plugin ordering is promised.

Ordinary comparisons should allow one operation to settle before the next.
Use one active integration for timing-sensitive fault finding. Different bridges
do not isolate traffic when both address the same controller.

**Legacy Timer reads are not always observational.** Native Timer polling in
v3 can clear countdown fields after observing a matching power state.
File-backed Fan/Cool/Heat timer polling can issue power/mode commands at expiry.

Cancel active legacy timers before validating the v4 native Timer, and disable
legacy Timer polling while doing that validation. Simply avoiding the old tile
does not stop polling. Disabling Cmd4 does not necessarily erase pending
file-backed timer state; check it before reactivation.

## Rollback and retirement

Stop/disable native v4 and let outstanding work finish before reactivating the
old integration for exclusive operation. Check retained legacy timer state.
Keep the existing Cmd4 configuration, pairing and dependencies until the
transition is accepted. Do not erase shared temporary directories or pairing
data as a rollback shortcut.

The retained backend lets you return to the configured legacy integration
without downgrading the npm package. If the installation itself needs rollback,
restore the recorded exact v3 package/configuration backup rather than assuming
an arbitrary old version matches your setup.

This compatibility layer is temporary. Its removal must be announced with
migration instructions before it is removed; no removal release is set yet.
