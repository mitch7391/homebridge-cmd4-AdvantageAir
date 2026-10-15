import assert from 'node:assert/strict';
import fs from 'node:fs';
import process from 'node:process';
import { fileURLToPath, URL } from 'node:url';

/** Packing remains possible while private; release metadata must stay beta-only. */
export function assertBetaPackage(manifest) {
  assert.equal(manifest.name, 'homebridge-advantageair');
  assert.match(manifest.version, /^4\.0\.0-beta\.(0|[1-9]\d*)$/, 'Expected an explicit v4 Beta 1-series prerelease.');
  assert.equal(typeof manifest.private, 'boolean', 'Keep private explicit: true until separately approved for release.');
  assert.equal(manifest.publishConfig?.tag, 'beta', 'The default publication tag must be beta.');
  assert.equal(manifest.publishConfig?.registry, 'https://registry.npmjs.org/', 'Unexpected publication registry.');
}

/** This guard performs no publication or registry calls. */
export function assertBetaPublication(manifest, env) {
  assertBetaPackage(manifest);
  assert.equal(manifest.private, false, 'Publication disabled: private remains true.');
  assert.equal(env.AA_BETA_RELEASE_PACKAGE, manifest.name, 'Explicit standalone package acknowledgement required.');
  for (const key of ['npm_config_ignore_scripts', 'npm_config_force']) {
    assert.ok(env[key] === undefined || env[key] === false || env[key] === 'false', `Prohibited publication bypass: ${key}`);
  }
  assert.equal(env.AA_BETA_RELEASE_VERSION, manifest.version, 'Explicit release-version acknowledgement required.');
  assert.equal(env.npm_config_tag, 'beta', 'Pass --tag beta explicitly; never publish this branch as latest.');
  assert.equal(env.npm_config_registry, manifest.publishConfig.registry, 'Pass --registry https://registry.npmjs.org/ explicitly.');
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const manifest = JSON.parse(fs.readFileSync(new URL('../package.json', import.meta.url), 'utf8'));
  assertBetaPublication(manifest, process.env);
}
