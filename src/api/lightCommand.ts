import type { JsonObject, SystemData } from './systemData.js';
import { ZoneCommandError } from './zoneCommand.js';

export class LightCommandError extends ZoneCommandError {}
export interface LightObservation {
  id: string;
  identity: string;
  name: string;
  on: boolean;
  capability: 'relay' | 'dimmer' | 'unknown';
  brightness?: number;
}
const object = (value: unknown): value is JsonObject =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

export function lightId(value: unknown): string {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{1,64}$/.test(value)) {
    throw new LightCommandError('Invalid light ID.');
  }
  return value;
}

export function lightBrightness(value: unknown): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0 || value > 100) {
    throw new LightCommandError('Invalid light brightness.');
  }
  return value;
}

export function lightPayload(id: string, field: 'state' | 'value', value: boolean | number): string {
  lightId(id);
  if (field === 'state' && typeof value === 'boolean') {
    return `{id:"${id}",state:${value ? 'on' : 'off'}}`;
  }
  if (field === 'value') {
    return `{id:"${id}",value:${lightBrightness(value)}}`;
  }
  throw new LightCommandError('Invalid light command.');
}

/** Invalid entries are isolated; absent collections never mean an observed Off. */
export function observeLights(data: SystemData, warn: (message: string) => void = () => {}): LightObservation[] {
  const collection = object(data.myLights) ? data.myLights.lights : undefined;
  if (!object(collection)) {
    return [];
  }
  const mid = data.system.mid;
  if (typeof mid !== 'string' || !mid.trim()) {
    return [];
  }
  const result: LightObservation[] = [];
  for (const [key, raw] of Object.entries(collection)) {
    try {
      lightId(key);
      if (!object(raw) || raw.id !== key || (raw.state !== 'on' && raw.state !== 'off')) {
        throw new LightCommandError('Invalid light identity or state.');
      }
      if (raw.relay !== undefined && typeof raw.relay !== 'boolean') {
        throw new LightCommandError('Invalid relay capability.');
      }
      const brightness = raw.value === undefined || raw.value === null ? undefined : lightBrightness(raw.value);
      if (raw.relay === true && brightness !== undefined) {
        throw new LightCommandError('Contradictory relay/dimmer capability.');
      }
      result.push({ id: key, identity: JSON.stringify(['AdvantageAir', mid.trim(), 'light', key]),
        name: typeof raw.name === 'string' && raw.name.trim() ? raw.name.trim() : `Light ${key}`,
        on: raw.state === 'on', brightness,
        capability: raw.relay === true ? 'relay' : brightness === undefined ? 'unknown' : 'dimmer' });
    } catch {
      warn(`Ignoring malformed light entry ${key}.`);
    }
  }
  return result;
}
