import assert from 'node:assert/strict';
import { Buffer } from 'node:buffer';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import process from 'node:process';
import console from 'node:console';
import { fileURLToPath } from 'node:url';

const oldPlugin = 'homebridge-cmd4-advantageair';
const newPlugin = 'homebridge-advantageair';
export const checksum = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

/** Explicit offline migration only; never imported or invoked by plugin startup. */
export function transformNativeCache(cache) {
  assert.ok(Array.isArray(cache), 'Expected Homebridge serialized accessory array.');
  const uuids = new Set();
  const selected = [];
  for (const accessory of cache) {
    assert.ok(accessory && typeof accessory.UUID === 'string' && Array.isArray(accessory.services), 'Invalid accessory record.');
    assert.ok(!uuids.has(accessory.UUID), 'Duplicate accessory UUID; stop.');
    uuids.add(accessory.UUID);
    if (accessory.plugin === oldPlugin && accessory.platform === 'AdvantageAir') {
      selected.push(accessory.UUID);
    }
  }
  assert.ok(selected.length > 0, 'No old native AdvantageAir records; nothing to migrate.');
  const result = cache.map(accessory => accessory.plugin === oldPlugin && accessory.platform === 'AdvantageAir'
    ? { ...accessory, plugin: newPlugin }
    : accessory);
  return { cache: result, uuids: selected };
}

export function migrateNativeCache(file, { expectedHash, expectedCount, stopped, apply = false } = {}) {
  assert.equal(path.isAbsolute(file), true, 'Select one absolute cache path explicitly.');
  assert.match(path.basename(file), /^cachedAccessories(?:\.[0-9A-Fa-f]{12})?$/, 'Select the main or one child-bridge cache.');
  assert.equal(fs.lstatSync(file).isSymbolicLink(), false, 'Symlink cache refused.');
  assert.equal(fs.realpathSync(file), path.resolve(file), 'Symlink/junction path refused.');
  assert.ok(fs.statSync(file).isFile());
  const before = fs.readFileSync(file);
  const hash = checksum(before);
  const plan = transformNativeCache(JSON.parse(before));
  const summary = { file, sha256: hash, count: plan.uuids.length, uuids: plan.uuids };
  if (!apply) {
    return summary;
  }
  assert.equal(stopped, true, 'Stop Homebridge (including children) before applying; this flag is an operator attestation.');
  assert.match(expectedHash ?? '', /^[a-f0-9]{64}$/, 'Supply the reviewed SHA-256.');
  assert.equal(hash, expectedHash, 'Cache changed since preview; stop.');
  assert.equal(plan.uuids.length, expectedCount, 'Unexpected native accessory count.');
  const mode = fs.statSync(file).mode & 0o777;
  const after = Buffer.from(JSON.stringify(plan.cache, null, 2) + '\n');
  const backup = file + '.before-standalone-' + hash + '.json';
  const temporary = file + '.standalone-' + crypto.randomUUID() + '.tmp';
  fs.writeFileSync(backup, before, { flag: 'wx', mode });
  assert.deepEqual(fs.readFileSync(backup), before);
  fs.writeFileSync(temporary, after, { flag: 'wx', mode });
  assert.deepEqual(fs.readFileSync(temporary), after);
  assert.deepEqual(fs.readFileSync(file), before, 'Cache changed while preparing migration; preserve backup/temp and stop.');
  fs.renameSync(temporary, file);
  assert.deepEqual(fs.readFileSync(file), after);
  return { ...summary, backup, migratedSha256: checksum(after) };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const options = {};
  let file;
  const seen = new Set();
  while (args.length) {
    const key = args.shift();
    assert.ok(!seen.has(key), 'Duplicate option.');
    seen.add(key);
    if (key === '--apply') {
      options.apply = true;
    } else if (key === '--homebridge-stopped') {
      options.stopped = true;
    } else if (['--cache', '--sha256', '--expect-count'].includes(key)) {
      const value = args.shift();
      assert.ok(value && !value.startsWith('--'), 'Missing option value.');
      if (key === '--cache') {
        file = value;
      } else if (key === '--sha256') {
        options.expectedHash = value;
      } else {
        assert.match(value, /^[1-9]\d*$/);
        options.expectedCount = Number(value);
      }
    } else {
      throw new Error('Unknown option: ' + key);
    }
  }
  assert.ok(file, 'Use --cache ABSOLUTE_PATH to preview; applying additionally requires --apply --homebridge-stopped --sha256 HASH --expect-count N.');
  console.log(JSON.stringify(migrateNativeCache(file, options), null, 2));
}
