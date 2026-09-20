import { validateThermostatPatch } from './thermostatPatch.js';
import type { ThermostatPatch } from './thermostatPatch.js';
import { validateSystemData } from './systemData.js';
import type { SystemData } from './systemData.js';

export interface RequestDiagnostic {
  id: number;
  endpoint: '/getSystemData' | '/setAircon';
  event: 'send' | 'headers' | 'body' | 'error';
  elapsedMs: number;
  status?: number;
  json?: 'empty-object' | 'object' | 'array' | 'null' | 'boolean' | 'number' | 'string';
  rejected?: boolean;
  reason?: 'cancelled' | 'timeout' | 'connect' | 'http' | 'body' | 'json';
}

export interface AdvantageAirClientOptions {
  ipAddress: string;
  port?: number;
  timeoutMs?: number;
  onDiagnostic?: (event: RequestDiagnostic) => void;
}

export class AdvantageAirRequestError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AdvantageAirRequestError';
  }
}

export class AirconCommandRejectedError extends AdvantageAirRequestError {}

export class ZoneCommandRejectedError extends AirconCommandRejectedError {}

export class AdvantageAirClient {
  private readonly endpoint: URL;
  private readonly timeoutMs: number;
  private inFlight?: Promise<SystemData>;
  private requestId = 0;
  private readonly onDiagnostic?: (event: RequestDiagnostic) => void;
  private requests: Promise<void> = Promise.resolve();

  constructor(options: AdvantageAirClientOptions) {
    const port = options.port ?? 2025;
    const timeoutMs = options.timeoutMs ?? 10000;
    const host = options.ipAddress.trim();
    const octets = host.split('.');

    if (
      octets.length !== 4
      || octets.some(octet =>
        !/^(0|[1-9]\d{0,2})$/.test(octet) || Number(octet) > 255,
      )
    ) {
      throw new Error('Controller address must be a valid IPv4 address.');
    }

    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error('Controller port must be an integer from 1 to 65535.');
    }

