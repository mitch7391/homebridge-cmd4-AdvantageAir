import type { API, PlatformAccessory, Service } from 'homebridge';

import type { ControllerPollState } from '../api/controllerPoller.js';
import { zoneTemperature } from './legacyState.js';

export interface ZoneTemperatureOptions {
  airconKey: string;
  zoneKey: string;
  getState: () => ControllerPollState;
  staleAfterMs?: number;
}

export class ZoneTemperatureAccessory {
  private readonly service: Service;
  private readonly staleAfterMs: number;

  constructor(
    private readonly api: API,
    accessory: PlatformAccessory,
    private readonly options: ZoneTemperatureOptions,
  ) {
    this.staleAfterMs = options.staleAfterMs ?? 90000;

    if (
      !Number.isInteger(this.staleAfterMs)
      || this.staleAfterMs < 1
    ) {
      throw new Error('Sensor freshness limit must be a positive integer.');
    }

    const { Service, Characteristic } = this.api.hap;

    this.service = accessory.getService(Service.TemperatureSensor)
      ?? accessory.addService(
        Service.TemperatureSensor,
        accessory.displayName,
      );

    this.service
      .getCharacteristic(Characteristic.CurrentTemperature)
      .onGet(() => this.readTemperature());

    this.service
      .getCharacteristic(Characteristic.StatusFault)
      .onGet(() => this.readFault());
  }

  /**
   * Push the current cached reading into Homebridge.
   * Called by platform integration after polling updates.
   */
  update(): void {
    const { Characteristic } = this.api.hap;
    let temperature: number;

    try {
      temperature = this.readTemperature();
    } catch {
      this.service.updateCharacteristic(
        Characteristic.CurrentTemperature,
        this.unavailable(),
      );
      this.service.updateCharacteristic(
        Characteristic.StatusFault,
        Characteristic.StatusFault.GENERAL_FAULT,
      );
      return;
    }

    this.service.updateCharacteristic(
      Characteristic.CurrentTemperature,
      temperature,
    );
    this.service.updateCharacteristic(
      Characteristic.StatusFault,
      Characteristic.StatusFault.NO_FAULT,
    );
  }

  private readTemperature(): number {
    const state = this.options.getState();

    if (
      !state.data
      || typeof state.lastSuccessAt !== 'number'
      || !Number.isFinite(state.lastSuccessAt)
    ) {
      throw this.unavailable();
    }

    const age = Date.now() - state.lastSuccessAt;

    if (age < 0 || age >= this.staleAfterMs) {
      throw this.unavailable();
    }

    const zone = state.data.aircons[this.options.airconKey]
      ?.zones[this.options.zoneKey];

    if (
      !zone
      || typeof zone.type !== 'number'
      || !Number.isInteger(zone.type)
      || zone.type <= 0
      || zone.error !== 0
      || zone.tempSensorClash === true
    ) {
      throw this.unavailable();
    }

    let temperature: number;

    try {
      temperature = zoneTemperature(zone);
    } catch {
      throw this.unavailable();
    }

    const characteristic = this.service.getCharacteristic(
      this.api.hap.Characteristic.CurrentTemperature,
    );

    const { minValue, maxValue } = characteristic.props;

    if (
      (minValue !== undefined && temperature < minValue)
      || (maxValue !== undefined && temperature > maxValue)
    ) {
      throw this.unavailable();
    }

    return temperature;
  }

  private readFault(): number {
    const { StatusFault } = this.api.hap.Characteristic;

    try {
      this.readTemperature();
      return StatusFault.NO_FAULT;
    } catch {
      return StatusFault.GENERAL_FAULT;
    }
  }

  private unavailable(): Error {
    return new this.api.hap.HapStatusError(
      this.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE,
    );
  }
}
