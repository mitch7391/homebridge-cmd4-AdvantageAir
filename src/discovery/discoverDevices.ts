import type { SystemData } from '../api/systemData.js';

export interface DiscoveredAircon {
  kind: 'aircon';
  identity: string;
  airconKey: string;
  name: string;
}

export interface DiscoveredZone {
  kind: 'zone';
  identity: string;
  airconKey: string;
  zoneKey: string;
  name: string;
}

export type DiscoveredDevice = DiscoveredAircon | DiscoveredZone;

function requireIdentifier(value: unknown, description: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`Discovery requires a valid ${description}.`);
  }

  return value.trim();
}

function displayName(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim()
    ? value.trim()
    : fallback;
}

export function discoverDevices(data: SystemData): DiscoveredDevice[] {
  const entries = Object.entries(data.aircons);

  if (entries.length === 0) {
    return [];
  }

  const controllerId = requireIdentifier(data.system.mid, 'controller ID');
  const airconIds = new Set<string>();
  const devices: DiscoveredDevice[] = [];

  for (const [airconKey, aircon] of entries) {
    const airconId = requireIdentifier(aircon.info.uid, 'air conditioner ID');

    if (airconIds.has(airconId)) {
      throw new Error('Discovery found duplicate air conditioner IDs.');
    }

    airconIds.add(airconId);

    devices.push({
      kind: 'aircon',
      identity: JSON.stringify(['AdvantageAir', controllerId, airconId, 'aircon']),
      airconKey,
      name: displayName(aircon.info.name, airconKey),
    });

    for (const [zoneKey, zone] of Object.entries(aircon.zones)) {
      devices.push({
        kind: 'zone',
        identity: JSON.stringify([
          'AdvantageAir',
          controllerId,
          airconId,
          'zone',
          zoneKey,
        ]),
        airconKey,
        zoneKey,
        name: displayName(zone.name, zoneKey),
      });
    }
  }

  return devices;
}
