import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import console from 'node:console';
import { execFileSync } from 'node:child_process';
import { fileURLToPath, URL } from 'node:url';

// Run through npm so its own CLI is used on Windows as well as Linux.
const root = fileURLToPath(new URL('../', import.meta.url));
const npm = process.env.npm_execpath;
assert.ok(npm, 'Run npm run check:package.');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'aa-package-check-'));
const created = [];
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const run = (command, args, cwd = root) => execFileSync(command, args, { cwd, stdio: 'inherit' });
const capture = (command, args, output) => {
  const fd = fs.openSync(output, 'w');
  try {
    execFileSync(command, args, { cwd: root, stdio: ['ignore', fd, 'inherit'] });
  } finally {
    fs.closeSync(fd);
  }
};

function filesBelow(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? filesBelow(file) : [file];
  });
}

try {
  // Never overwrite a maintainer's local configuration. Only remove our probes.
  for (const relative of ['dev/lab/local.json', 'assets/package-check-local.json', 'dist/package-check-stale.js']) {
    const file = path.join(root, relative);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    if (!fs.existsSync(file)) {
      fs.writeFileSync(file, '{"packageCheckProbe":true}\n', { flag: 'wx' });
      created.push(file);
    } else if (relative === 'dist/package-check-stale.js') {
      throw new Error('Stale-build probe already exists; remove it before checking.');
    }
  }
  const output = path.join(temporary, 'pack.json');
  capture(process.execPath, [npm, 'pack', '--json', '--pack-destination', temporary], output);
  assert.ok(!fs.existsSync(path.join(root, 'dist/package-check-stale.js')), 'prepack did not clean dist.');
  const results = read(output);
  assert.equal(results.length, 1);
  const packed = results[0];
  const manifest = read(path.join(root, 'package.json'));
  assert.equal(packed.name, manifest.name);
  assert.equal(packed.version, manifest.version);
  assert.equal(manifest.private, true, 'Publication remains a separate, explicitly authorised step.');
  assert.equal(manifest.license, 'MIT');
  assert.equal(manifest.author, 'mitch7391');
  assert.equal(Object.keys(manifest.dependencies ?? {}).length, 0);

  const expected = [
    'package.json', 'README.md', 'AdvAir.sh', 'config.schema.json',
    'LICENSE', 'LICENSE.homebridge-template', 'TEMPLATE_SOURCE.txt',
    'assets/README.md', 'assets/settings-header.png', 'assets/settings-header.svg', 'docs/v3-migration.md',
  ];
  for (const source of filesBelow(path.join(root, 'src'))) {
    if (source.endsWith('.ts') && !source.endsWith('.d.ts')) {
      const base = 'dist/' + path.relative(path.join(root, 'src'), source).replaceAll(path.sep, '/').slice(0, -3);
      expected.push(base + '.js', base + '.d.ts', base + '.js.map');
    }
  }
  assert.deepEqual(packed.files.map(file => file.path).sort(), expected.sort(), 'Unexpected or missing packed files.');
  const archive = path.join(temporary, packed.filename);
  const listing = path.join(temporary, 'members.txt');
  capture('tar', ['-tzf', archive], listing);
  assert.deepEqual(fs.readFileSync(listing, 'utf8').trim().split(/\r?\n/).sort(), expected.map(file => 'package/' + file).sort());
  run('tar', ['-xzf', archive, '-C', temporary]);
  for (const file of expected) {
    assert.deepEqual(fs.readFileSync(path.join(temporary, 'package', file)), fs.readFileSync(path.join(root, file)), file);
  }
  // Windows cannot represent the Unix executable bit faithfully; Linux CI must verify it.
  if (process.platform !== 'win32') {
    // Inspect stored permissions, independent of extraction/filesystem behaviour.
    const modes = path.join(temporary, 'legacy-mode.txt');
    capture('tar', ['-tvzf', archive, 'package/AdvAir.sh'], modes);
    assert.match(fs.readFileSync(modes, 'utf8'), /^-rwxr-xr-x\s/, 'Archive must preserve AdvAir.sh mode 0755.');
  }

  const install = path.join(temporary, 'consumer');
  fs.mkdirSync(install);
  fs.writeFileSync(path.join(install, 'package.json'), '{"name":"aa-package-consumer","private":true}\n');
  run(process.execPath, [npm, 'install', '--offline', '--ignore-scripts', '--omit=dev', '--no-audit', '--no-fund',
    '--package-lock=false', archive], install);
  // Import from a consumer directory, without the development tree or Homebridge installed.
  const smoke = path.join(install, 'smoke.mjs');
  fs.writeFileSync(smoke, `import assert from 'node:assert/strict';
import register from '${manifest.name}';
const calls = [];
register({ registerPlatform: (...args) => calls.push(args) });
assert.deepEqual(calls.map(call => call.slice(0, 2)), [
  ['${manifest.name}', 'AdvantageAir'], ['${manifest.name}', 'cmd4AdvantageAir'],
]);
assert.ok(calls.every(call => typeof call[2] === 'function'));
`);
  run(process.execPath, [smoke], install);
  console.log(`PASS: ${expected.length} packed files match; local probes excluded; stale dist removed; consumer import succeeds.`);
  console.log(`Archive and full file manifest: ${temporary}`);
} finally {
  for (const file of created) {
    fs.rmSync(file, { force: true });
  }
}
