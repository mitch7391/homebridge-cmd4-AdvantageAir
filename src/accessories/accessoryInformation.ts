import { createRequire } from 'node:module';
import { Buffer } from 'node:buffer';
import type { API, PlatformAccessory } from 'homebridge';

const { version } = createRequire(import.meta.url)('../../package.json') as { version: string };

/** Update descriptive metadata only; the existing UUID and services retain their identity. */
export function updateAccessoryInformation(
  api: API,
  accessory: PlatformAccessory,
  sysType: unknown,
  persist = false,
): boolean {
  const information = accessory.getService(api.hap.Service.AccessoryInformation)!;
  const characteristic = api.hap.Characteristic;
  const values = [
    [characteristic.Manufacturer, 'Advantage Air'],
    [characteristic.SerialNumber, 'AA-' + accessory.UUID.replace(/-/g, '')],
    [characteristic.FirmwareRevision, version],
    [characteristic.Name, accessory.displayName],
  ] as const;
  let changed = false;
  for (const [type, value] of values) {
    const field = information.getCharacteristic(type);
    if (field.value !== value) {
      field.updateValue(value);
      changed = true;
    }
  }
  const model = information.getCharacteristic(characteristic.Model);
  // Do not trim, reinterpret or truncate the controller's reported family.
  // Missing/invalid values retain the existing model, including a cached valid one.
  if (typeof sysType === 'string' && sysType.trim().length > 0
    && !/\p{Cc}/u.test(sysType) && Buffer.byteLength(sysType, 'utf8') <= (model.props.maxLen ?? 64)
    && model.value !== sysType) {
    model.updateValue(sysType);
    changed = true;
  }
  if (changed && persist) {
    api.updatePlatformAccessories([accessory]);
  }
  return changed;
}
