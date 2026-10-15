# Maintainer public-beta publication and tag gates

Development keeps private: true and version 4.0.0-beta.1. No test, CI job,
package check or policy validator publishes or changes registry tags.

## Two separately approved registry operations

Publish homebridge-advantageair initially with beta. Verify its contents and
registry metadata, then obtain separate approval to assign latest to that exact
version. During the initial public beta programme both tags intentionally identify
the same reviewed prerelease. Latest means default installation, not stable quality.
Keep the public beta warning, prerelease version and GitHub Prerelease label.

Never modify homebridge-cmd4-advantageair. Its recorded tags are latest=3.12.2
and beta=3.6.0-beta.2. An intervening v3 release requires review of this snapshot,
not blindly restoring or changing its tags.

## Safeguards and limits

publishConfig still pins beta and the public registry. Initial publication must
pass dev/beta-policy.mjs: exact standalone name, 4.0.0-beta.N version, explicit
private:false, package/version acknowledgements and explicit beta/registry options.
Initial --tag latest remains prohibited. Force/ignore-scripts are refused when
the guard executes. prepublishOnly runs the guard, lint and actual package checks;
prepack cleans and rebuilds dist.

Only copied child environments for the checker's internal pack and offline
consumer installation override inherited dry-run. These local files must exist
for validation. The parent publication dry-run, process.env and hooks are unchanged.
No checker subprocess invokes publication or distribution-tag commands.

dev/beta-latest-policy.mjs is a read-only before/after gate. It requires exact
package/version acknowledgements, separate latest approval, the reviewed source
SHA and published sha512 integrity, an explicit previous latest (or none), matching
published metadata and beta tag, and unchanged v3 tags. It refuses downgrades,
repeated promotion and stable versions. It performs pinned-registry GET requests
only and never executes npm dist-tag.

Lifecycle hooks cannot protect independent npm dist-tag writes, raw-archive
publication or --ignore-scripts. These controls prevent accidents, not deliberate
bypass. Review the literal tag command separately. Registry reads/writes are not
atomic: coordinate with other maintainers, check immediately before each write
and verify afterward. Never automatically repair a tag or retry an ambiguous write.
Do not use --dry-run with dist-tag as if it made the operation harmless.

## Future release sequence

1. Use a clean reviewed v4-beta release commit with green CI. Preserve backups,
   hardware qualification boundaries and the fresh-install/native-cache distinction.
2. Read package/version availability and both complete tag maps. Confirm the npm
   account and supported authentication/2FA privately; never put tokens/OTP in Git.
3. Obtain approval for a separate private:false release change, keeping version,
   beta publishConfig and guards. Never silently choose a different version.
4. Validate that exact source: clean build, lint, policy tests, production audit
   and npm run check:package. Record the actual inventory and archive hashes.
   Review development advisories separately; do not use npm audit fix blindly.
5. Obtain rehearsal approval. Run the command below with --dry-run added and
   review all lifecycle output. Rehearsal does not prove registry authorisation.
6. Recheck source, account and registry; obtain separate publication approval.

**Future Codespaces terminal, reviewed release checkout, only after publication
approval; add --dry-run only for a separately approved rehearsal:**

```bash
AA_BETA_RELEASE_PACKAGE=homebridge-advantageair \
AA_BETA_RELEASE_VERSION=4.0.0-beta.1 \
npm publish --tag=beta --registry=https://registry.npmjs.org/ \
  --ignore-scripts=false --force=false
```

7. Require the exact beta tag and unchanged previous latest/v3 tags. Download and
   verify the archive against registry dist.integrity and reviewed contents,
   explicitly accounting for npm-added gitHead metadata. Record approved published
   integrity only after this review; do not automatically trust returned metadata.
8. Obtain separate approval for latest promotion. Set evidence below from that
   review. The validator does not itself constitute approval.

**Future Codespaces terminal, reviewed release checkout; read-only preparation
following artifact verification and latest-promotion approval:**

```bash
export AA_BETA_RELEASE_PACKAGE=homebridge-advantageair
export AA_BETA_RELEASE_VERSION=4.0.0-beta.1
export AA_BETA_LATEST_APPROVAL=4.0.0-beta.1
export AA_BETA_PREVIOUS_LATEST=none
export npm_config_registry=https://registry.npmjs.org/
read -r -p 'Approved published source commit (40 hex): ' AA_BETA_RELEASE_COMMIT
read -r -p 'Approved published sha512 integrity: ' AA_BETA_RELEASE_INTEGRITY
export AA_BETA_RELEASE_COMMIT AA_BETA_RELEASE_INTEGRITY
node dev/beta-latest-policy.mjs before
```

9. Review and approve the exact literal command. This changes the new package only.

**Future Codespaces terminal, same approved session; registry-changing operation,
never run during development or rehearsal:**

```bash
node dev/beta-latest-policy.mjs before &&
npm dist-tag add homebridge-advantageair@4.0.0-beta.1 latest \
  --registry=https://registry.npmjs.org/ &&
node dev/beta-latest-policy.mjs after
```

On any error inspect registry state. An ambiguous write may have succeeded: run
the read-only after check before considering a retry, not another blind write.

10. Check Homebridge UI exact-name search, normal installation, alternate selection
    and updates with backups. Record UI/Homebridge/Node versions. Announce only
    after the agreed checks. Git tags and GitHub Prerelease creation at the exact
    published commit need separate approval. Verified and v3 invitations are later.

## Subsequent betas and eventual stable release

For beta.2/beta.3 review a coherent version update, including lock root and any
version-pinned tooling/docs. Publish beta, inspect, then separately approve latest.
Supply the actual old latest rather than none. The gate requires increasing beta
numbers. Until promotion, default installs remain on the previous reviewed beta;
record this short interval explicitly so latest is not forgotten. No automatic
promotion or tag synchronisation belongs in CI.

Normal Homebridge updates should offer a higher latest prerelease; exactly pinned
installations may need explicit selection. Do not modify v3 or downgrade tags to
influence native updates. On a bad beta, stop promotion and warn testers; separately
approve a correction/deprecation. Automatic unpublishing is not rollback and a
published version cannot be reused. Emergency rollback of latest is intentionally
outside this forward-only gate and requires a separate incident procedure.

Stable 4.0.0 needs a separately reviewed policy/documentation transition: current
beta guards deliberately reject it. Decide then what beta should track; do not
bypass guards or silently retain permanent dual-tag synchronisation.

## Homebridge UI expectations

Current UI source uses exact-name registry lookup, all-version/tag lookup for
alternate selection, and /latest for normal installation/update metadata. Both
tags should make these paths resolve the approved prerelease and later higher
betas. Search indexing and UI-version-specific behaviour still require actual
post-publication checks; this is an expectation, not a completed UI acceptance.

References: [npm lifecycle](https://docs.npmjs.com/cli/v11/using-npm/scripts/),
[npm dist-tag](https://docs.npmjs.com/cli/v11/commands/npm-dist-tag/),
[Homebridge UI registry handling](https://github.com/homebridge/homebridge-config-ui-x/blob/latest/src/modules/plugins/plugins.service.ts).
