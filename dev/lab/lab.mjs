import fs from 'node:fs';
import process from 'node:process';
import path from 'node:path';
import net from 'node:net';
import crypto from 'node:crypto';
import { spawn } from 'node:child_process';
import { directory, repository, home, components, readRecord, recordPath, wait, validateConfig } from './paths.mjs';
import { followLog } from './logs.mjs';

const args = process.argv.slice(2);
const { console, fetch, AbortSignal } = globalThis;
if (args[0] === 'logs') {
  const component = args[1] ?? 'homebridge';
  try {
    if (args.length > 2 || !['homebridge', 'simulator'].includes(component)) {
      throw new Error('Usage: lab.cmd logs [homebridge|simulator]');
    }
    await followLog(path.join(home, `${component}.log`));
    process.exit(0);
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}
const kind = args.length === 1 ? 'lab' : args[0];
const action = args.length === 1 ? args[0] : args[1];
if (!['lab', 'simulator', 'homebridge'].includes(kind) || !['start', 'stop', 'status'].includes(action) || args.length > 2) {
  console.error('Usage: lab.cmd [simulator|homebridge] start|stop|status');
  process.exit(1);
}

async function control(component, record, operation) {
  const response = await fetch(`http://127.0.0.1:${components[component].control}/${operation}`, {
    method: operation === 'stop' ? 'POST' : 'GET', headers: { Authorization: `Bearer ${record.token}` },
    signal: AbortSignal.timeout(2000),
  });
  if (!response.ok) {
    throw new Error(`${component}: control authentication failed; nothing was stopped.`);
  }
  const data = await response.json();
  if (data.kind !== component || data.token !== record.token || data.home !== home || data.pid !== record.pid) {
    throw new Error(`${component}: process identity mismatch; nothing was stopped.`);
  }
  return data;
}

async function listening(port) {
  return new Promise(resolve => {
    const socket = net.connect({ host: '127.0.0.1', port });
    socket.setTimeout(500);
    socket.once('connect', () => {
      socket.destroy(); resolve(true); 
    });
    socket.once('error', () => {
      socket.destroy(); resolve(false); 
    });
    socket.once('timeout', () => {
      socket.destroy(); resolve(true); 
    });
  });
}

async function status(component) {
  const record = readRecord(component);
  if (await listening(components[component].control)) {
    if (!record) {
      throw new Error(`${component}: untracked control-port listener; refusing to manage it.`);
    }
    return control(component, record, 'status');
  }
  if (await listening(components[component].port)) {
    throw new Error(`${component}: port ${components[component].port} is occupied by an unmanaged process; no PID will be killed.`);
  }
  return { state: 'stopped' };
}

async function start(component) {
  const existing = await status(component);
  if (existing.state !== 'stopped') {
    console.log(`${component}: ${existing.state} (PID ${existing.pid})`);
    return;
  }
  validateConfig();
  if (component === 'homebridge' && (await status('simulator')).state !== 'running') {
    throw new Error('Start the simulator first, or use lab:start.');
  }
  const token = crypto.randomBytes(32).toString('hex');
  const out = fs.openSync(path.join(home, `${component}.log`), 'a');
  const err = fs.openSync(path.join(home, `${component}-error.log`), 'a');
  const child = spawn(process.execPath, [path.join(directory, 'worker.mjs'), component, token], {
    cwd: repository, detached: true, windowsHide: true, stdio: ['ignore', out, err],
    env: { ...process.env, AA_LAB_HOME: home },
  });
  fs.closeSync(out);
  fs.closeSync(err);
  await new Promise((resolve, reject) => {
    child.once('spawn', resolve); child.once('error', reject); 
  });
  const record = { token, pid: child.pid, home, kind: component };
  fs.writeFileSync(recordPath(component), JSON.stringify(record, null, 2), { mode: 0o600 });
  child.unref();
  for (let attempt = 0; attempt < 60; attempt++) {
    await wait(500);
    if (await listening(components[component].control)) {
      const current = await control(component, record, 'status');
      if (current.state === 'running') {
        console.log(`${component}: running (PID ${current.pid}, port ${components[component].port})`);
        return;
      }
    }
  }
  throw new Error(`${component}: startup did not finish; inspect ${home}/${component}-error.log and run status.`);
}

async function stop(component) {
  const current = await status(component);
  if (current.state === 'stopped') {
    console.log(`${component}: stopped`);
    return;
  }
  const record = readRecord(component);
  // Verify authenticated identity before issuing the shutdown request.
  await control(component, record, 'status');
  await control(component, record, 'stop');
  for (let attempt = 0; attempt < 40; attempt++) {
    await wait(250);
    if (!await listening(components[component].control) && !await listening(components[component].port)) {
      console.log(`${component}: stopped`);
      return;
    }
  }
  throw new Error(`${component}: shutdown is still pending; inspect its log. No forced PID kill was attempted.`);
}

// Serialize commands; a crashed command's lock is recovered only when its owner no longer exists.
fs.mkdirSync(home, { recursive: true });
const lock = path.join(home, 'command.lock');
let ownsLock = false;
try {
  if (fs.existsSync(lock)) {
    const owner = Number(fs.readFileSync(lock, 'utf8'));
    let alive = true;
    try {
      process.kill(owner, 0); 
    } catch (error) {
      if (error.code === 'ESRCH') {
        alive = false; 
      } 
    }
    if (alive) {
      throw new Error('Another lab command is active; retry after it finishes.');
    }
    fs.unlinkSync(lock);
  }
  fs.writeFileSync(lock, String(process.pid), { flag: 'wx' });
  ownsLock = true;
  const order = kind === 'lab' ? (action === 'stop' ? ['homebridge', 'simulator'] : ['simulator', 'homebridge']) : [kind];
  for (const component of order) {
    if (action === 'start') {
      await start(component);
    } else if (action === 'stop') {
      await stop(component);
    } else {
      const result = await status(component);
      console.log(`${component}: ${result.state}${result.pid ? ` (PID ${result.pid})` : ''}`);
    }
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  if (ownsLock) {
    fs.unlinkSync(lock);
  }
}
