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

The package name, author `mitch7391`, exact PayPal funding URL, repository links,
Homebridge keywords, version and engine ranges remain unchanged. `private: true`
is intentional. No dependency updates or runtime changes are part of this work.

## Build and package contract

From a clean checkout, install development dependencies with `npm ci`.
`npm pack` runs `prepack`, which calls the existing clean TypeScript build.
`prepublishOnly` continues to run lint and build; publication also runs `prepack`.
There is no consumer install/prepare hook and no compiler dependency at runtime.
Do not use `--ignore-scripts` for a release pack: it intentionally bypasses npm's
build safeguard and is suitable only for separately verified build artifacts.

The explicit file allowlist includes:

- `dist` JavaScript, declarations and JavaScript source maps;
- root `AdvAir.sh`, retained for legacy migration compatibility;
- `config.schema.json` and the exact two header assets plus their attribution;
- `docs/v3-migration.md`, both licence files and the template source reference;
- npm's automatically included `package.json` and `README.md`.

The current output is 119 files: 36 JavaScript modules, 36 declaration files,
36 source maps and the 11 runtime/configuration/documentation files above.
Maps and declarations remain available for diagnostics/tooling; maps refer to
repository source paths, but TypeScript source is not included in the package.

Tests, simulator/lab code, `dev/lab/local.json`, additional asset-directory files,
screenshots, GitHub workflows, dependency lockfiles, node_modules and development
configuration are excluded. Keep secrets outside the explicitly shipped files;
an allowlist cannot detect a secret deliberately placed inside an allowed file.

`npm run check:package` uses actual npm packing, checks the complete tarball file
set and bytes, and verifies the executable legacy script on Unix. It places
temporary non-secret probes to check local-file exclusion and stale-build cleanup,
without overwriting an existing local configuration. It then installs the tarball
offline into a disposable consumer and imports/registers both platform aliases
without contacting a controller or needing development dependencies. Temporary
probes are removed even on failure; the archive and manifest are retained in the
printed temporary directory for review. Node 22/24 Linux CI runs this check.

## Remaining release gates

Preserve the completed live UI, naming, debug, identity and Timer acceptance.
These packaging changes do not require repeating those controller campaigns.

Before external beta publication:

1. Run Linux `npm ci`, lint, tests and `npm run check:package` on the reviewed
   commit. This also verifies Unix executable permissions and the clean-install
   lifecycle. A developer's existing node_modules is not a clean-install result.
2. Run `npm audit --omit=dev` and separately `npm audit` with registry access.
   There are currently no production npm dependencies. Previously reported
   development-tool advisories still need a fresh online assessment; do not use
   `npm audit fix` blindly or confuse development issues with runtime exposure.
3. Record compatibility evidence separately from declared engine ranges. Existing
   real Homebridge 2.4.0 / Node 24.21.0 acceptance remains valid. Homebridge 1.8.5
   with Node 22 still needs its planned compatibility check; no expanded claim is
   made here. Current ranges remain Node `^22.10.0 || ^24.0.0` and Homebridge
   `^1.8.0 || ^2.0.0`.
4. Choose an unused beta version using the registry, obtain explicit publication
   approval, then remove `private` in a separately reviewed release change. Publish
   using the beta dist-tag, preserving the existing v3 latest tag. Nothing in this
   increment publishes or enables automatic publication.

The plugin-card shield/author/donation presentation remains a separate registry
and Homebridge UI-state follow-up, not a reason to change author/funding metadata.
