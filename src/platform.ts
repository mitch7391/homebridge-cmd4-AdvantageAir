import { fanSetting } from './api/fanCommand.js';
import type {
  API,
  DynamicPlatformPlugin,
  Logging,
  PlatformAccessory,
  PlatformConfig,
} from 'homebridge';

import { AdvantageAirClient } from './api/advantageAirClient.js';
import { ControllerCoordinator } from './api/controllerCoordinator.js';
import type { ControllerPollState } from './api/controllerPoller.js';
import { ZoneSwitchManager } from './accessories/zoneSwitchManager.js';
import { ThermostatManager } from './accessories/thermostatManager.js';
import { DuplicateControllerError, ZoneTemperatureManager } from './accessories/zoneTemperatureManager.js';

interface ConfiguredController {
  name: string;
  debug: boolean;
  poller: ControllerCoordinator;
  switchManager: ZoneSwitchManager;
  thermostatManager: ThermostatManager;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export class AdvantageAirPlatform implements DynamicPlatformPlugin {
  public readonly accessories = new Map<string, PlatformAccessory>();

  private readonly controllers: ConfiguredController[] = [];
  private launched = false;
  private stopped = false;

  constructor(
    public readonly log: Logging,
    public readonly config: PlatformConfig,
    public readonly api: API,
  ) {
    this.configureControllers(this.config.devices);

    this.api.on('didFinishLaunching', () => {
      if (this.launched || this.stopped) {
        return;
      }

      this.launched = true;

      for (const controller of this.controllers) {
        this.log.info('Starting controller polling:', controller.name);
        controller.poller.start();
      }
    });

    this.api.on('shutdown', () => {
      this.stopped = true;

      for (const controller of this.controllers) {
        controller.poller.stop();
        controller.switchManager.stop();
        controller.thermostatManager.stop();
      }
    });
  }

  configureAccessory(accessory: PlatformAccessory): void {
    this.log.debug('Loading accessory from cache:', accessory.displayName);
    this.accessories.set(accessory.UUID, accessory);
    ZoneTemperatureManager.prepareCachedAccessory(this.api, accessory);
    ZoneSwitchManager.prepareCachedAccessory(this.api, accessory);
    ThermostatManager.prepareCachedAccessory(this.api, accessory);
  }

  private configureControllers(devices: unknown): void {
    if (!Array.isArray(devices) || devices.length === 0) {
      this.log.warn('No controllers configured. Add a controller in plugin settings.');
      return;
    }

    const endpoints = new Set<string>();

    for (const [index, device] of devices.entries()) {
      try {
        if (!isObject(device)) {
          throw new Error('Controller settings must be an object.');
        }

        if (typeof device.ipAddress !== 'string') {
          throw new Error('An IPv4 address is required.');
        }

        if (device.port !== undefined && typeof device.port !== 'number') {
          throw new Error('Port must be a number.');
        }

        if (device.name !== undefined && typeof device.name !== 'string') {
          throw new Error('Controller name must be text.');
        }

        if (device.debug !== undefined && typeof device.debug !== 'boolean') {
          throw new Error('Debug must be true or false.');
        }

        const ipAddress = device.ipAddress.trim();
        const port = device.port ?? 2025;
        const name = typeof device.name === 'string' && device.name.trim()
          ? device.name.trim()
          : `Controller ${index + 1}`;

        const debug = device.debug === true;
        const client = new AdvantageAirClient({
          ipAddress, port,
          onDiagnostic: debug
            ? event => this.log.debug(name, 'AA timing:', JSON.stringify(event))
            : undefined,
        });
        const endpoint = `${ipAddress}:${port}`;

        if (endpoints.has(endpoint)) {
          throw new Error('This controller address and port are already configured.');
        }

        endpoints.add(endpoint);

        let previouslyFailed = false;
        let receivedData = false;
        let accessoryUpdateFailed = false;

        const temperatureManager = new ZoneTemperatureManager(
          this.api,
          this.accessories,
          accessoryName => this.log.info(name, 'Created accessory:', accessoryName),
        );

        const updateManagers: Array<(state: ControllerPollState) => void> = [
          state => temperatureManager.update(state),
        ];
        const poller = new ControllerCoordinator(client, (state, reason) => {
          let updateFailed = false;
          for (const update of updateManagers) {
            try {
              update(state);
            } catch (error) {
              if (error instanceof DuplicateControllerError) {
                poller.stop();
                this.log.error('Duplicate controller identity:', name, 'Polling stopped for this entry.');
                return;
              }
              updateFailed = true;
            }
          }
          if (updateFailed && !accessoryUpdateFailed) {
            this.log.error(
              'Controller accessory update failed:',
              name,
              'Existing accessories have been retained.',
            );
          }
          accessoryUpdateFailed = updateFailed;
          if (reason === 'state') {
            return;
          }

          if (state.lastAttemptFailed) {
            if (!previouslyFailed) {
              this.log.warn(
                'Controller read failed:',
                name,
                state.data
                  ? 'Retaining previously received data; it may be stale.'
                  : 'Waiting for the first valid response.',
              );
            }

            previouslyFailed = true;
            return;
          }

          if (!state.data) {
            return;
          }

          if (previouslyFailed) {
            this.log.info('Controller communication recovered:', name);
          } else if (!receivedData) {
            this.log.info('Received first valid controller response:', name);
          }

          previouslyFailed = false;
          receivedData = true;

          if (debug) {
            const aircons = Object.values(state.data.aircons);
            const zoneCount = aircons.reduce(
              (total, aircon) => total + Object.keys(aircon.zones).length,
              0,
            );

            this.log.debug(
              'Controller read:',
              name,
              `${aircons.length} air conditioner(s), ${zoneCount} zone(s).`,
            );
          }
        }, message => this.log.warn(name, message), (event) => {
          const state = event.kind === 'zone' ? (event.on ? 'Open' : 'Closed')
            : event.kind === 'fan' ? 'fan speed ' + fanSetting(event.percentage).fan
              : event.kind === 'mode' ? event.mode : String(event.temperature) + ' °C';
          if (event.superseded || event.outcome === 'unchanged') {
            if (debug) {
              this.log.debug(name, event.name,
                event.superseded ? 'Earlier command confirmed:' : 'Already in requested state:', state);
            }
          } else if (debug) {
            this.log.debug(name, event.name, 'Controller confirmed:', state);
          }
        }, (accessoryName, target) => this.log.info(name, accessoryName, 'Sending:', target));

        const switchManager = new ZoneSwitchManager(
          this.api,
          this.accessories,
          poller,
          message => this.log.warn(name, message),
          accessoryName => this.log.info(name, 'Created accessory:', accessoryName),
        );
        updateManagers.unshift(state => switchManager.update(state));

        const thermostatManager = new ThermostatManager(
          this.api,
          this.accessories,
          poller,
          message => this.log.warn(name, message),
          accessoryName => this.log.info(name, 'Created accessory:', accessoryName),
        );
        updateManagers.push(state => thermostatManager.update(state));

        this.controllers.push({ name, debug, poller, switchManager, thermostatManager });
      } catch (error) {
        const reason = error instanceof Error
          ? error.message
          : 'Invalid controller settings.';

        this.log.error(`Controller entry ${index + 1} skipped: ${reason}`);
      }
    }
  }
}
