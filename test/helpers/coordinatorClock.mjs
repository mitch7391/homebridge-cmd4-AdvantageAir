import { beforeEach } from 'node:test';

// Node's mock timers drive Date and setTimeout, but not performance.now.
// Keep coordinator deadlines on that same deterministic clock in these fixtures.
beforeEach(t => {
  t.mock.method(globalThis.performance, 'now', () => Date.now());
});
