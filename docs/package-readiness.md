# Native v4 package readiness

## Licence and metadata

The package declares MIT, matching the root `LICENSE` and historical v3 releases.
The v3.12.2 release commit
`20cfbc7c1855bd530a97e4dbf5935cdbdeb26434` declared MIT, as does the published v3
npm listing. The Apache-2.0 package declaration entered with the template-based
v4 foundation (`cb685190878ab8f59ccd37bef15ac17dbabae5bf`).
This metadata correction does not relicense the retained template material:
`LICENSE.homebridge-template` and `TEMPLATE_SOURCE.txt` remain unchanged and ship
alongside the project's MIT licence. Header artwork attribution also remains in
`assets/README.md`.

The standalone name is `homebridge-advantageair`. Author `mitch7391`, exact
PayPal funding URL, version and engines are retained. Canonical repository metadata
and the approved 20 search keywords were updated after publication for a future
package release; they do not change the immutable Beta 1 npm artifact.
Development `private: true` is intentional; the published source used the separately
approved `private: false` release change.

## Build and package contract

From a clean checkout, install development dependencies with `npm ci`.
`npm pack` runs `prepack`, which calls the existing clean TypeScript build.
`prepublishOnly` now checks beta publication policy, then lint and the actual
package checker; publication also runs the clean `prepack` build.
There is no consumer install/prepare hook and no compiler dependency at runtime.
Do not use `--ignore-scripts` for a release pack: it intentionally bypasses npm's
build safeguard and is suitable only for separately verified build artifacts.

The explicit file allowlist includes:

- `dist` JavaScript, declarations and JavaScript source maps;
- `config.schema.json` and the exact two header assets plus their attribution;
- `docs/v3-migration.md`, `docs/native-package-transition.md`,
  `docs/beta1-testing.md`, both licence files and the template source reference;
- npm's automatically included `package.json` and `README.md`.

The final inventory is established from the source modules and explicit
non-runtime allowlist, then compared with the actual npm tarball. The standalone
baseline had 128 files; published Beta 1 has 129 files, including the installed
tester guide, without additional runtime modules. Do not substitute an assumed
count for the exact manifest.
AdvAir.sh and the removed legacy handler remain excluded.
Maps and declarations remain available for diagnostics/tooling; maps refer to
repository source paths, but TypeScript source is not included in the package.

Tests, simulator/lab code, `dev/lab/local.json`, additional asset-directory files,
screenshots, GitHub workflows, dependency lockfiles, node_modules and development
configuration are excluded. Keep secrets outside the explicitly shipped files;
an allowlist cannot detect a secret deliberately placed inside an allowed file.

`npm run check:package` uses actual npm packing, checks the complete tarball file
set and bytes, and refuses the legacy backend/handler in the native package. It places
temporary non-secret probes to check local-file exclusion and stale-build cleanup,
without overwriting an existing local configuration. It then installs the tarball
offline into a disposable consumer and imports/registers only AdvantageAir
without contacting a controller or needing development dependencies. Temporary
probes are removed even on failure; the archive and manifest are retained in the
printed temporary directory for review. Node 22/24 Linux CI runs this check.
Only the internal pack and offline consumer-install child environments disable
inherited dry-run so their local validation artifacts exist. The parent's
publication dry-run and all hooks remain intact; no check publishes anything.

## Remaining release gates

Preserve the completed live UI, naming, debug, identity and Timer acceptance.
These packaging changes do not require repeating those controller campaigns.

Beta 1 was published on 19 October 2026 from
95c41ca771cb159cde0d2decee23f6f1d5df1018. Node 22/24 and Homebridge 1.8.5 CI passed;
the Linux rehearsal passed on Node 24.21.0 / npm 11.19.0. All 129 published files
and package integrity were verified against approved source. The production
audit found zero vulnerabilities; four development-only high-severity findings
were assessed as non-blocking for that release. These are historical results,
not a current audit of future releases. Both native npm tags identified Beta 1
during initial publication, without a separate latest-promotion command.

The following gates apply to a new, separately reviewed release, not to
republishing 4.0.0-beta.1:

1. Run Linux `npm ci`, lint, tests and `npm run check:package` on the reviewed
   commit. This verifies clean-build/package lifecycle and the final allowlist. A developer's existing node_modules is not a clean-install result.
2. Run `npm audit --omit=dev` and separately `npm audit` with registry access.
   There are currently no production npm dependencies. Previously reported
   development-tool advisories require assessment for the next release; do not use
   `npm audit fix` blindly or confuse development issues with runtime exposure.
3. Preserve the completed standalone Linux Homebridge 2.4.0 / Node 24.21.0 and
   Homebridge 1.8.5 / Node 22.23.3 coexistence/restart/cache-owner campaigns.
   Release-policy/documentation changes do not invalidate that runtime evidence.
   See [compatibility evidence](homebridge1-compatibility.md); this does not
   establish every permitted patch version. Current ranges remain Node `^22.10.0 || ^24.0.0` and Homebridge
   `^1.8.0 || ^2.0.0`.
4. Choose an unused beta version using the registry, obtain explicit publication
   approval, then change `private` explicitly to false in a separately reviewed
   release change. Packing and compatibility checks accept both explicit boolean
   states under the same beta metadata policy. Follow [beta publication](beta-publication.md);
   publish a new version with beta, inspect its artifact and actual tag outcome,
   then separately approve latest promotion if a tag change is needed. Preserve
   both v3 tags and do not bypass scripts. No repository check or CI job performs
   publication or tag promotion. Latest is intentionally a beta during this programme.

Existing native development migrations still need a backed-up real Apple Home
pairing/room/automation check; simulated cache restoration is not that evidence.
Hardware beta qualifications, including safe airflow and physical lights, remain
in [the tester guide](beta1-testing.md).

The plugin-card shield/author/donation presentation remains a separate registry
and Homebridge UI-state follow-up, not a reason to change author/funding metadata.
