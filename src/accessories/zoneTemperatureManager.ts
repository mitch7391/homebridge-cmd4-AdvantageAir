import type { API, PlatformAccessory } from 'homebridge';

import type { ControllerPollState } from '../api/controllerPoller.js';
import { discoverDevices } from '../discovery/discoverDevices.js';
import { PLATFORM_NAME, PLUGIN_NAME } from '../settings.js';
import {
  ZoneTemperatureAccessory,
} from './zoneTemperatureAccessory.js';

interface TemperatureBinding {
  handler: ZoneTemperatureAccessory;
  airconKey: string;
  zoneKey: string;
  present: boolean;
}

export class DuplicateControllerError extends Error {
  constructor() {
    super('This controller identity is already managed by another configured address.');
    this.name = 'DuplicateControllerError';
  }
}

export class ZoneTemperatureManager {
  private static readonly controllerOwners = new WeakMap<API, Map<string, ZoneTemperatureManager>>();

  private state: ControllerPollState = {
    lastAttemptFailed: false,
  };

  private readonly bindings = new Map<string, TemperatureBinding>();

  static prepareCachedAccessory(api: API, accessory: PlatformAccessory): void {
    if (accessory.context.advantageAirTemperature !== true) {
      return;
    }

    // Saved readings are not evidence that the controller is reachable.
    // Discovery will replace these handlers after a valid response.
    const handler = new ZoneTemperatureAccessory(api, accessory, {
      airconKey: '',
      zoneKey: '',
      getState: () => ({ lastAttemptFailed: false }),
    });

    handler.update();
  }

  constructor(
    private readonly api: API,
    private readonly accessories: Map<string, PlatformAccessory>,
  ) {}

  update(state: ControllerPollState): void {
    this.state = state;

    if (state.lastAttemptFailed || !state.data) {
      this.updateHandlers();
      return;
    }

    // Discover the complete response before changing any existing bindings.
    // If identities cannot be verified, old addressing must not be reused.
    let devices: ReturnType<typeof discoverDevices>;

    try {
      devices = discoverDevices(state.data);

      if (devices.length > 0) {
        // Discovery has validated the controller ID. Claims last for this API
        // instance so another address cannot replace an active read handler.
        const controllerId = (state.data.system.mid as string).trim();
        let owners = ZoneTemperatureManager.controllerOwners.get(this.api);

        if (!owners) {
          owners = new Map();
          ZoneTemperatureManager.controllerOwners.set(this.api, owners);
        }

        const owner = owners.get(controllerId);

        if (owner && owner !== this) {
          throw new DuplicateControllerError();
        }

        owners.set(controllerId, this);
      }
    } catch (error) {
      for (const binding of this.bindings.values()) {
        binding.present = false;
      }

      this.updateHandlers();
      throw error;
    }

    for (const binding of this.bindings.values()) {
      binding.present = false;
    }

    try {
      for (const device of devices) {
        if (device.kind !== 'zone') {
          continue;
        }

        const zone = state.data.aircons[device.airconKey].zones[device.zoneKey];

        // Capability determines whether a sensor exists.
        // A temporary sensor error must not remove its accessory.
        if (
          typeof zone.type !== 'number'
          || !Number.isInteger(zone.type)
          || zone.type <= 0
        ) {
          continue;
        }

        const uuid = this.api.hap.uuid.generate(JSON.stringify([
          device.identity,
          'temperature',
        ]));

        const existingBinding = this.bindings.get(uuid);

        if (existingBinding) {
          existingBinding.airconKey = device.airconKey;
          existingBinding.zoneKey = device.zoneKey;
          existingBinding.present = true;
          continue;
        }

        const cachedAccessory = this.accessories.get(uuid);
        const accessory = cachedAccessory ?? new this.api.platformAccessory(
          `${device.name} Temperature`,
          uuid,
        );

        // This mutable address lets restored handlers follow addressing
        // changes without changing the accessory's stable UUID.
        const address = {
          airconKey: device.airconKey,
          zoneKey: device.zoneKey,
          present: true,
        };

        const handler = new ZoneTemperatureAccessory(this.api, accessory, {
          get airconKey() {
            return address.airconKey;
          },
          get zoneKey() {
            return address.zoneKey;
          },
          getState: () => address.present
            ? this.state
            : { ...this.state, data: undefined },
        });

        const needsMarker = accessory.context.advantageAirTemperature !== true;
        accessory.context.advantageAirTemperature = true;

        if (cachedAccessory && needsMarker) {
          this.api.updatePlatformAccessories([accessory]);
        }

        if (!cachedAccessory) {
          this.api.registerPlatformAccessories(
            PLUGIN_NAME,
            PLATFORM_NAME,
            [accessory],
          );

          this.accessories.set(uuid, accessory);
        }

        // Keep the address object itself so later updates reach the getters.
        const binding: TemperatureBinding = Object.assign(address, {
          handler,
        });

        this.bindings.set(uuid, binding);
      }
    } finally {
      this.updateHandlers();
    }
  }

  private updateHandlers(): void {
    for (const binding of this.bindings.values()) {
      binding.handler.update();
    }
  }
}
