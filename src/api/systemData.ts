export type JsonObject = Record<string, unknown>;

export interface AirconData extends JsonObject {
  info: JsonObject;
  zones: Record<string, JsonObject>;
}

export interface SystemData extends JsonObject {
  system: JsonObject;
  aircons: Record<string, AirconData>;
}

export class InvalidSystemDataError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'InvalidSystemDataError';
  }
}

export class IncompleteSystemDataError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'IncompleteSystemDataError';
  }
}

function isObject(value: unknown): value is JsonObject {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * Validate the response structure without discarding additional API fields.
 * Accessory-specific values will be validated before they are used.
 */
export function validateSystemData(value: unknown): SystemData {
  if (!isObject(value)) {
    throw new InvalidSystemDataError('System data must be an object.');
  }

  const { system, aircons } = value;

  if (!isObject(system) || !isObject(aircons)) {
    throw new InvalidSystemDataError(
      'System data must contain system and aircons objects.',
    );
  }

  const airconEntries = Object.entries(aircons);
  const expectedCount = system.noOfAircons;

  if (
    expectedCount !== undefined
    && (
      typeof expectedCount !== 'number'
      || !Number.isInteger(expectedCount)
      || expectedCount < 0
    )
  ) {
    throw new InvalidSystemDataError('Invalid air conditioner count.');
  }

  if (
    (system.hasAircons === true && airconEntries.length === 0)
    || (typeof expectedCount === 'number' && airconEntries.length < expectedCount)
  ) {
    throw new IncompleteSystemDataError(
      'The controller reports air conditioners that are missing from its response.',
    );
  }

  for (const [, aircon] of airconEntries) {
    if (!isObject(aircon) || !isObject(aircon.info) || !isObject(aircon.zones)) {
      throw new InvalidSystemDataError(
        'Each air conditioner must contain info and zones objects.',
      );
    }

    for (const zone of Object.values(aircon.zones)) {
      if (!isObject(zone)) {
        throw new InvalidSystemDataError('Each zone must be an object.');
      }
    }
  }

  return value as SystemData;
}
