import fs from 'node:fs';
import process from 'node:process';
import path from 'node:path';
import http from 'node:http';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { directory, repository, home, storage, components, readRecord, recordPath, wait, validateConfig } from './paths.mjs';

const [kind, token] = process.argv.slice(2);
const { console, fetch, AbortSignal, setImmediate, URL } = globalThis;
if (!Object.hasOwn(components, kind) || !/^[a-f0-9]{64}$/.test(token ?? '')) {
  throw new Error('Worker must be started by lab.mjs.');
}
const config = validateConfig();
let state = 'starting';
let stopping = false;
let simulator;
const identity = () => ({ kind, token, pid: process.pid, home, state });
const control = http.createServer((request, response) => {
  if (request.headers.authorization !== `Bearer ${token}`) {
    response.writeHead(403).end();
    return;
  }
  if ((request.method !== 'GET' || request.url !== '/status') && (request.method !== 'POST' || request.url !== '/stop')) {
    response.writeHead(404).end();
    return;
  }
  response.setHeader('Content-Type', 'application/json');
  response.end(JSON.stringify(identity()));
  if (request.url === '/stop' && !stopping) {
    stopping = true;
    state = 'stopping';
    setImmediate(async () => {
      try {
        if (kind === 'simulator') {
          await new Promise((resolve, reject) => simulator.close(error => error ? reject(error) : resolve()));
        }
        control.close();
        if (kind === 'homebridge') {
          process.emit('SIGINT'); // Homebridge's own teardown handler, inside its process (works on Windows).
        }
      } catch (error) {
        console.error('Shutdown did not complete:', error);
        state = 'shutdown-error';
        stopping = false;
      }
    });
  }
});
await new Promise((resolve, reject) => {
  control.once('error', reject);
  control.listen(components[kind].control, '127.0.0.1', resolve);
});
process.once('exit', () => {
  if (readRecord(kind)?.token === token) {
    fs.unlinkSync(recordPath(kind));
  }
});
console.log(`\n[LAB ${new Date().toISOString()}] ${kind} starting; storage preserved at ${storage}`);
try {
  if (kind === 'simulator') {
    process.env.PORT = '52025';
    process.argv = [process.execPath, path.join(directory, 'AirConServer.cjs')];
    simulator = await createRequire(import.meta.url)('./AirConServer.cjs');
    for (let attempt = 0; ; attempt++) {
      try {
        const url = new URL('http://127.0.0.1:52025/');
        url.searchParams.set('load', path.join(directory, 'fixtures/percentage.json'));
        const response = await fetch(url, { signal: AbortSignal.timeout(1000) });
        if (!response.ok) {
          throw new Error('Fixture load failed');
        }
        await response.text();
        break;
      } catch (error) {
        if (attempt >= 15) {
          throw error;
        }
        await wait(250);
      }
    }
  } else {
    await import('./diagnostics.mjs');
    const cli = path.join(repository, 'node_modules/homebridge/bin/homebridge.js');
    process.argv = [process.execPath, cli, '-U', storage, '-P', repository, '--strict-plugin-resolution', '-D', '-Q'];
    await import(pathToFileURL(cli).href);
    for (let attempt = 0; ; attempt++) {
      try {
        const response = await fetch(`http://${config.bridge.bind[0]}:51889/accessories`, { signal: AbortSignal.timeout(1000) });
        if (response.status !== 470) {
          throw new Error('Expected paired HomeKit authentication');
        }
        break;
      } catch (error) {
        if (attempt >= 60) {
          throw error;
        }
        await wait(250);
      }
    }
  }
  state = 'running';
  console.log(`[LAB ${new Date().toISOString()}] ${kind} ready`);
} catch (error) {
  console.error(error);
  process.exit(1);
}
