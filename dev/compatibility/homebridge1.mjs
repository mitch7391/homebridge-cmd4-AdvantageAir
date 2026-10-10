import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';
import process from 'node:process';
import console from 'node:console';
import crypto from 'node:crypto';
import { spawn, execFileSync } from 'node:child_process';
import { setTimeout as wait } from 'node:timers/promises';
import { fileURLToPath, URL } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const { fetch, AbortSignal } = globalThis;
assert.equal(process.versions.node.split('.')[0], '22', 'Use Node 22 for this campaign.');
assert.equal(process.platform, 'linux', 'Run this isolated campaign in Linux/Codespaces.');
assert.ok(process.env.npm_execpath, 'Run npm run check:homebridge1 -- /absolute/package.tgz');
assert.equal(process.argv.length, 3, 'Supply exactly one validated plugin tarball.');
const archive = path.resolve(process.argv[2]);
const home = fs.mkdtempSync(path.join(os.tmpdir(), 'aa-homebridge1-'));
const storage = path.join(home, 'storage');
fs.mkdirSync(storage);
const name = 'homebridge-cmd4-advantageair';
const pin = '031-45-154'; // Disposable, unpaired, loopback-only test bridge.
const report = { node: process.version, homebridge: '1.8.5', archive,
  archiveSha256: crypto.createHash('sha256').update(fs.readFileSync(archive)).digest('hex'), checks: [], status: 'running' };
const children = [];
let hb;
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const run = (command, args, cwd = home) => execFileSync(command, args, { cwd, stdio: 'inherit' });
const capture = (command, args, target) => {
  const fd = fs.openSync(target, 'w');
  try {
    execFileSync(command, args, { cwd: home, stdio: ['ignore', fd, 'inherit'] });
  } finally {
    fs.closeSync(fd);
  }
};
const mark = message => {
  report.checks.push(message); console.log('PASS:', message);
};
const until = async (description, check) => {
  const deadline = Date.now() + 30000;
  let last;
  while (Date.now() < deadline) {
    for (const child of children) {
      assert.ok(child.stopping || child.exitCode === null && child.signalCode === null, `Child exited; see ${child.log}`);
    }
    try {
      const result = await check();
      if (result) {
        return result;
      }
    } catch (error) {
      last = error;
    }
    await wait(200);
  }
  throw new Error(`${description} timed out${last ? ': ' + last.message : ''}`);
};
const freePort = async () => {
  const server = net.createServer();
  await new Promise((resolve, reject) => {
    server.once('error', reject); server.listen(0, '127.0.0.1', resolve);
  });
  const port = server.address().port;
  await new Promise(resolve => server.close(resolve));
  return port;
};
const launch = (args, log, env = process.env) => {
  const fd = fs.openSync(log, 'a');
  const child = spawn(process.execPath, args, { cwd: home, env, stdio: ['ignore', fd, fd] });
  fs.closeSync(fd);
  child.log = log;
  child.on('error', error => {
    report.processError = error.message;
  });
  children.push(child);
  return child;
};
const stop = async child => {
  child.stopping = true;
  if (child.exitCode !== null || child.signalCode !== null) {
    return;
  }
  child.kill('SIGTERM');
  for (let i = 0; i < 100 && child.exitCode === null && child.signalCode === null; i++) {
    await wait(100);
  }
  if (child.exitCode === null && child.signalCode === null) {
    child.kill('SIGKILL');
    throw new Error(`Graceful shutdown timed out; see ${child.log}`);
  }
  assert.ok(child.exitCode === 0 || child.exitCode === 143 || !child.homebridge && child.signalCode === 'SIGTERM',
    `Unclean exit ${child.exitCode}/${child.signalCode}; see ${child.log}`);
};

