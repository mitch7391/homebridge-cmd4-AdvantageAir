// Temporary process-only diagnostics. Does not modify plugin or HAP files.
import { Characteristic } from '../../node_modules/@homebridge/hap-nodejs/dist/index.js';
import { PercentageZoneAccessory } from '../../dist/accessories/percentageZoneAccessory.js';
import { ControllerCoordinator } from '../../dist/api/controllerCoordinator.js';
const { console, URL } = globalThis;
const tagged = new WeakSet();
const log = (event, fields = {}) => console.log('[AA HOME TRIAL]', JSON.stringify({ at: new Date().toISOString(), event, ...fields }));
const update = PercentageZoneAccessory.prototype.update;
PercentageZoneAccessory.prototype.update = function (...args) {
  for (const [characteristic] of this.readings) {
    tagged.add(characteristic);
  }
  return update.apply(this, args);
};
const write = Characteristic.prototype.handleSetRequest;
let next = 0;
Characteristic.prototype.handleSetRequest = async function (value, connection, context) {
  if (!tagged.has(this) || connection === undefined) {
    return write.call(this, value, connection, context);
  }
  const id = ++next;
  log('HAP_WRITE', { id, characteristic: this.displayName, value });
  try {
    const response = await write.call(this, value, connection, context);
    log('HAP_ACCEPTED', { id, characteristic: this.displayName, response, current: this.value });
    return response;
  } catch (error) {
    log('HAP_REFUSED', { id, status: typeof error === 'number' ? error : error.message });
    throw error;
  }
};
for (const method of ['requestPercentageZoneState', 'requestZonePercentage']) {
  const original = ControllerCoordinator.prototype[method];
  ControllerCoordinator.prototype[method] = function (identity, value) {
    const result = original.call(this, identity, value);
    log('DESIRED_ADMITTED', { control: method === 'requestZonePercentage' ? 'percentage' : 'state', value });
    return result;
  };
}
const originalFetch = globalThis.fetch;
globalThis.fetch = async (input, options) => {
  const url = new URL(String(input));
  if (url.hostname !== '127.0.0.1' || url.port !== '52025') {
    throw Error('Trial HTTP access restricted to local simulator');
  }
  if (url.pathname === '/setAircon') {
    log('SET_PAYLOAD', { payload: JSON.parse(url.searchParams.get('json')) });
  }
  const response = await originalFetch(input, options);
  if (url.pathname === '/getSystemData') {
    const data = await response.clone().json();
    const z = data.aircons?.ac1?.zones?.z06;
    log('SIMULATOR_READ', { state: z?.state, value: z?.value, type: z?.type });
  }
  return response;
};
log('DIAGNOSTICS_READY', { simulator: '127.0.0.1:52025' });
