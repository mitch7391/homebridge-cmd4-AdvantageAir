import type { API, PlatformAccessory } from 'homebridge';
import type { ControllerPollState } from '../api/controllerPoller.js';
import type { ControllerCoordinator } from '../api/controllerCoordinator.js';
import { LightCommandError, observeLights } from '../api/lightCommand.js';
import { PLATFORM_NAME, PLUGIN_NAME } from '../settings.js';
import { LightAccessory } from './lightAccessory.js';
import { updateAccessoryName } from './accessoryName.js';
import { updateAccessoryInformation } from './accessoryInformation.js';

export class LightManager {
  private readonly handlers = new Map<string, LightAccessory>();
  private readonly warned = new Set<string>();
  private present = new Set<string>();
  private stopped = false;
  constructor(private readonly api: API, private readonly accessories: Map<string, PlatformAccessory>,
    private readonly coordinator: Pick<ControllerCoordinator, 'readLight' | 'requestLight'>,
    private readonly exclusions: Set<string>, private readonly warn: (message: string) => void) {}

  static prepareCachedAccessory(api: API, accessory: PlatformAccessory): void {
    if (accessory.context.advantageAirLight !== true) {
      return;
    }
    const unavailable = () => {
      throw new LightCommandError('Waiting for light data.');
    };
    new LightAccessory(api, accessory, accessory.context.lightDimmer === true,
      { read: unavailable, write: unavailable }).update();
  }

  update(state: ControllerPollState): void {
    if (this.stopped) {
      return;
    }
    if (state.data && !state.lastAttemptFailed) {
      this.present.clear();
      const warning = (message: string) => {
        if (!this.warned.has(message) && this.warned.size < 256) {
          this.warned.add(message);
          this.warn(message);
        }
      };
      // Explicit exclusions also apply when an excluded output is temporarily absent.
      const mid = state.data.system.mid;
      if (typeof mid === 'string' && mid.trim()) {
        for (const id of this.exclusions) {
          const identity = JSON.stringify(['AdvantageAir', mid.trim(), 'light', id]);
          const uuid = this.api.hap.uuid.generate(identity);
          const cached = this.accessories.get(uuid);
          if (cached?.context.advantageAirLight === true) {
            this.api.unregisterPlatformAccessories(PLUGIN_NAME, PLATFORM_NAME, [cached]);
            this.accessories.delete(uuid);
            this.handlers.delete(identity);
          }
        }
      }
      for (const light of observeLights(state.data, warning)) {
        const uuid = this.api.hap.uuid.generate(light.identity);
        const cached = this.accessories.get(uuid);
        if (this.exclusions.has(light.id)) {
          if (cached?.context.advantageAirLight === true) {
            this.api.unregisterPlatformAccessories(PLUGIN_NAME, PLATFORM_NAME, [cached]);
            this.accessories.delete(uuid);
            this.handlers.delete(light.identity);
          }
          continue;
        }
        const accessory = cached ?? new this.api.platformAccessory(light.name, uuid);
        const prior = accessory.context.lightDimmer;
        if ((prior === true && light.capability === 'relay') || (prior === false && light.capability === 'dimmer')) {
          warning(`Light ${light.id} capability conflicts with its established capability; accessory retained unavailable.`);
          continue;
        }
        const dimmer = prior === true || light.capability === 'dimmer';
        this.present.add(light.identity);
        let changed = updateAccessoryInformation(this.api, accessory, state.data.system.sysType);
        if (accessory.context.advantageAirLight !== true) {
          accessory.context.advantageAirLight = true;
          // Unknown evidence must not permanently prevent later positive dimmer discovery.
          accessory.context.lightDimmer = light.capability === 'unknown' ? undefined : dimmer;
          changed = true;
        } else if (prior === undefined && light.capability !== 'unknown') {
          accessory.context.lightDimmer = dimmer;
          changed = true;
        }
        if (!this.handlers.has(light.identity) || (prior === undefined && dimmer)) {
          const use = () => {
            if (this.stopped || !this.present.has(light.identity)) {
              throw new LightCommandError('Light unavailable.');
            }
          };
          this.handlers.set(light.identity, new LightAccessory(this.api, accessory, dimmer, {
            read: field => {
              use(); return this.coordinator.readLight(light.identity, field);
            },
            write: (field, value) => {
              use(); this.coordinator.requestLight(light.identity, field, value);
            },
          }));
        }
        changed = updateAccessoryName(this.api, accessory, light.name,
          [[accessory.getService(this.api.hap.Service.Lightbulb), light.name]]) || changed;
        if (!cached) {
          this.api.registerPlatformAccessories(PLUGIN_NAME, PLATFORM_NAME, [accessory]);
          this.accessories.set(uuid, accessory);
        } else if (changed) {
          this.api.updatePlatformAccessories([accessory]);
        }
      }
    }
    for (const handler of this.handlers.values()) {
      handler.update();
    }
  }
  stop(): void {
    this.stopped = true;
    this.present.clear();
    for (const handler of this.handlers.values()) {
      handler.update();
    }
  }
}
