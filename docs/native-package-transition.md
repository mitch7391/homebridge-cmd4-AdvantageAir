# Existing native development installations: package transition

This applies only to native v4 development accessories previously installed as
`homebridge-cmd4-advantageair`. Ordinary v3/Cmd4 users follow
[v3 migration](v3-migration.md); they must not migrate Cmd4 cache records.

The new npm identity is `homebridge-advantageair`; platform `AdvantageAir`,
device-derived UUID inputs and service subtypes remain unchanged. Homebridge
also stores a `plugin` owner in each serialized accessory. Its rename fallback
may not run when v3 is installed under the old name. Starting with stale owners
can therefore orphan native accessories even when their UUIDs are unchanged.

## Offline transition, with a complete backup

1. Record installed package versions/archives and take a full Homebridge backup
   including configuration, `accessories` and `persist`. Record the native
   bridge username, PIN and port. Do not remove its bridge from Apple Home.
2. Stop Homebridge and every child process. Keep them stopped until package,
   configuration and cache changes are complete. Use the same operating-system
   account that owns the Homebridge files. Do not run the helper while the UI
   or service can restart Homebridge; `--homebridge-stopped` is an operator
   attestation, not automatic service detection.
3. Identify the cache for the existing native bridge in the Homebridge storage
   `accessories` directory: `cachedAccessories` for the main bridge, or
   `cachedAccessories.<12-hex-bridge-username>` for a child bridge. Never select
   `persist` files. Preview each relevant file separately; do not bulk-edit.
4. Obtain `dev/migrate-native-cache.mjs` from the reviewed standalone commit.
   It is maintainer tooling, intentionally not included in the npm plugin.
   Copy it outside the installed plugin directories. Review its source/checksum
   from that commit before use. The helper defaults to a read-only preview.
5. Run the preview, review the selected UUIDs/count, then apply with that exact
   SHA-256 and count. It changes only records with both
   `plugin: homebridge-cmd4-advantageair` and `platform: AdvantageAir`. UUIDs,
   services, characteristics, context (including saved Timer duration/light
   capability), Cmd4 records and all other owners are retained. It refuses
   duplicate UUIDs, malformed records, symlink paths and unexpected hashes/counts.
   Applying saves an exclusive byte-for-byte backup beside the cache before
   replacing it. An existing backup causes refusal, never overwriting a backup.

**Run in the Raspberry Pi/Homebridge terminal, with Homebridge stopped.**
Replace the absolute paths with the reviewed helper and your selected cache:

```sh
node /absolute/path/migrate-native-cache.mjs --cache /absolute/storage/accessories/cachedAccessories
```

**Run in the Raspberry Pi/Homebridge terminal, still stopped, only after review.**
Replace HASH and COUNT with the preview values, and use the same cache path:

```sh
node /absolute/path/migrate-native-cache.mjs --cache /absolute/storage/accessories/cachedAccessories --apply --homebridge-stopped --sha256 HASH --expect-count COUNT
```

6. While still stopped, install the reviewed native tarball under its new name.
   Remove the old *native development build* from the old package identity, or
   replace it with your recorded genuine v3 release if Cmd4 still needs it.
   Never load two native `AdvantageAir` implementations together. Preserve the
   v3 backend path and dependencies when legacy accessories remain in use.
7. Keep the native platform block, devices and existing `_bridge` settings.
   If platform identifiers are fully qualified, change only
   `homebridge-cmd4-advantageair.AdvantageAir` to
   `homebridge-advantageair.AdvantageAir`. Update explicit plugin allow/deny
   lists for native v4 while retaining v3 when needed. An unqualified
   `AdvantageAir` remains valid. Do not change `Cmd4`/`cmd4AdvantageAir` entries.
8. Restart, inspect for orphan/duplicate warnings and verify expected counts,
   existing Home rooms/automations, Timer duration and bridge pairing. Stop on
   discrepancies. Do not clear storage, delete accessories or re-pair as a shortcut.

## Rollback and evidence boundary

Stop Homebridge again before rollback. Restore the recorded package versions,
configuration and the matching pre-transition cache backup together. Preserve
the same bridge identity and `persist`; if Homebridge already removed accessories,
use the full recorded backup and investigate rather than repeatedly restarting.
The helper does not automatically roll back or remove its backup/temp evidence
after an error. Inspect any failure before retrying.

Focused tests exercise exact owner-only transformations and real HAP
serialization. The packaged compatibility harness installs genuine v3 alongside
native v4, checks normal restart, then reproduces old development ownership and
checks restoration after this helper. Those disposable tests do not prove
Apple Home room/automation retention or real pairing on your installation.
Preserving bridge identity and storage is necessary; actual Home presentation
requires a backed-up maintainer check. No live installation is modified by CI.

For existing persistent lab profiles, keep their storage/bridge identities too:
stop the lab, update its explicit plugin allowlist to `homebridge-advantageair`
and migrate only that lab's native cache using the same guarded procedure.
New lab profiles already use the new package name. The lab does not silently
rewrite an existing configuration or reset its pairing.
