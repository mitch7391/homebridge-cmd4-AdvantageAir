import type { API, PlatformAccessory, Service } from 'homebridge';
import type { HomeNameResolver } from '../discovery/homeNames.js';

export function airconAccessoryName(
  resolve: HomeNameResolver | undefined, identity: string, reported: string,
  suffix: string, cached?: PlatformAccessory,
): string | undefined {
  if (!resolve) {
    return reported + suffix;
  }
  const base = resolve(identity);
  return base === undefined ? cached?.displayName : base + suffix;
}

/** Change presentation in place; never replace a service or touch its subtype/state. */
export function updateAccessoryName(
  api: API, accessory: PlatformAccessory, name: string, services: Array<[Service | undefined, string]>,
): boolean {
  let changed = accessory.displayName !== name;
  accessory.displayName = name;
  const { Name, ConfiguredName } = api.hap.Characteristic;
  const information = accessory.getService(api.hap.Service.AccessoryInformation);
  for (const [service, value] of [...services, [information, name] as const]) {
    if (!service) {
      continue;
    }
    if (service !== information && service.displayName !== value) {
      service.displayName = value;
      changed = true;
    }
    for (const characteristic of [Name, ConfiguredName]) {
      if (characteristic === ConfiguredName && !service.testCharacteristic(characteristic)) {
        continue;
      }
      if (service.getCharacteristic(characteristic).value !== value) {
        service.setCharacteristic(characteristic, value);
        changed = true;
      }
    }
  }
  return changed;
}
