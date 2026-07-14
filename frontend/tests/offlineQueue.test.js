import assert from 'node:assert/strict';
import { describe, it } from 'vitest';
import {
  OFFLINE_QUEUE_KEY,
  backoffMs,
  buildTerrainPointFeature,
  drainOfflineQueue,
  enqueueOfflinePoint,
  isPermanentPostError,
  mapPointValidationStatus,
  readOfflineQueue,
  validateTerrainPointLocal,
  validationFilterParams,
  writeOfflineQueue,
} from '../js/core/offlineQueue.js';

function memoryStorage(initial = {}) {
  const store = { ...initial };
  return {
    getItem(key) {
      return Object.prototype.hasOwnProperty.call(store, key) ? store[key] : null;
    },
    setItem(key, value) {
      store[key] = String(value);
    },
  };
}

describe('buildTerrainPointFeature', () => {
  it('format GeoJSON + client_id idempotent', () => {
    const body = buildTerrainPointFeature({
      lon: 1.35,
      lat: 6.4,
      ph: 6.2,
      humidityPct: 35,
      soilType: 'limoneux',
      collectedAt: '2026-03-10',
      clientId: 'fixed-id',
    });
    assert.equal(body.type, 'Feature');
    assert.deepEqual(body.geometry.coordinates, [1.35, 6.4]);
    assert.equal(body.properties.client_id, 'fixed-id');
    assert.equal(body.properties.source, 'terrain');
  });
});

describe('validateTerrainPointLocal', () => {
  it('accepte un point Maritime valide', () => {
    assert.deepEqual(
      validateTerrainPointLocal({ lon: 1.35, lat: 6.4, ph: 6.2, humidityPct: 35 }),
      {},
    );
  });

  it('rejette pH et bbox hors plage', () => {
    const err = validateTerrainPointLocal({ lon: 5, lat: 5, ph: 2, humidityPct: 35 });
    assert.ok(err.ph);
    assert.ok(err.location);
  });
});

describe('offline queue drain', () => {
  it('enqueue et read persistents avec client_id', () => {
    const storage = memoryStorage();
    const body = buildTerrainPointFeature({
      lon: 1.2, lat: 6.3, ph: 7, humidityPct: 40, soilType: 'argileux', collectedAt: '2026-01-01',
    });
    enqueueOfflinePoint({ body }, { storage, now: () => 42 });
    const q = readOfflineQueue(storage);
    assert.equal(q.length, 1);
    assert.equal(q[0].queued_at, 42);
    assert.ok(q[0].body.properties.client_id);
  });

  it('drain : retries transitoires, dead-letter permanente', async () => {
    const items = [
      { body: { id: 'ok' }, queued_at: 1, attempts: 0 },
      { body: { id: 'fail400' }, queued_at: 2, attempts: 0 },
      { body: { id: 'retry' }, queued_at: 3, attempts: 0 },
    ];
    const { remaining, deadLetter, synced } = await drainOfflineQueue(
      items,
      async (body) => {
        if (body.id === 'fail400') {
          const e = new Error('pH hors plage');
          e.status = 400;
          throw e;
        }
        if (body.id === 'retry') {
          const e = new Error('network');
          e.status = 503;
          throw e;
        }
      },
      { now: () => 1000, maxAttempts: 5 },
    );
    assert.equal(synced, 1);
    assert.equal(deadLetter.length, 1);
    assert.equal(deadLetter[0].body.id, 'fail400');
    assert.equal(remaining.length, 1);
    assert.equal(remaining[0].body.id, 'retry');
    assert.equal(remaining[0].attempts, 1);
    assert.ok(remaining[0].next_retry_at > 1000);
  });

  it('writeOfflineQueue vide la clé partagée', () => {
    const storage = memoryStorage({ [OFFLINE_QUEUE_KEY]: '[{}]' });
    writeOfflineQueue([], storage);
    assert.equal(storage.getItem(OFFLINE_QUEUE_KEY), '[]');
  });
});

describe('helpers', () => {
  it('isPermanentPostError', () => {
    assert.equal(isPermanentPostError({ status: 400 }), true);
    assert.equal(isPermanentPostError({ status: 503 }), false);
  });

  it('backoffMs borne', () => {
    assert.equal(backoffMs(1), 2000);
    assert.ok(backoffMs(10) <= 60000);
  });

  it('mapPointValidationStatus', () => {
    assert.equal(mapPointValidationStatus({ validation_status: 'rejected' }), 'rejected');
    assert.equal(mapPointValidationStatus({ is_validated: true }), 'validated');
  });

  it('validationFilterParams', () => {
    assert.deepEqual(validationFilterParams('validated'), { is_validated: 'true' });
    assert.deepEqual(validationFilterParams('pending'), { validation_status: 'pending' });
    assert.deepEqual(validationFilterParams('all'), {});
  });
});
