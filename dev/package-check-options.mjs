import assert from 'node:assert/strict';
import process from 'node:process';

/** Only local pack/install validation may override inherited publication dry-run. */
export function localPackageCheckOptions(command, env = process.env) {
  assert.ok(['pack', 'install'].includes(command), 'Only local package checks may override dry-run.');
  return { env: { ...env, npm_config_dry_run: 'false', NPM_CONFIG_DRY_RUN: 'false' } };
}
