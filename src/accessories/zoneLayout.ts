import type { API, PlatformAccessory, Service } from 'homebridge';

export type ZoneControlType = 'switch-light' | 'lights' | 'fans';

/** Omitted settings preserve the Beta 2 layout. Reject typos rather than rearranging Home. */
export function zoneLayout(device: Record<string, unknown>): { type: ZoneControlType; linkTemperatures: boolean } {
  const type = device.zoneControlType === undefined ? 'switch-light' : device.zoneControlType;
  if (type !== 'switch-light' && type !== 'lights' && type !== 'fans') {
    throw new Error('Zone Control Type must be switch-light, lights or fans.');
  }
  if (device.linkZoneTemperatures !== undefined && typeof device.linkZoneTemperatures !== 'boolean') {
    throw new Error('Link temperatures to zone controls must be true or false.');
  }
  return { type, linkTemperatures: device.linkZoneTemperatures === true };
}

/** Cache restoration uses the saved presentation until controller identity is verified. */
export function cachedZoneControlType(accessory: PlatformAccessory): ZoneControlType {
  const type = accessory.context.advantageAirZoneControlType;
  return type === 'lights' || type === 'fans' ? type : 'switch-light';
}

/** Only call for this plugin's zone-control accessories, never thermostat/mode fans or lights. */
export function zoneControlService(api: API, accessory: PlatformAccessory, type: ZoneControlType, percentage: boolean): Service {
  const { Switch, Lightbulb, Fan } = api.hap.Service;
  const wanted = type === 'fans' ? Fan : percentage || type === 'lights' ? Lightbulb : Switch;
  for (const kind of [Switch, Lightbulb, Fan]) {
    const old = accessory.getService(kind);
    if (kind !== wanted && old) {
      accessory.removeService(old);
    }
  }
  return accessory.getService(wanted) ?? accessory.addService(wanted, accessory.displayName);
}