try {
  // Inspect only the supplied tarball; no linking to the repository plugin/dev Homebridge.
  const membersFile = path.join(home, 'archive-members.txt');
  capture('tar', ['-tzf', archive], membersFile);
  const members = fs.readFileSync(membersFile, 'utf8').trim().split('\n');
  assert.equal(members.length, 119, 'Expected the validated current v4 package.');
  assert.equal(new Set(members).size, members.length);
  assert.ok(members.every(file => file.startsWith('package/') && !file.split('/').includes('..')));
  run('tar', ['-xzf', archive, '-C', home]);
  const pkg = read(path.join(home, 'package/package.json'));
  assert.equal(pkg.name, name);
  assert.equal(pkg.version, read(path.join(root, 'package.json')).version);
  assert.equal(pkg.private, true);
  report.plugin = pkg.version;
  fs.writeFileSync(path.join(home, 'package.json'), '{"name":"aa-hb1-consumer","private":true}\n');
  run(process.execPath, [process.env.npm_execpath, 'install', '--save-exact', '--omit=dev', '--no-audit', '--no-fund',
    '--package-lock=false', 'homebridge@1.8.5', archive]);
  const installed = path.join(home, 'node_modules', name);
  assert.equal(fs.lstatSync(installed).isSymbolicLink(), false);
  assert.equal(read(path.join(home, 'node_modules/homebridge/package.json')).version, '1.8.5');
  for (const member of members) {
    assert.deepEqual(fs.readFileSync(path.join(home, member)), fs.readFileSync(path.join(installed, member.slice(8))), member);
  }
  mark('Homebridge 1.8.5 installed with the actual tarball; all 119 installed plugin files match.');
  const simPort = await freePort();
  let hapPort = await freePort();
  while (hapPort === simPort) {
    hapPort = await freePort();
  }
  const sim = `http://127.0.0.1:${simPort}`;
  const request = async (url, options = {}) => {
    const response = await fetch(url, { ...options, signal: AbortSignal.timeout(3000) });
    assert.ok(response.ok, `${options.method ?? 'GET'} ${url}: HTTP ${response.status}`);
    const text = await response.text();
    return text ? JSON.parse(text) : undefined;
  };
  launch([path.join(root, 'dev/lab/AirConServer.cjs')], path.join(home, 'simulator.log'), { ...process.env, PORT: String(simPort) });
  await until('Simulator startup', async () => (await fetch(sim + '/reInit')).ok);
  const load = new URL(sim + '/');
  load.searchParams.set('load', path.join(root, 'dev/lab/fixtures/myzone.json'));
  assert.ok((await fetch(load)).ok);
  const state = async () => (await request(sim + '/getSystemData')).aircons.ac1;
  assert.equal((await state()).info.myZone, 1);
  const config = { bridge: { name: 'AA HB1 compatibility', username: '0E:22:18:05:00:01', port: hapPort,
    pin, bind: ['127.0.0.1'], advertiser: 'ciao' }, plugins: [name], accessories: [], platforms: [
    { platform: 'cmd4AdvantageAir', name: 'Legacy compatibility' },
    { platform: 'AdvantageAir', name: 'Native compatibility', debug: true,
      devices: [{ name: 'Simulator', homeName: 'Aircon', ipAddress: '127.0.0.1', port: simPort, debug: false }] },
  ] };
  fs.writeFileSync(path.join(storage, 'config.json'), JSON.stringify(config, null, 2));
  const schema = read(path.join(installed, 'config.schema.json'));
  assert.equal(schema.pluginAlias, 'AdvantageAir');
  assert.ok(schema.schema.properties.devices.items.properties.homeName);
  const hap = (suffix, options = {}) => request(`http://127.0.0.1:${hapPort}${suffix}`, {
    ...options, headers: { Authorization: pin, 'Content-Type': 'application/hap+json' },
  });
  const start = async label => {
    hb = launch([path.join(home, 'node_modules/homebridge/bin/homebridge'), '-U', storage,
      '-P', path.join(home, 'node_modules'), '--strict-plugin-resolution', '-I', '-Q'], path.join(home, `${label}.log`));
    hb.homebridge = true;
    return until('Homebridge discovery', async () => {
      const data = await hap('/accessories');
      return data.accessories.length === 11 && data.accessories;
    });
  };
  const short = type => type.replace(/-0000-1000-8000-0026BB765291$/i, '').replace(/^0+/, '').toUpperCase();
  const characteristic = (service, type) => service.characteristics.find(c => short(c.type) === type);
  const select = (accessories, accessoryName, serviceType, serviceName) => {
    const matching = accessories.filter(a => a.services.some(s => short(s.type) === '3E' && characteristic(s, '23')?.value === accessoryName));
    assert.equal(matching.length, 1, `Accessory ${accessoryName}`);
    const a = matching[0];
    const services = a.services.filter(s => short(s.type) === serviceType && (!serviceName || characteristic(s, '23')?.value === serviceName));
    assert.equal(services.length, 1, `Service ${accessoryName}/${serviceName ?? serviceType}`);
    return { aid: a.aid, service: services[0] };
  };
  const get = async (control, type) => {
    const c = characteristic(control.service, type);
    assert.ok(c, `Missing characteristic ${type}`);
    const data = await hap(`/characteristics?id=${control.aid}.${c.iid}`);
    assert.equal(data.characteristics[0].status ?? 0, 0);
    return data.characteristics[0].value;
  };
  const put = async (control, type, value) => {
    const c = characteristic(control.service, type);
    assert.ok(c, `Missing characteristic ${type}`);
    const result = await hap('/characteristics', { method: 'PUT', body: JSON.stringify({ characteristics: [{ aid: control.aid, iid: c.iid, value }] }) });
    assert.ok(!result || result.characteristics.every(item => (item.status ?? 0) === 0), 'HAP write refused');
  };
  const first = await start('first-start');
  const thermostat = select(first, 'Aircon', '4A');
  const speed = select(first, 'Aircon', '40');
  const zone = select(first, 'Bedroom Reference Zone', '49');
  const sensor = select(first, 'Living Reference Temperature', '8A');
  const percentage = select(first, 'Percentage Test Zone', '43');
  const vent = select(first, 'Aircon Fan', '40');
  const dry = select(first, 'Aircon Dry Mode', '40');
  const timer = select(first, 'Aircon Timer', 'D0');
  const myzone = select(first, 'Aircon MyZone', '49', 'Bedroom Reference MyZone');
  assert.ok(thermostat.service.linked?.includes(speed.service.iid), 'FanSpeed must remain linked to the thermostat.');
  mark('Actual Homebridge startup discovered all 10 native accessories and both platform aliases.');
  assert.ok(Number.isFinite(await get(thermostat, '11')));
  assert.ok(Number.isFinite(await get(sensor, '11')));
  await put(thermostat, '33', 1);
  await until('Thermostat heat', async () => {
    const s = await state(); return s.info.state === 'on' && s.info.mode === 'heat';
  });
  await put(thermostat, '35', 25);
  await until('Target temperature', async () => (await state()).info.setTemp === 25);
  mark('Thermostat current temperature, Heat and target temperature; temperature sensor read.');
  await put(speed, '29', 75);
  await until('Linked FanSpeed', async () => (await state()).info.fan === 'high');
  await put(zone, '25', true);
  await until('Temperature-zone switch', async () => (await state()).zones.z02.state === 'open');
  assert.ok([true, 1].includes(await get(zone, '25')), 'Expected HAP On=true or 1');
  await put(percentage, '8', 60);
  await until('Percentage brightness', async () => (await state()).zones.z06.value === 60);
  assert.equal(await get(percentage, '8'), 60);
  await put(percentage, '25', false);
  await until('Percentage Off', async () => (await state()).zones.z06.state === 'close');
  mark('Linked FanSpeed, zone Switch and percentage Lightbulb controls.');
  for (const [control, mode] of [[vent, 'vent'], [dry, 'dry']]) {
    await put(control, '25', true);
    await until(mode, async () => {
      const s = await state(); return s.info.mode === mode && s.info.state === 'on';
    });
    assert.ok([true, 1].includes(await get(control, '25')), 'Expected HAP On=true or 1');
    assert.ok(Number.isFinite(await get(control, '29')));
  }
  mark('Ventilation and Dry mode fans.');
  await put(timer, 'D3', 2700);
  assert.equal(await get(timer, 'D3'), 2700);
  await put(timer, 'B0', 1);
  await until('Timer activation', async () => (await state()).info.countDownToOff > 0);
  await put(timer, 'B0', 0);
  await until('Timer cancellation', async () => (await state()).info.countDownToOff === 0);
  await put(myzone, '25', true);
  await until('MyZone selection', async () => (await state()).info.myZone === 7);
  assert.ok([true, 1].includes(await get(myzone, '25')), 'Expected HAP On=true or 1');
  mark('Timer duration/activation/cancellation and fixture MyZone selection.');
  const topology = accessories => accessories.map(a => ({ aid: a.aid, services: a.services.map(s => ({ iid: s.iid, type: s.type,
    linked: s.linked ?? [], characteristics: s.characteristics.map(c => ({ iid: c.iid, type: c.type })) })) }));
  await stop(hb);
  const cacheFile = path.join(storage, 'accessories/cachedAccessories');
  const beforeCache = read(cacheFile);
  assert.equal(beforeCache.length, 10);
  const identity = cache => cache.map(a => ({ uuid: a.UUID, services: a.services.map(s => ({ uuid: s.UUID, subtype: s.subtype })) }))
    .sort((a, b) => a.uuid.localeCompare(b.uuid));
  assert.equal(new Set(beforeCache.map(a => a.UUID)).size, 10);
  const restored = await start('cached-restart');
  assert.deepEqual(topology(restored), topology(first));
  const restoredTimer = select(restored, 'Aircon Timer', 'D0');
  await until('Restored controls ready', async () => (await get(restoredTimer, 'D3')) === 2700);
  assert.ok(Number.isFinite(await get(select(restored, 'Aircon', '4A'), '11')));
  await stop(hb);
  assert.deepEqual(identity(read(cacheFile)), identity(beforeCache));
  for (const label of ['first-start', 'cached-restart']) {
    const log = fs.readFileSync(path.join(home, `${label}.log`), 'utf8');
    assert.match(log, /Legacy cmd4AdvantageAir compatibility only/);
    assert.match(log, /Registering platform.*AdvantageAir/);
    assert.doesNotMatch(log, /TypeError|ReferenceError|Cannot find module|ERR_MODULE_NOT_FOUND/);
  }
  report.accessoryIdentity = identity(beforeCache);
  mark('Clean shutdown/restart: same 10 UUIDs, service subtypes, HAP AIDs/IIDs and retained 45-minute Timer duration.');
  report.status = 'passed';
} catch (error) {
  report.status = 'failed';
  report.error = error.stack;
  throw error;
} finally {
  for (const child of children.reverse()) {
    try {
      await stop(child);
    } catch (error) {
      report.status = 'failed';
      report.cleanupError = error.message;
      process.exitCode = 1;
    }
  }
  fs.writeFileSync(path.join(home, 'evidence.json'), JSON.stringify(report, null, 2));
  console.log(`Compatibility evidence (${report.status}): ${home}`);
}
