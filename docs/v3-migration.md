# Migrating from v3 to native v4

This guide describes two independently installed packages: existing v3
`homebridge-cmd4-advantageair` and native v4 `homebridge-advantageair`.
Follow [Beta installation and rollback](beta1-testing.md) when installing a
version announced by the maintainer; do not substitute an unbuilt GitHub branch.

## What remains with v3

v3 HomeKit accessories belong to `homebridge-cmd4`. Their configured
`state_cmd` continues calling the independently installed v3 package's `AdvAir.sh`.
Keep that package, installation prefix and configured path unchanged. Native v4
does not supply this backend and does not replace v3 when installed.

The frozen source is v3 commit
`d65be40f736e4814c261c1470275f2405df20c94`, Git blob
`c8b6e7d12530dd3d4bb27b71bfa3d063139fcf53`, mode `100755`.
It remains in the repository as historical parity reference, excluded from the
native npm package. Its whitespace and acknowledgements remain preserved.

Cmd4, its existing polling/queue configuration, Bash, curl, jq and a writable
temporary directory remain required for legacy accessories only. Existing
older Cmd4 installations may have a queue patch previously installed by the
v3 configuration creator; this package neither installs nor replaces it.

Only the separate v3 package registers `cmd4AdvantageAir`. Native v4 registers
only `AdvantageAir`, avoiding ambiguous legacy configuration. Existing v3 setup
tools remain with v3; native v4 does not provide them.

Native v4 uses platform `AdvantageAir`. New native users need none of this
legacy setup.

## Before adding native v4

- Back up Homebridge configuration and pairing/storage, including the existing
  Cmd4 entries and any local script customisations.
- Check the actual `state_cmd` path. A changed npm prefix, container or
  Homebridge installation can invalidate it. Installing native v4 must not
  remove or overwrite that v3 backend or local customisations.
- Upgrade away from Node 18/20 first. Node 22/24 are the current v4 targets;
  check your Homebridge, Cmd4 and other plugins against the chosen version.
  The standalone package passed Linux Homebridge 1.8.5/Node 22.23.3 and
  2.4.0/Node 24.21.0 coexistence/cache campaigns with genuine v3 installed.
  This is unpaired simulator evidence, not real Home room/automation retention.
  Node 26 remains outside the current engine range.
- Know how to stop/disable the Advantage Air entries or their dedicated Cmd4
  bridge. Do not disable unrelated Cmd4 accessories unnecessarily.
- Check whether you use v3 features absent from native v4, such as MyPlace
  Things, light groups/scenes, mode-specific legacy timers or alternative zone
  layouts. Individual MyPlace lights are supported.
  These are not automatically replaced.

## Transition

1. Keep v3 and Cmd4 installed. Add the reviewed standalone native package
   separately. If you already ran native development v4 under the old package
   name, first follow [the cache-transition procedure](native-package-transition.md).
2. Add a **separate** native `AdvantageAir` platform configuration using the
   Homebridge plugin settings. Do not overwrite the existing Cmd4 configuration
   or repurpose the old helper entry.
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

Existing Cmd4 identities, rooms and automations remain with the original
accessories when configuration, dependencies and pairing/storage are preserved.
Native accessories have separate identities; arrange them and transfer your
Home setup manually. There is no automatic transfer of rooms or automations.
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

The independently retained v3 backend lets you return to the configured legacy
integration without replacing native v4 with v3. If v3 itself was changed, restore
its recorded exact version/configuration backup. Keep native storage if planning
to resume v4 later. Neither npm package owns or removes the other package.
