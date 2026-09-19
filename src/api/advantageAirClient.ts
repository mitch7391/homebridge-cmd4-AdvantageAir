import { validateSystemData } from './systemData.js';
import type { SystemData } from './systemData.js';

export interface AdvantageAirClientOptions {
  ipAddress: string;
  port?: number;
  timeoutMs?: number;
}

export class AdvantageAirRequestError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AdvantageAirRequestError';
  }
}

export class AdvantageAirClient {
  private readonly endpoint: URL;
  private readonly timeoutMs: number;
  private inFlight?: Promise<SystemData>;
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
  }

  getSystemData(): Promise<SystemData> {
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

  private async requestSystemData(): Promise<SystemData> {
    return validateSystemData(await this.requestJson(this.endpoint));
  }

  getFreshSystemData(): Promise<SystemData> {
    this.inFlight = undefined;
    return this.getSystemData();
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
      throw new AdvantageAirRequestError('Controller rejected the zone command.');
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

      if (!response.ok) {
        await response.body?.cancel();
        throw new AdvantageAirRequestError(
          `Controller returned HTTP ${response.status}.`,
        );
      }

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

      let data: unknown;

      try {
        data = JSON.parse(body);
      } catch {
        throw new AdvantageAirRequestError(
          'Controller response was not valid JSON.',
        );
      }

      return data;
    } finally {
      clearTimeout(timer);
    }
  }
}
