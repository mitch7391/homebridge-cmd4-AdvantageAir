import type { API, CharacteristicValue, PlatformAccessory, Service } from 'homebridge';

import { ZoneCommandError } from '../api/zoneCommand.js';

export interface ZoneSwitchOptions {
  getOn: () => boolean;
  /** Resolve only after confirmation and updating the state used by getOn. */
  setOn: (on: boolean, signal?: AbortSignal) => Promise<void>;
  warn: (message: string) => void;
}

export class ZoneSwitchAccessory {
  private readonly service: Service;
  private pending?: Promise<void>;

  constructor(
    private readonly api: API,
    private readonly accessory: PlatformAccessory,
    private readonly options: ZoneSwitchOptions,
  ) {
    const { Service, Characteristic } = api.hap;
    this.service = accessory.getService(Service.Switch)
      ?? accessory.addService(Service.Switch, accessory.displayName);
    this.service.getCharacteristic(Characteristic.On)
      .onGet(() => this.read())
      .onSet(value => this.set(value));
  }

  update(): void {
    // A polling update must not overwrite a command still being confirmed.
    if (this.pending) {
      return;
    }
    try {
      this.service.updateCharacteristic(this.api.hap.Characteristic.On, this.options.getOn());
    } catch {
      this.service.updateCharacteristic(this.api.hap.Characteristic.On, this.unavailable());
    }
  }

  private async read(): Promise<boolean> {
    let timer: ReturnType<typeof setTimeout> | undefined;
    const deadline = new Promise<never>((_, reject) => {
      timer = setTimeout(() => reject(this.unavailable()), 7000);
    });
    try {
      while (this.pending) {
        await Promise.race([this.pending, deadline]);
      }
      return this.options.getOn();
    } catch {
      throw this.unavailable();
    } finally {
      clearTimeout(timer);
    }
  }

  private async set(value: CharacteristicValue): Promise<void> {
    if (typeof value !== 'boolean') {
      throw new this.api.hap.HapStatusError(this.api.hap.HAPStatus.INVALID_VALUE_IN_REQUEST);
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(
      new ZoneCommandError('Zone command timed out before confirmation.'),
    ), 7000);
    let cancel = () => {};
    const cancelled = new Promise<never>((_, reject) => {
      cancel = () => reject(controller.signal.reason);
      controller.signal.addEventListener('abort', cancel, { once: true });
    });
    const previous = this.pending ?? Promise.resolve();
    const work = previous.catch(() => undefined).then(async () => {
      controller.signal.throwIfAborted();
      await this.options.setOn(value, controller.signal);
      controller.signal.throwIfAborted();
    });
    const operation = Promise.race([work, cancelled]);
    this.pending = operation;
    try {
      await operation;
    } catch (error) {
      const reason = error instanceof ZoneCommandError
        ? error.message
        : 'Controller communication failed; the requested change could not be confirmed.';
      this.options.warn(`Zone command failed for "${this.accessory.displayName}": ${reason}`);
      throw this.unavailable();
    } finally {
      clearTimeout(timer);
      controller.signal.removeEventListener('abort', cancel);
      if (this.pending === operation) {
        this.pending = undefined;
      }
    }
  }

  private unavailable(): Error {
    return new this.api.hap.HapStatusError(this.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
  }
}
