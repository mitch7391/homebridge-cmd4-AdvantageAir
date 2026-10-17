import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { URL } from 'node:url';
import { assertBetaPackage, assertBetaPublication } from '../../dev/beta-policy.mjs';

const current = JSON.parse(fs.readFileSync(new URL('../../package.json', import.meta.url), 'utf8'));
const release = () => ({ ...globalThis.structuredClone(current), private: false });
const environment = () => ({
  AA_BETA_RELEASE_PACKAGE: current.name,
  AA_BETA_RELEASE_VERSION: current.version,
  npm_config_tag: 'beta',
  npm_config_registry: 'https://registry.npmjs.org/',
});

test('package policy works before and after an explicitly reviewed private flag change', () => {
  assertBetaPackage({ ...current, private: true });
  assertBetaPackage(release());
  assertBetaPublication(release(), environment());
});

test('private package and missing publication acknowledgement are refused', () => {
  assert.throws(() => assertBetaPublication({ ...current, private: true }, environment()), /private remains true/);
  for (const key of Object.keys(environment())) {
    const env = environment();
    delete env[key];
    assert.throws(() => assertBetaPublication(release(), env));
  }
  assert.throws(() => assertBetaPublication(release(), { ...environment(), AA_BETA_RELEASE_VERSION: '4.0.0-beta.999' }));
});

test('stable versions, foreign packages and unsafe publication defaults are rejected during packing too', () => {
  for (const patch of [
    { name: 'another-package' }, { name: 'homebridge-cmd4-advantageair' }, { version: '4.0.0' }, { version: '4.0.0-rc.1' },
    { version: '4.0.0-beta.01' }, { private: undefined }, { private: 'false' },
    { publishConfig: { tag: 'latest', registry: 'https://registry.npmjs.org/' } },
    { publishConfig: { tag: 'beta', registry: 'https://example.invalid/' } },
  ]) {
    assert.throws(() => assertBetaPackage({ ...release(), ...patch }));
  }
});

test('initial publication still refuses latest despite the separately authorised dual-tag policy', () => {
  for (const tag of ['latest', 'next', '', 'Beta']) {
    assert.throws(() => assertBetaPublication(release(), { ...environment(), npm_config_tag: tag }));
  }
  assert.throws(() => assertBetaPublication(release(), { ...environment(), npm_config_registry: 'https://example.invalid/' }));
});

test('npm hooks keep the guard first, package validation before publishing, and clean builds on pack', () => {
  assert.equal(current.scripts.prepublishOnly, 'node dev/beta-policy.mjs && npm run lint && npm run check:package');
  assert.equal(current.scripts.prepack, 'npm run build');
});

test('wrong package acknowledgement and bypass flags are refused', () => {
  assert.throws(() => assertBetaPublication(release(), { ...environment(), AA_BETA_RELEASE_PACKAGE: 'homebridge-cmd4-advantageair' }));
  for (const key of ['npm_config_ignore_scripts', 'npm_config_force']) {
    for (const value of [true, 'true', '1', '']) {
      assert.throws(() => assertBetaPublication(release(), { ...environment(), [key]: value }));
    }
    assertBetaPublication(release(), { ...environment(), [key]: 'false' });
  }
});
