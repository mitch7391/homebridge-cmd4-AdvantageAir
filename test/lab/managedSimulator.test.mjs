// Explicit developer check: node --test test/lab/managedSimulator.test.mjs
// Uses fixed lab simulator ports; refuses occupied ports rather than touching a running lab.
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import fs from 'node:fs/promises';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { promisify } from 'node:util';
import { fileURLToPath, URL } from 'node:url';
import test from 'node:test';

const execute = promisify(execFile);
const repository = fileURLToPath(new URL('../../', import.meta.url));

test('actual lab CLI startup, fixture replacement and repeated start preserve one managed simulator', async t => {
  for (const port of [52025, 52026]) {
    const probe = net.createServer();
    await new Promise((resolve, reject) => {
      probe.once('error', reject);
      probe.listen(port, '127.0.0.1', resolve);
    });
    await new Promise(resolve => probe.close(resolve));
  }
  const runtime = await fs.mkdtemp(path.join(os.tmpdir(), 'aa-managed-lab-test-'));
  const cli = async (...args) => execute(process.execPath, [path.join(repository, 'dev/lab/lab.mjs'), ...args], {
    cwd: repository, env: { ...process.env, AA_LAB_HOME: runtime }, timeout: 45000, windowsHide: true,
  });
  await fs.mkdir(path.join(runtime, 'storage'));
  await fs.writeFile(path.join(runtime, 'storage/config.json'), JSON.stringify({
    bridge: { port: 51889 }, plugins: ['homebridge-cmd4-advantageair'],
    platforms: [{ platform: 'AdvantageAir', devices: [{ ipAddress: '127.0.0.1', port: 52025 }] }],
  }));
  t.after(async () => {
    // Only a record in this test's private runtime authorizes stopping its worker.
    try {
      await fs.access(path.join(runtime, 'simulator-control.json'));
    } catch {
      return;
    }
    await cli('simulator', 'stop');
    // Retain this small disposable runtime for diagnostics; never remove pairing directories.
  });
  assert.match((await cli('simulator', 'start')).stdout, /simulator: running/);
  const firstStatus = (await cli('simulator', 'status')).stdout;
  assert.match(firstStatus, /^simulator: running \(PID \d+\)/);
  const read = async () => {
    const response = await globalThis.fetch('http://127.0.0.1:52025/getSystemData');
    assert.equal(response.status, 200);
    return response.json();
  };
  assert.equal((await read()).aircons.ac1.info.myZone, 0);
  const reset = await globalThis.fetch('http://127.0.0.1:52025/reInit');
  assert.equal(reset.status, 200);
  await reset.text();
  const url = new URL('http://127.0.0.1:52025/');
  url.searchParams.set('load', path.join(repository, 'dev/lab/fixtures/myzone.json'));
  const response = await globalThis.fetch(url);
  assert.equal(response.status, 200);
  await response.text();
  for (let attempt = 0; attempt < 3; attempt++) {
    const data = await read();
    assert.equal(data.system.mid, 'aa-percentage-lab-controller');
    assert.equal(data.aircons.ac1.info.uid, 'aa-percentage-lab-ac1');
    assert.equal(data.aircons.ac1.info.myZone, 1);
    assert.equal(data.aircons.ac1.zones.z02.number, 7);
    assert.deepEqual(Object.keys(data.aircons.ac1.zones).sort(), ['z01', 'z02', 'z06']);
  }
  await cli('simulator', 'start');
  assert.equal((await cli('simulator', 'status')).stdout, firstStatus);
  assert.equal((await read()).aircons.ac1.info.myZone, 1);
  assert.match((await cli('simulator', 'stop')).stdout, /simulator: stopped/);
  assert.match((await cli('simulator', 'status')).stdout, /simulator: stopped/);
});
