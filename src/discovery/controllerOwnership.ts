import type { API } from 'homebridge';
import type { SystemData } from '../api/systemData.js';

export class DuplicateControllerError extends Error {
  constructor() {
    super('This controller identity is already managed by another configured address.');
    this.name = 'DuplicateControllerError';
  }
}
const owners = new WeakMap<API, Map<string, object>>();
export function claimController(api: API, data: SystemData, owner: object): void {
  const mid = data.system.mid;
  if (typeof mid !== 'string' || !mid.trim()) {
    throw new Error('Controller identity is missing.');
  }
  let map = owners.get(api);
  if (!map) {
    map = new Map();
    owners.set(api, map);
  }
  if (map.has(mid.trim()) && map.get(mid.trim()) !== owner) {
    throw new DuplicateControllerError();
  }
  map.set(mid.trim(), owner);
}
