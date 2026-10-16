import type { API, PlatformAccessory, Characteristic } from 'homebridge';

export interface LightOptions {
  read: (field: 'state' | 'value') => boolean | number;
  write: (field: 'state' | 'value', value: boolean | number) => void;
}
export class LightAccessory {
  private readonly readings: Array<[Characteristic, () => boolean | number]> = [];
  constructor(private readonly api: API, accessory: PlatformAccessory, dimmer: boolean, options: LightOptions) {
    const { Service, Characteristic, Perms } = api.hap;
    const service = accessory.getService(Service.Lightbulb) ?? accessory.addService(Service.Lightbulb, accessory.displayName);
    for (const field of dimmer ? ['state', 'value'] as const : ['state'] as const) {
      const characteristic = service.getCharacteristic(field === 'state' ? Characteristic.On : Characteristic.Brightness);
      const read = () => options.read(field);
      this.readings.push([characteristic, read]);
      if (field === 'value') {
        characteristic.setProps({ minValue: 0, maxValue: 100, minStep: 1 });
      }
      characteristic.setProps({ perms: [...new Set([...characteristic.props.perms, Perms.WRITE_RESPONSE])] });
      characteristic.onGet(() => {
        try {
          return read();
        } catch {
          throw this.unavailable();
        }
      }).onSet(value => {
        if (field === 'state' ? typeof value !== 'boolean'
          : typeof value !== 'number' || !Number.isInteger(value) || value < 0 || value > 100) {
          throw new api.hap.HapStatusError(api.hap.HAPStatus.INVALID_VALUE_IN_REQUEST);
        }
        try {
          options.write(field, value as boolean | number);
          return read();
        } catch {
          throw this.unavailable();
        }
      });
    }
  }
  update(): void {
    for (const [characteristic, read] of this.readings) {
      try {
        characteristic.updateValue(read());
      } catch {
        characteristic.updateValue(this.unavailable());
      }
    }
  }
  private unavailable(): Error {
    return new this.api.hap.HapStatusError(this.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
  }
}