    if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 120000) {
      throw new Error('Request timeout must be from 1 to 120000 milliseconds.');
    }

    this.endpoint = new URL(`http://${host}:${port}/getSystemData`);
    this.timeoutMs = timeoutMs;
    this.onDiagnostic = options.onDiagnostic;
  }

  getSystemData(signal?: AbortSignal): Promise<SystemData> {
    if (signal) {
      return this.requestSystemData(signal);
    }
    if (!this.inFlight) {
      const request = this.requestSystemData().finally(() => {
        if (this.inFlight === request) {
          this.inFlight = undefined;
        }
      });
      this.inFlight = request;
    }

    return this.inFlight;
  }

  private async requestSystemData(signal?: AbortSignal): Promise<SystemData> {
    return validateSystemData(await this.requestJson(this.endpoint, signal));
  }

  getFreshSystemData(signal?: AbortSignal): Promise<SystemData> {
    this.inFlight = undefined;
    return this.getSystemData(signal);
  }

  /** Sends once. The returned response is not confirmation of the zone state. */
  async requestZoneState(
    airconKey: string,
    zoneKey: string,
    state: 'open' | 'close',
    signal?: AbortSignal,
  ): Promise<unknown> {
    if (
      typeof airconKey !== 'string' || !/^ac\d+$/.test(airconKey)
      || typeof zoneKey !== 'string' || !/^z\d+$/.test(zoneKey)
      || (state !== 'open' && state !== 'close')
    ) {
      throw new AdvantageAirRequestError('Invalid zone command.');
    }

    const endpoint = new URL('/setAircon', this.endpoint);
    endpoint.searchParams.set('json', JSON.stringify({
      [airconKey]: { zones: { [zoneKey]: { state } } },
    }));

    // Reads requested after this write must not share an earlier read.
    this.inFlight = undefined;
    const response = await this.requestJson(endpoint, signal);
    if (response === false) {
      throw new ZoneCommandRejectedError('Controller rejected the zone command.');
    }
    return response;
  }

  /** One absolute thermostat write; readback is coordinated separately. */
  async requestThermostatPatch(airconKey: string, patch: ThermostatPatch, signal?: AbortSignal): Promise<unknown> {
    if (typeof airconKey !== 'string' || !/^ac\d+$/.test(airconKey)) {
      throw new AdvantageAirRequestError('Invalid air conditioner address.');
    }
    validateThermostatPatch(patch);
    const endpoint = new URL('/setAircon', this.endpoint);
    endpoint.searchParams.set('json', JSON.stringify({ [airconKey]: patch }));
    this.inFlight = undefined;
    const response = await this.requestJson(endpoint, signal);
    if (response === false) {
      throw new AirconCommandRejectedError('Controller rejected the thermostat command.');
    }
    return response;
  }

  private requestJson(endpoint: URL, signal?: AbortSignal): Promise<unknown> {
    const request = this.requests.then(() => {
      if (signal?.aborted) {
        throw new AdvantageAirRequestError('Controller request cancelled.');
      }
      return this.performRequest(endpoint, signal);
    });
    // A failed request must not prevent subsequent requests from running.
    this.requests = request.then(() => undefined, () => undefined);
    return request;
  }

  private async performRequest(endpoint: URL, signal?: AbortSignal): Promise<unknown> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    const requestSignal = signal
      ? AbortSignal.any([controller.signal, signal])
      : controller.signal;

    const id = ++this.requestId;
    const started = performance.now();
    let reason: RequestDiagnostic['reason'] = 'connect';
    const diagnostic = (event: RequestDiagnostic['event'], details: Partial<RequestDiagnostic> = {}) => {
      try {
        this.onDiagnostic?.({
          id, endpoint: endpoint.pathname === '/setAircon' ? '/setAircon' : '/getSystemData',
          event, elapsedMs: Math.round(performance.now() - started), ...details,
        });
      } catch {
        // Diagnostic observers cannot change request outcomes or queue progress.
      }
    };
    diagnostic('send');

    try {
      let response: Response;

      try {
        response = await fetch(endpoint, {
          signal: requestSignal,
          redirect: 'error',
          headers: {
            Accept: 'application/json',
          },
        });
      } catch {
        if (signal?.aborted) {
          throw new AdvantageAirRequestError('Controller request cancelled.');
        }
        throw new AdvantageAirRequestError(
          controller.signal.aborted
            ? 'Controller request timed out.'
            : 'Could not connect to the controller.',
        );
      }

      diagnostic('headers', { status: response.status });
      if (!response.ok) {
        reason = 'http';
        await response.body?.cancel();
        throw new AdvantageAirRequestError(
          `Controller returned HTTP ${response.status}.`,
        );
      }

      reason = 'body';
      let body: string;

      try {
        body = await response.text();
      } catch {
        if (signal?.aborted) {
          throw new AdvantageAirRequestError('Controller request cancelled.');
        }
        throw new AdvantageAirRequestError(
          controller.signal.aborted
            ? 'Controller request timed out.'
            : 'Could not read the controller response.',
        );
      }

      reason = 'json';
      let data: unknown;

      try {
        data = JSON.parse(body);
      } catch {
        throw new AdvantageAirRequestError(
          'Controller response was not valid JSON.',
        );
      }

      const json: RequestDiagnostic['json'] = data === null ? 'null'
        : Array.isArray(data) ? 'array'
          : typeof data === 'object' ? (Object.keys(data).length === 0 ? 'empty-object' : 'object')
            : typeof data as 'boolean' | 'number' | 'string';
      diagnostic('body', {
        json,
        ...(endpoint.pathname === '/setAircon' && data === false ? { rejected: true } : {}),
      });
      return data;
    } catch (error) {
      diagnostic('error', {
        reason: signal?.aborted ? 'cancelled' : controller.signal.aborted ? 'timeout' : reason,
      });
      throw error;
    } finally {
      clearTimeout(timer);
    }
  }
}
