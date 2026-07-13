/**
 * File d'attente points sol hors ligne — alignée mobile OfflineQueueService.
 * Clé localStorage partagée : sig_sols_offline_queue
 */

export const OFFLINE_QUEUE_KEY = 'sig_sols_offline_queue';

export function readOfflineQueue(storage = globalThis.localStorage) {
  try {
    const raw = storage.getItem(OFFLINE_QUEUE_KEY);
    const parsed = JSON.parse(raw || '[]');
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export function writeOfflineQueue(items, storage = globalThis.localStorage) {
  storage.setItem(OFFLINE_QUEUE_KEY, JSON.stringify(items));
}

export function enqueueOfflinePoint(payload, {
  storage = globalThis.localStorage,
  now = Date.now,
} = {}) {
  const q = readOfflineQueue(storage);
  q.push({ ...payload, queued_at: now() });
  writeOfflineQueue(q, storage);
  return q;
}

/**
 * POST séquentiel des items ; conserve les échecs (pas de dead-letter).
 * @param {Array<{body: object}>} items
 * @param {(body: object) => Promise<unknown>} postPoint
 */
export async function drainOfflineQueue(items, postPoint) {
  const remaining = [];
  let synced = 0;
  for (const item of items) {
    try {
      await postPoint(item.body);
      synced += 1;
    } catch {
      remaining.push(item);
    }
  }
  return { remaining, synced };
}

/** GeoJSON Feature identique web ↔ mobile. */
export function buildTerrainPointFeature({ lon, lat, ph, humidityPct, soilType, collectedAt, source = 'terrain' }) {
  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [lon, lat] },
    properties: {
      ph,
      humidity_pct: humidityPct,
      soil_type: soilType,
      collected_at: collectedAt,
      source,
    },
  };
}

/** Statut popup carte à partir de la réponse light API. */
export function mapPointValidationStatus(props = {}) {
  if (props.validation_status) return props.validation_status;
  return props.is_validated ? 'validated' : 'pending';
}
