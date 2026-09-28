import type { API, Characteristic, PlatformAccessory } from 'homebridge';
import { MyZoneCommandError } from '../api/myZoneCommand.js';
import { ZoneCommandError } from '../api/zoneCommand.js';

export interface MyZoneOptions {
  getOn: (identity: string) => boolean;
  select: (identity: string) => void;
  warn: (message: string) => void;
}

/** One accessory containing independently named reference-selection switches. */
export class MyZoneAccessory {
  private readonly readings = new Map<string, [Characteristic, () => boolean]>();

  constructor(
    private readonly api: API,
    private readonly accessory: PlatformAccessory,
    private readonly options: MyZoneOptions,
  ) {
    MyZoneAccessory.prepareCachedAccessory(api, accessory);
  }

  static prepareCachedAccessory(api: API, accessory: PlatformAccessory): void {
    if (accessory.context.advantageAirMyZone !== true) {
      return;
    }
    const unavailable = () => {
      throw new api.hap.HapStatusError(api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
    };
    for (const service of accessory.services) {
      if (service.UUID === api.hap.Service.Switch.UUID) {
        service.getCharacteristic(api.hap.Characteristic.On)
          .onGet(unavailable).onSet(unavailable)
          .updateValue(new api.hap.HapStatusError(api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE));
      }
    }
  }

  /** Returns true only when a new service was added to the accessory. */
  addZone(identity: string, name: string): boolean {
    if (this.readings.has(identity)) {
      return false;
    }
    const { Service, Characteristic, Perms } = this.api.hap;
    const subtype = this.api.hap.uuid.generate(JSON.stringify([identity, 'myzone-selection']));
    const cached = this.accessory.getServiceById(Service.Switch, subtype);
    const service = cached ?? this.accessory.addService(Service.Switch, `${name} MyZone`, subtype);
    if (!cached) {
      service.setCharacteristic(Characteristic.Name, `${name} MyZone`);
      service.addOptionalCharacteristic(Characteristic.ConfiguredName);
      service.setCharacteristic(Characteristic.ConfiguredName, `${name} MyZone`);
    }
    const on = service.getCharacteristic(Characteristic.On);
    const read = () => {
      const value = this.options.getOn(identity);
      if (typeof value !== 'boolean') {
        throw new MyZoneCommandError('The MyZone selection is unavailable.');
      }
      return value;
    };
    on.setProps({ perms: [...new Set([...on.props.perms, Perms.WRITE_RESPONSE])] }).onGet(() => {
      try {
        return read();
      } catch {
        throw this.unavailable();
      }
    }).onSet(value => {
      if (typeof value !== 'boolean') {
        throw new this.api.hap.HapStatusError(this.api.hap.HAPStatus.INVALID_VALUE_IN_REQUEST);
      }
      try {
        const selected = read();
        if (value) {
          this.options.select(identity);
        } else if (selected) {
          this.warn(`MyZone Off refused for "${service.displayName}": select another reference zone; MyZone cannot be disabled.`);
        }
        // Publish the other switches immediately; the coordinator owns desired/observed state.
        this.update();
        return read();
      } catch (error) {
        const reason = error instanceof ZoneCommandError ? error.message : 'The MyZone request could not be accepted.';
        this.warn(`MyZone command refused for "${service.displayName}": ${reason}`);
        throw this.unavailable();
      }
    });
    this.readings.set(identity, [on, read]);
    return !cached;
  }

  update(): void {
    for (const [characteristic, read] of this.readings.values()) {
      try {
        characteristic.updateValue(read());
      } catch {
        characteristic.updateValue(this.unavailable());
      }
    }
  }

  private warn(message: string): void {
    try {
      this.options.warn(message);
    } catch {
      // Logging must not change admission or the HomeKit response.
    }
  }

  private unavailable(): Error {
    return new this.api.hap.HapStatusError(this.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
  }
}
