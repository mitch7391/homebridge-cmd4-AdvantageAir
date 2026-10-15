# Maintainer beta publication gate

Preparation only. This change keeps private: true and version 4.0.0-beta.1.
No publish command is executed by tests, CI or the transfer handoff.
The target is homebridge-advantageair@beta. The separate stable package
homebridge-cmd4-advantageair@latest must remain untouched. The v3 invitation message is a later, separate task.

## Safeguards

- publishConfig pins tag beta and registry https://registry.npmjs.org/.
- dev/beta-policy.mjs enforces homebridge-advantageair, explicit boolean private, and a
  4.0.0-beta.N version (no stable/RC version or leading-zero beta number).
- Packing and compatibility checks share this policy instead of requiring
  private:true forever. The future reviewed private:false change will not break
  these checks. The flag is not changed by any helper.
- prepublishOnly refuses private:true; requires AA_BETA_RELEASE_PACKAGE equal
  to homebridge-advantageair and AA_BETA_RELEASE_VERSION equal to the exact
  package version, explicit --tag beta and explicit public registry;
  then runs lint and actual package validation. Pack still cleans/rebuilds dist.
- If the guard runs, enabled force/ignore-scripts configuration is rejected.
- There is no automatic publish CI job, tag creation, version bump or dist-tag update.

These are accident-prevention controls, not an npm account security boundary.
An operator can bypass lifecycle hooks with --ignore-scripts; publishing a tarball
must not be assumed to execute this checkout's prepublishOnly. Use the reviewed
checkout publication workflow below, never a raw archive or a bypass flag.
Do not change global/user npm configuration to make this pass.

## Future release sequence — Codespaces terminal, only after approval

1. Use a clean complete checkout of the reviewed release commit. Record Git SHA,
   Node/npm versions and green hosted CI. Close any configuration-specific airflow
   evidence gap; see v3-v4-parity.md. Review the installed backup/migration guide.
2. Recheck name availability/ownership and the unused version on
   homebridge-advantageair. Separately record homebridge-cmd4-advantageair@latest
   and the new package's current tags (absence is valid for a first release).
   Never expect the new package latest tag to refer to v3. Confirm the intended
   maintainer account and supported npm authentication/2FA before approval.
   A version cannot be republished; if the name/version is unavailable, stop.
3. Obtain explicit publication approval, then review a separate change setting
   private:false. Keep the beta version, publishConfig and guard intact. If the
   version must change, update lock root and version-pinned docs/harness references
   coherently. Do not silently choose another version or remove the guard.
4. On that exact release tree, run clean-install CI checks, production audit and
   package validation. Record the tarball SHA-256 and complete file manifest;
   require tester/migration guides and absence of AdvAir.sh/legacy registration.
   Review dev-only advisories separately. Do not use npm audit fix.
5. Rehearse a dry run from the checkout with exact-package/version acknowledgements and
   explicit beta/public-registry arguments. Review package name, version, tag,
   file list and lifecycle results. Stop on any mismatch. A dry run is not a
   publication and does not establish registry availability/authentication.
6. Recheck Git cleanliness, release tree, npm account/name/version availability
   and both packages' recorded tags immediately before the separately authorised
   publication. In the Codespaces terminal, the future command form is
   AA_BETA_RELEASE_PACKAGE=homebridge-advantageair
   AA_BETA_RELEASE_VERSION=<approved-version> npm publish --tag beta
   --registry https://registry.npmjs.org/ from the reviewed checkout (both
   acknowledgements are environment assignments on the same command). For
   rehearsal add --dry-run. This procedure is not approval to run it now.
7. After publication verify homebridge-advantageair@beta points to the approved
   version and its latest tag has not been newly assigned or changed. Verify
   homebridge-cmd4-advantageair@latest still points to the separately recorded v3
   version. Compare published archive integrity/content with the intended release.
   If anything differs, stop: do not automatically retag latest,
   unpublish, publish another version or issue the v3 invitation.

The acknowledgement is not a secret and does not replace maintainer approval.
Credentials/OTP belong in npm's supported secure interaction, never committed
files or logs. Published-package install/migration smoke checks and the v3
notification follow only after the beta is available and separately authorised.
Record the source commit and create the explicitly approved v4 prerelease notes
without implying a v3 update. New-package Homebridge verification is a separate
application after publication, not inherited from v3 or a controlled-beta blocker.
Retain the existing repository/issues; make source and release links select v4.

References: [npm package metadata](https://docs.npmjs.com/cli/v11/configuring-npm/package-json/)
and [npm lifecycle scripts](https://docs.npmjs.com/cli/v11/using-npm/scripts/).
