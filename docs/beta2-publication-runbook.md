# Beta 2 publication handoff — approval required

Target: `homebridge-advantageair@4.0.0-beta.2`.
This document is preparation, not permission to rehearse, publish or change tags.
Follow [the publication policy](beta-publication.md). Beta 1 remains immutable.

## Source and qualification

Preparation starts at merged PR #147,
`c9b226f02295133a3c931b210be52cce2a20958d`.
The candidate commit is recorded in the maintainer handoff. After merging the
preparation PR, independently approve the exact resulting release SHA; do not
substitute a moving branch tip or reuse the Beta 1 SHA.

Require green Node 22, Node 24 and Homebridge 1.8.5 / Node 22 CI on the approved
release commit. Reuse unchanged runtime evidence. The maintainer visually
accepted the corrected Settings page on 20 October 2026; this is not new
physical MyPlace-light or cache-migration evidence.

Use a clean isolated Linux checkout with the reviewed locked dependencies.
Do not disturb existing work or use the live Homebridge installation.

**In the Codespaces terminal, inside that isolated release checkout:**

```bash
set -euo pipefail
read -r -p 'Separately approved release commit (40 hex): ' RELEASE_COMMIT
[[ "$RELEASE_COMMIT" =~ ^[0-9a-f]{40}$ ]]
test "$(git rev-parse HEAD)" = "$RELEASE_COMMIT"
test -z "$(git status --porcelain --untracked-files=all)"
test "$(git remote get-url origin)" = \
  https://github.com/mitch7391/homebridge-advantageair.git
test "$(git ls-remote origin refs/heads/v4-beta)" = \
  "$(printf '%s\trefs/heads/v4-beta' "$RELEASE_COMMIT")"
node --input-type=module <<'NODE'
import assert from 'node:assert/strict';
import fs from 'node:fs';
const p = JSON.parse(fs.readFileSync('package.json', 'utf8'));
assert.equal(p.name, 'homebridge-advantageair');
assert.equal(p.version, '4.0.0-beta.2');
assert.equal(p.private, false);
assert.equal(p.publishConfig.tag, 'beta');
assert.equal(p.publishConfig.registry, 'https://registry.npmjs.org/');
assert.ok(['22', '24'].includes(process.versions.node.split('.')[0]));
NODE
node --version
npm --version
npm whoami --registry=https://registry.npmjs.org/
npm view homebridge-advantageair versions dist-tags --json \
  --registry=https://registry.npmjs.org/
npm view homebridge-cmd4-advantageair dist-tags --json \
  --registry=https://registry.npmjs.org/
```

Stop if Beta 2 already exists, the account is unexpected, any source guard fails
or tag state differs from the reviewed snapshot. Never log tokens or OTPs.
Confirm supported authentication/2FA privately; dry-run cannot prove permission.
At preparation, native beta/latest were both Beta 1; legacy latest was 3.12.2
and beta was 3.6.0-beta.2. Re-read rather than assuming this remains current.

## Separately approved rehearsal

**In the same Codespaces terminal and approved release checkout, only after
rehearsal approval:**

```bash
export AA_BETA_RELEASE_PACKAGE=homebridge-advantageair
export AA_BETA_RELEASE_VERSION=4.0.0-beta.2
export npm_config_tag=beta
export npm_config_registry=https://registry.npmjs.org/
npm publish --dry-run --tag=beta --registry=https://registry.npmjs.org/ \
  --ignore-scripts=false --force=false
```

Preserve npm 11's explicit lifecycle environment as well as CLI options.
Capture the full policy/lint/build/package output and exact generated manifest,
archive SHA-256 and warnings outside the checkout. Confirm the packaged schema
has no visible exclusion editor but retains the optional JSON array. Confirm
all package bytes against the approved source, including licences and metadata.
Recheck clean Git state and both tag maps after the rehearsal.
Do not retry a failed rehearsal by disabling hooks or editing approved source.

## Separately approved publication

Recheck source, registry, account and approval immediately before the write.
Use the same acknowledgements above and retain the official registry and beta tag.

**In the same verified Codespaces release checkout, only after explicit actual
publication approval (never during preparation):**

```bash
npm publish --tag=beta --registry=https://registry.npmjs.org/ \
  --ignore-scripts=false --force=false
```

Do not assume latest remains unchanged: initial Beta 1 publication assigned both
tags. If npm returns an ambiguous error, inspect the registry before considering
any retry. A version that reached the registry must never be republished.

## Read-only verification after publication

**In the Codespaces terminal, after publication:**

```bash
npm view homebridge-advantageair@4.0.0-beta.2 \
  name version gitHead dist --json --registry=https://registry.npmjs.org/
npm view homebridge-advantageair dist-tags --json \
  --registry=https://registry.npmjs.org/
npm view homebridge-cmd4-advantageair dist-tags --json \
  --registry=https://registry.npmjs.org/
```

Download the exact registry `dist.tarball` to a separate evidence directory.
Verify its bytes against registry `dist.integrity` (SHA-512 SRI), record SHA-256,
and compare every unpacked member and its content with the reviewed source/
package manifest. Account explicitly for registry-added `gitHead`; do not claim
the local candidate archive SHA-256 must equal a newly generated publish archive.
Verify the name/version, corrected schema, complete allowlist, metadata and
absence of legacy shell backend, development fixtures or private configuration.

Require beta=Beta 2 and unchanged legacy tags. Record actual latest. If latest
still identifies Beta 1, obtain separate approval before promotion. If latest
already identifies Beta 2, do not perform a redundant promotion. Unexpected tag
movement requires review, not automatic repair.

For an approved promotion, use `dev/beta-latest-policy.mjs before` and `after`
with Beta 2 package/version acknowledgements, `AA_BETA_LATEST_APPROVAL=4.0.0-beta.2`,
the actual `AA_BETA_PREVIOUS_LATEST`, exact `AA_BETA_RELEASE_COMMIT`, verified
`AA_BETA_RELEASE_INTEGRITY` and official registry. Separately review the literal
version-specific tag command; this runbook does not authorise it. Never use
`npm dist-tag --dry-run` as a safety mechanism.

The legacy tag guard intentionally expects 3.12.2 until v3.12.3 is actually
published. Any later mismatch requires review, not bypassing the guard.

## GitHub prerelease and incidents

After verified npm publication, separately approve Git tag `v4.0.0-beta.2`
at the exact published commit and a GitHub **prerelease**. Use the changelog's
Beta 2 notes, retain hardware qualifications and backup/migration guidance,
and announce only the verified version. Check Homebridge discovery separately;
new keywords do not guarantee immediate indexing.

On a bad release, stop promotion/announcements and preserve evidence. Warn
testers and separately approve correction/deprecation or an incident-specific
tag rollback; the forward-only latest gate is not a rollback tool. Do not
unpublish automatically or reuse the version. User recovery must preserve
Homebridge backups, identities and the separate v3 installation as described
in [the testing guide](beta1-testing.md#rollback--homebridge-web-ui).
