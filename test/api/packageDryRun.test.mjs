import assert from 'node:assert/strict';
import test from 'node:test';
import { localPackageCheckOptions } from '../../dev/package-check-options.mjs';

test('local pack and offline install can write while outer publication stays dry-run', () => {
  const outer = Object.freeze({ npm_config_dry_run: 'true', NPM_CONFIG_DRY_RUN: 'true', npm_config_tag: 'beta' });
  for (const command of ['pack', 'install']) {
    const { env } = localPackageCheckOptions(command, outer);
    assert.equal(env.npm_config_dry_run, 'false');
    assert.equal(env.NPM_CONFIG_DRY_RUN, 'false');
    assert.equal(env.npm_config_tag, 'beta');
    assert.notEqual(env, outer);
  }
  assert.equal(outer.npm_config_dry_run, 'true');
  assert.equal(outer.NPM_CONFIG_DRY_RUN, 'true');
});

test('normal local checks preserve unrelated safeguards and never allow publication override', () => {
  const outer = Object.freeze({ npm_config_force: 'false', npm_config_registry: 'https://registry.npmjs.org/' });
  assert.deepEqual(localPackageCheckOptions('pack', outer).env, {
    ...outer, npm_config_dry_run: 'false', NPM_CONFIG_DRY_RUN: 'false',
  });
  assert.equal(Object.hasOwn(outer, 'npm_config_dry_run'), false);
  for (const command of ['publish', 'dist-tag', 'tag', '', 'PACK']) {
    assert.throws(() => localPackageCheckOptions(command, outer), /Only local package checks/);
  }
});
