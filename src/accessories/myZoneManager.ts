import { airconAccessoryName, updateAccessoryName } from './accessoryName.js';
import type { HomeNameResolver } from '../discovery/homeNames.js';
import { updateAccessoryInformation } from './accessoryInformation.js';
import type { API, PlatformAccessory } from 'homebridge';
import type { ControllerCoordinator } from '../api/controllerCoordinator.js';
import type { ControllerPollState } from '../api/controllerPoller.js';
import { MyZoneCommandError, planMyZoneSelection } from '../api/myZoneCommand.js';
import { discoverDevices } from '../discovery/discoverDevices.js';
import { PLATFORM_NAME, PLUGIN_NAME } from '../settings.js';
import { MyZoneAccessory } from './myZoneAccessory.js';
import { DuplicateControllerError } from './zoneTemperatureManager.js';

export class MyZoneManager {
  private static readonly owners = new WeakMap<API, Map<string, MyZoneManager>>();
  private readonly handlers = new Map<string, MyZoneAccessory>();
  private eligible = new Set<string>();
  private stopped = false;

  constructor(
    private readonly api: API,
    private readonly accessories: Map<string, PlatformAccessory>,
    private readonly coordinator: Pick<ControllerCoordinator, 'readMyZoneSelection' | 'requestMyZoneSelection'>,
    private readonly warn: (message: string) => void,
    private readonly onCreated: (name: string) => void,
    private readonly resolveHomeName?: HomeNameResolver,
  ) {}

  static prepareCachedAccessory(api: API, accessory: PlatformAccessory): void {
    MyZoneAccessory.prepareCachedAccessory(api, accessory);
  }

  update(state: ControllerPollState): void {
    if (this.stopped) {
      return;
    }
    try {
      if (!state.data || state.lastAttemptFailed) {
        return;
      }
      const devices = discoverDevices(state.data);
      const eligible = new Set<string>();
      for (const aircon of devices) {
        if (aircon.kind !== 'aircon') {
          continue;
        }
        const zones = devices.filter(zone => {
          if (zone.kind !== 'zone' || zone.airconKey !== aircon.airconKey) {
            return false;
          }
          try {
            planMyZoneSelection(state.data!.aircons[aircon.airconKey], zone.zoneKey);
            return true;
          } catch {
            return false;
          }
        });
        for (const zone of zones) {
          eligible.add(zone.identity);
        }
        if (zones.length === 0) {
          continue;
        }
        let owners = MyZoneManager.owners.get(this.api);
        if (!owners) {
          owners = new Map();
          MyZoneManager.owners.set(this.api, owners);
        }
        const owner = owners.get(aircon.identity);
        if (owner && owner !== this) {
          throw new DuplicateControllerError();
        }
        owners.set(aircon.identity, this);
        const uuid = this.api.hap.uuid.generate(JSON.stringify([aircon.identity, 'myzone']));
        const cached = this.accessories.get(uuid);
        const name = airconAccessoryName(this.resolveHomeName, aircon.identity, aircon.name, ' MyZone', cached);
        if (name === undefined) {
          continue;
        }
        const accessory = cached ?? new this.api.platformAccessory(name, uuid);
        const namesChanged = (!this.resolveHomeName || this.resolveHomeName(aircon.identity) !== undefined)
          && updateAccessoryName(this.api, accessory, name, []);
        let handler = this.handlers.get(uuid);
        let changed = updateAccessoryInformation(this.api, accessory, state.data.system.sysType) || namesChanged;
        if (!handler) {
          const use = <T>(identity: string, operation: () => T): T => {
            if (this.stopped || !this.eligible.has(identity)) {
              throw new MyZoneCommandError('This MyZone reference zone is unavailable.');
            }
            return operation();
          };
          handler = new MyZoneAccessory(this.api, accessory, {
            getOn: identity => use(identity, () => this.coordinator.readMyZoneSelection(aircon.identity) === identity),
            select: identity => use(identity, () => this.coordinator.requestMyZoneSelection(aircon.identity, identity)),
            warn: this.warn,
          });
          changed = accessory.context.advantageAirMyZone !== true || changed;
          accessory.context.advantageAirMyZone = true;
          this.handlers.set(uuid, handler);
        }
        for (const zone of zones) {
          changed = handler.addZone(zone.identity, zone.name) || changed;
        }
        if (!cached) {
          this.api.registerPlatformAccessories(PLUGIN_NAME, PLATFORM_NAME, [accessory]);
          this.accessories.set(uuid, accessory);
          try {
            this.onCreated(accessory.displayName);
          } catch {
            // A logging failure must not interrupt accessory discovery.
          }
        } else if (changed) {
          this.api.updatePlatformAccessories([accessory]);
        }
      }
      this.eligible = eligible;
    } catch (error) {
      this.eligible.clear();
      throw error;
    } finally {
      for (const handler of this.handlers.values()) {
        handler.update();
      }
    }
  }

  stop(): void {
    this.stopped = true;
    this.eligible.clear();
    for (const handler of this.handlers.values()) {
      handler.update();
    }
  }
}
