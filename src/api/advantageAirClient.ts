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
      this.inFlight = this.requestSystemData().finally(() => {
        this.inFlight = undefined;
      });
    }

    return this.inFlight;
  }

  private async requestSystemData(): Promise<SystemData> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      let response: Response;

      try {
        response = await fetch(this.endpoint, {
          signal: controller.signal,
          redirect: 'error',
          headers: {
            Accept: 'application/json',
          },
        });
      } catch {
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

      return validateSystemData(data);
    } finally {
      clearTimeout(timer);
    }
  }
}
