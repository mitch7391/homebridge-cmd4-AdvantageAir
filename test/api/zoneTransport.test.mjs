import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';
import { URL } from 'node:url';

import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';

async function prepare(t, handler, timeoutMs = 1000) {
  const server = http.createServer(handler);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => {
    server.close(resolve);
    server.closeAllConnections();
  }));
  return new AdvantageAirClient({
    ipAddress: '127.0.0.1', port: server.address().port, timeoutMs,
  });
}

test('sends only the requested zone patch and returns an unconfirmed response', async (t) => {
  let calls = 0;
  const client = await prepare(t, (request, response) => {
    calls++;
    const url = new URL(request.url, 'http://localhost');
    assert.equal(request.method, 'GET');
    assert.equal(url.pathname, '/setAircon');
    assert.deepEqual(JSON.parse(url.searchParams.get('json')), {
      ac2: { zones: { z03: { state: 'close' } } },
    });
    response.end('{}');
  });
  assert.deepEqual(await client.requestZoneState('ac2', 'z03', 'close'), {});
  assert.equal(calls, 1);
});

test('rejects a false response without retrying', async (t) => {
  let calls = 0;
  const client = await prepare(t, (request, response) => {
    calls++;
    response.end('false');
  });
  await assert.rejects(client.requestZoneState('ac1', 'z01', 'open'), /rejected/);
  assert.equal(calls, 1);
});

test('preserves other JSON responses for later interpretation', async (t) => {
  const client = await prepare(t, (request, response) => {
    response.end('{"status":"unknown"}');
  });
  assert.deepEqual(await client.requestZoneState('ac1', 'z01', 'open'), {
    status: 'unknown',
  });
});

test('rejects invalid commands before sending any request', async (t) => {
  let calls = 0;
  const client = await prepare(t, (request, response) => {
    calls++;
    response.end('{}');
  });
  for (const args of [
    ['ac1', 'z01', 'off'], ['ac1', 'z01', true],
    ['__proto__', 'z01', 'open'], ['ac1', '../z01', 'open'],
    [null, 'z01', 'open'], ['ac1', null, 'open'],
  ]) {
    await assert.rejects(client.requestZoneState(...args), /Invalid zone command/);
  }
  assert.equal(calls, 0);
});

test('rejects HTTP errors and malformed JSON without disclosing bodies', async (t) => {
  let calls = 0;
  const client = await prepare(t, (request, response) => {
    calls++;
    response.statusCode = calls === 1 ? 503 : 200;
    response.end('private controller response');
  });
  await assert.rejects(client.requestZoneState('ac1', 'z01', 'open'), /HTTP 503/);
  await assert.rejects(client.requestZoneState('ac1', 'z01', 'open'), error => {
    assert.match(error.message, /not valid JSON/);
    assert.equal(error.message.includes('private'), false);
    return true;
  });
  assert.equal(calls, 2);
});

test('times out during the response body without retrying the write', async (t) => {
  let calls = 0;
  const client = await prepare(t, (request, response) => {
    calls++;
    response.writeHead(200);
    response.write('{');
  }, 100);
  await assert.rejects(client.requestZoneState('ac1', 'z01', 'open'), /timed out/);
  assert.equal(calls, 1);
});

test('does not follow redirects or retry dropped connections', async (t) => {
  let calls = 0;
  const client = await prepare(t, (request, response) => {
    calls++;
    if (calls === 1) {
      response.writeHead(302, { Location: '/other' });
      response.end();
    } else {
      request.socket.destroy();
    }
  });
  await assert.rejects(client.requestZoneState('ac1', 'z01', 'open'), /Could not connect/);
  assert.equal(calls, 1);
  await assert.rejects(client.requestZoneState('ac1', 'z01', 'open'), /Could not connect/);
  assert.equal(calls, 2);
});
