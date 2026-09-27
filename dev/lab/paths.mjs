import fs from 'node:fs';
import process from 'node:process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const directory = path.dirname(fileURLToPath(import.meta.url));
export const repository = path.resolve(directory, '../..');
const local = path.join(directory, 'local.json');
export const home = path.resolve(repository, process.env.AA_LAB_HOME
  || (fs.existsSync(local) ? JSON.parse(fs.readFileSync(local, 'utf8')).runtimeDirectory : '../advantage-air-lab'));
export const storage = path.join(home, 'storage');
export const components = { simulator: { port: 52025, control: 52026 }, homebridge: { port: 51889, control: 52027 } };
export const recordPath = kind => path.join(home, `${kind}-control.json`);
export const readRecord = kind => fs.existsSync(recordPath(kind)) ? JSON.parse(fs.readFileSync(recordPath(kind), 'utf8')) : undefined;
export const wait = ms => new Promise(resolve => globalThis.setTimeout(resolve, ms));

export function validateConfig() {
  const config = JSON.parse(fs.readFileSync(path.join(storage, 'config.json'), 'utf8'));
  const devices = config.platforms?.[0]?.devices;
  if (config.platforms?.length !== 1 || config.platforms[0].platform !== 'AdvantageAir'
    || devices?.length !== 1 || devices[0].ipAddress !== '127.0.0.1' || devices[0].port !== 52025
    || config.bridge?.port !== 51889 || config.plugins?.length !== 1 || config.plugins[0] !== 'homebridge-cmd4-advantageair') {
    throw new Error('Lab config must use only the loopback simulator and isolated bridge port 51889.');
  }
  return config;
}
