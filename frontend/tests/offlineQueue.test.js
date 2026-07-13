import assert from 'node:assert/strict';
import { describe, it } from 'vitest';
import {
  OFFLINE_QUEUE_KEY,
  buildTerrainPointFeature,
  drainOfflineQueue,
  enqueueOfflinePoint,
  mapPointValidationStatus,
  readOfflineQueue,
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
  it('format GeoJSON identique mobile OfflineQueueService', () => {
    const body = buildTerrainPointFeature({
      lon: 1.35,
      lat: 6.4,
      ph: 6.2,
      humidityPct: 35,
      soilType: 'limoneux',
      collectedAt: '2026-03-10',
    });
    assert.equal(body.type, 'Feature');
    assert.deepEqual(body.geometry.coordinates, [1.35, 6.4]);
    assert.equal(body.properties.humidity_pct, 35);
    assert.equal(body.properties.source, 'terrain');
    assert.equal(body.properties.collected_at, '2026-03-10');
  });
});

describe('offline queue', () => {
  it('enqueue et read persistents', () => {
    const storage = memoryStorage();
    const body = buildTerrainPointFeature({
      lon: 1.2, lat: 6.3, ph: 7, humidityPct: 40, soilType: 'argileux', collectedAt: '2026-01-01',
    });
    enqueueOfflinePoint({ body }, { storage, now: () => 42 });
    const q = readOfflineQueue(storage);
    assert.equal(q.length, 1);
    assert.equal(q[0].queued_at, 42);
    assert.equal(q[0].body.properties.soil_type, 'argileux');
  });

  it('drain sync partiel conserve les échecs', async () => {
    const items = [
      { body: { id: 'ok' }, queued_at: 1 },
      { body: { id: 'fail' }, queued_at: 2 },
      { body: { id: 'ok2' }, queued_at: 3 },
    ];
    const { remaining, synced } = await drainOfflineQueue(items, async (body) => {
      if (body.id === 'fail') throw new Error('network');
    });
    assert.equal(synced, 2);
    assert.equal(remaining.length, 1);
    assert.equal(remaining[0].body.id, 'fail');
  });

  it('writeOfflineQueue vide la clé partagée', () => {
    const storage = memoryStorage({ [OFFLINE_QUEUE_KEY]: '[{}]' });
    writeOfflineQueue([], storage);
    assert.equal(storage.getItem(OFFLINE_QUEUE_KEY), '[]');
  });
});

describe('mapPointValidationStatus', () => {
  it('préfère validation_status light API', () => {
    assert.equal(mapPointValidationStatus({ validation_status: 'rejected', is_validated: false }), 'rejected');
  });

  it('fallback is_validated', () => {
    assert.equal(mapPointValidationStatus({ is_validated: true }), 'validated');
    assert.equal(mapPointValidationStatus({}), 'pending');
  });
});
