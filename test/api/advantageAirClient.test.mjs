import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import {
  AdvantageAirClient,
  AdvantageAirRequestError,
} from '../../dist/api/advantageAirClient.js';
import {
  IncompleteSystemDataError,
} from '../../dist/api/systemData.js';

const validData = {
  system: { hasAircons: true, noOfAircons: 1 },
  aircons: {
    ac2: {
      info: { name: 'Test AC' },
      zones: {},
    },
  },
};

async function createServer(t, handler) {
  const server = http.createServer(handler);

  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });

  t.after(async () => {
    await new Promise((resolve, reject) => {
      server.close(error => error ? reject(error) : resolve());
      server.closeAllConnections();
    });
  });

  return new AdvantageAirClient({
    ipAddress: '127.0.0.1',
    port: server.address().port,
    timeoutMs: 1000,
  });
}

test('requests system data using the expected endpoint', async (t) => {
  let requestedUrl;
  let requestedMethod;

  const client = await createServer(t, (request, response) => {
    requestedUrl = request.url;
    requestedMethod = request.method;
    response.end(JSON.stringify(validData));
  });

  assert.deepEqual(await client.getSystemData(), validData);
  assert.equal(requestedUrl, '/getSystemData');
  assert.equal(requestedMethod, 'GET');
});

test('shares overlapping reads and allows a subsequent fresh read', async (t) => {
  let requests = 0;
  let releaseResponse;
  let signalReceived;

  const received = new Promise(resolve => {
    signalReceived = resolve;
  });

  const client = await createServer(t, (_request, response) => {
    requests++;

    if (requests === 1) {
      releaseResponse = () => response.end(JSON.stringify(validData));
      signalReceived();
    } else {
      response.end(JSON.stringify(validData));
    }
  });

  const first = client.getSystemData();
  const second = client.getSystemData();

  assert.equal(first, second);
  await received;
  assert.equal(requests, 1);

  releaseResponse();
  await Promise.all([first, second]);

  await client.getSystemData();
  assert.equal(requests, 2);
});

test('reports HTTP errors and allows a later retry', async (t) => {
  let requests = 0;

  const client = await createServer(t, (_request, response) => {
    requests++;

    if (requests === 1) {
      response.writeHead(503);
      response.end('Unavailable');
    } else {
      response.end(JSON.stringify(validData));
    }
  });

  await assert.rejects(client.getSystemData(), {
    name: 'AdvantageAirRequestError',
    message: 'Controller returned HTTP 503.',
  });

  assert.deepEqual(await client.getSystemData(), validData);
  assert.equal(requests, 2);
});

test('rejects malformed JSON without exposing the response body', async (t) => {
  const client = await createServer(t, (_request, response) => {
    response.end('private controller response');
  });

  await assert.rejects(client.getSystemData(), {
    name: 'AdvantageAirRequestError',
    message: 'Controller response was not valid JSON.',
  });
});

test('rejects incomplete controller data', async (t) => {
  const client = await createServer(t, (_request, response) => {
    response.end(JSON.stringify({
      system: { hasAircons: true, noOfAircons: 1 },
      aircons: {},
    }));
  });

  await assert.rejects(
    client.getSystemData(),
    IncompleteSystemDataError,
  );
});

test('times out while waiting for the response body', async (t) => {
  const client = await createServer(t, (_request, response) => {
    response.writeHead(200, { 'Content-Type': 'application/json' });
    response.flushHeaders();
    response.write('{"system":');
  });

  await assert.rejects(client.getSystemData(), {
    name: 'AdvantageAirRequestError',
    message: 'Controller request timed out.',
  });
});

test('reports a dropped connection', async (t) => {
  const client = await createServer(t, (request) => {
    request.socket.destroy();
  });

  await assert.rejects(
    client.getSystemData(),
    AdvantageAirRequestError,
  );
});

test('rejects invalid connection settings', () => {
  for (const options of [
    { ipAddress: 'invalid' },
    { ipAddress: '127.0.0.1', port: 0 },
    { ipAddress: '127.0.0.1', port: 65536 },
    { ipAddress: '127.0.0.1', timeoutMs: 0 },
  ]) {
    assert.throws(() => new AdvantageAirClient(options));
  }
});
