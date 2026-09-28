import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import net from 'node:net';
import childProcess from 'node:child_process';
import { EventEmitter } from 'node:events';
import { syncBuiltinESMExports } from 'node:module';
import { pathToFileURL, fileURLToPath, URL } from 'node:url';
import test from 'node:test';

test('lab startup uses bounded timeout retries without adopting or killing other processes', async t => {
  const runtime = fs.mkdtempSync(path.join(os.tmpdir(), 'aa-startup-regression-'));
  const previousHome = process.env.AA_LAB_HOME;
  process.env.AA_LAB_HOME = runtime;
  t.after(() => {
    if (previousHome === undefined) {
      delete process.env.AA_LAB_HOME;
    } else {
      process.env.AA_LAB_HOME = previousHome;
    }
  });
  fs.mkdirSync(path.join(runtime, 'storage'));
  fs.writeFileSync(path.join(runtime, 'storage/config.json'), JSON.stringify({
    bridge: { port: 51889 }, plugins: ['homebridge-cmd4-advantageair'],
    platforms: [{ platform: 'AdvantageAir', devices: [{ ipAddress: '127.0.0.1', port: 52025 }] }],
  }));
  // Import the real CLI for each case; only OS/network/clock boundaries are mocked.
  const moduleUrl = pathToFileURL(fileURLToPath(new URL('../../dev/lab/lab.mjs', import.meta.url)));
  const cases = [
    ['transient header timeout', 'header-timeout', true],
    ['transient body timeout', 'body-timeout', true],
    ['persistent control timeouts expire', 'timeouts', false],
    ['worker never opens control port', 'no-listener', false],
    ['worker remains starting', 'starting', false],
    ['untracked control listener refused', 'unmanaged-control', false],
    ['unmanaged service listener refused', 'unmanaged-service', false],
    ['authentication failure is not retried', 'authentication', false],
    ['identity mismatch is not retried', 'identity', false],
  ];
  for (const [name, scenario, succeeds] of cases) {
    await t.test(name, async sub => {
      fs.rmSync(path.join(runtime, 'homebridge-control.json'), { force: true });
      const simulator = { kind: 'simulator', pid: 765, token: 'test-simulator', home: runtime };
      fs.writeFileSync(path.join(runtime, 'simulator-control.json'), JSON.stringify(simulator));
      let now = 0;
      let spawned = 0;
      let requests = 0;
      const messages = [];
      const oldArgv = process.argv;
      const oldExitCode = process.exitCode;
      process.argv = [process.execPath, 'lab.mjs', 'homebridge', 'start'];
      process.exitCode = undefined;
      sub.after(() => {
        process.argv = oldArgv;
        process.exitCode = oldExitCode;
        sub.mock.restoreAll();
        syncBuiltinESMExports();
      });
      sub.mock.method(Date, 'now', () => now);
      sub.mock.method(globalThis, 'setTimeout', (callback, ms) => {
        now += ms;
        globalThis.queueMicrotask(callback);
        return 1;
      });
      sub.mock.method(globalThis.console, 'log', message => messages.push(message));
      sub.mock.method(globalThis.console, 'error', message => messages.push(message));
      const kill = sub.mock.method(process, 'kill', () => {
        throw new Error('No PID operation is allowed.');
      });
      sub.mock.method(net, 'connect', ({ port }) => {
        const socket = new EventEmitter();
        socket.setTimeout = () => {};
        socket.destroy = () => {};
        const connected = port === 52026
          || (port === 52027 && (scenario === 'unmanaged-control' || (spawned > 0 && scenario !== 'no-listener')))
          || (port === 51889 && scenario === 'unmanaged-service');
        globalThis.queueMicrotask(() => socket.emit(connected ? 'connect' : 'error', new Error('No listener')));
        return socket;
      });
      sub.mock.method(childProcess, 'spawn', () => {
        spawned++;
        const child = new EventEmitter();
        child.pid = 4242;
        child.unref = () => {};
        globalThis.queueMicrotask(() => child.emit('spawn'));
        return child;
      });
      syncBuiltinESMExports();
      sub.mock.method(globalThis, 'fetch', async (url, options) => {
        assert.equal(options.method, 'GET', 'Startup must never send a stop request.');
        if (url.includes(':52026/')) {
          return { ok: true, json: async () => ({ ...simulator, state: 'running' }) };
        }
        requests++;
        if (scenario === 'timeouts' || (scenario === 'header-timeout' && requests === 1)) {
          now += Math.min(2000, 30000 - now);
          throw new globalThis.DOMException('Control timed out', 'TimeoutError');
        }
        if (scenario === 'body-timeout' && requests === 1) {
          return { ok: true, json: async () => {
            now += 2000;
            throw new globalThis.DOMException('Body timed out', 'AbortError');
          } };
        }
        const record = JSON.parse(fs.readFileSync(path.join(runtime, 'homebridge-control.json'), 'utf8'));
        return {
          ok: scenario !== 'authentication',
          json: async () => ({
            ...record, token: scenario === 'identity' ? 'wrong-token' : record.token,
            state: scenario === 'starting' ? 'starting' : 'running',
          }),
        };
      });
      await import(moduleUrl.href + '?startup-case=' + scenario);
      assert.equal(process.exitCode, succeeds ? undefined : 1);
      assert.equal(kill.mock.callCount(), 0);
      assert.equal(fs.existsSync(path.join(runtime, 'command.lock')), false);
      if (succeeds) {
        assert.equal(requests, 2);
        assert.equal(spawned, 1);
        assert.match(messages.join('\n'), /homebridge: running/);
        assert.ok(now < 30000);
      } else if (scenario.startsWith('unmanaged-')) {
        assert.equal(spawned, 0);
        assert.equal(requests, 0);
        assert.equal(fs.existsSync(path.join(runtime, 'homebridge-control.json')), false);
        assert.match(messages.join('\n'), /untracked|unmanaged/);
      } else if (['authentication', 'identity'].includes(scenario)) {
        assert.equal(requests, 1);
        assert.equal(spawned, 1);
        assert.match(messages.join('\n'), /authentication failed|identity mismatch/);
      } else {
        assert.equal(now, 30000, 'Retries must share a 30-second deadline, not extend it.');
        assert.equal(spawned, 1);
        assert.match(messages.join('\n'), /startup did not finish/);
      }
    });
  }
});
