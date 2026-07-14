/**
 * File d'attente points sol hors ligne — alignée mobile OfflineQueueService.
 * Clé localStorage partagée : sig_sols_offline_queue
 */

export const OFFLINE_QUEUE_KEY = 'sig_sols_offline_queue';
export const OFFLINE_DEAD_LETTER_KEY = 'sig_sols_offline_dead';
export const MAX_SYNC_ATTEMPTS = 5;
export const MARITIME_BBOX = { minLon: 0.9, minLat: 6.0, maxLon: 1.8, maxLat: 6.8 };

export function readOfflineQueue(storage = globalThis.localStorage) {
  return _readList(storage, OFFLINE_QUEUE_KEY);
}

export function writeOfflineQueue(items, storage = globalThis.localStorage) {
  storage.setItem(OFFLINE_QUEUE_KEY, JSON.stringify(items));
}

export function readDeadLetter(storage = globalThis.localStorage) {
  return _readList(storage, OFFLINE_DEAD_LETTER_KEY);
}

export function writeDeadLetter(items, storage = globalThis.localStorage) {
  storage.setItem(OFFLINE_DEAD_LETTER_KEY, JSON.stringify(items));
}

function _readList(storage, key) {
  try {
    const parsed = JSON.parse(storage.getItem(key) || '[]');
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export function newClientId(randomUUID = globalThis.crypto?.randomUUID?.bind(globalThis.crypto)) {
  if (typeof randomUUID === 'function') return randomUUID();
  return `cli_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

/** Validation locale (même règles que validators.py) avant enqueue. */
export function validateTerrainPointLocal({ lon, lat, ph, humidityPct }) {
  const errors = {};
  if (ph == null || ph < 3.5 || ph > 9.5) {
    errors.ph = 'pH hors plage valide (3,5 – 9,5).';
  }
  if (humidityPct == null || humidityPct < 0 || humidityPct > 100) {
    errors.humidity_pct = 'Humidité hors plage (0 – 100 %).';
  }
  if (
    lon == null || lat == null
    || lon < MARITIME_BBOX.minLon || lon > MARITIME_BBOX.maxLon
    || lat < MARITIME_BBOX.minLat || lat > MARITIME_BBOX.maxLat
  ) {
    errors.location = 'Coordonnées hors Région Maritime (pilote).';
  }
  return errors;
}

export function enqueueOfflinePoint(payload, {
  storage = globalThis.localStorage,
  now = Date.now,
} = {}) {
  const q = readOfflineQueue(storage);
  const body = payload.body || payload;
  const clientId = body?.properties?.client_id || newClientId();
  if (body?.properties && !body.properties.client_id) {
    body.properties.client_id = clientId;
  }
  q.push({
    ...payload,
    body,
    client_id: clientId,
    queued_at: now(),
    attempts: payload.attempts || 0,
  });
  writeOfflineQueue(q, storage);
  return q;
}

export function backoffMs(attempts, base = 2000) {
  return Math.min(base * (2 ** Math.max(0, attempts - 1)), 60000);
}

export function isPermanentPostError(err) {
  const status = err?.status ?? err?.response?.status ?? err?.statusCode;
  if (status === 400 || status === 403 || status === 401 || status === 409) return true;
  const msg = String(err?.message || err || '');
  if (/pH hors|Humidité hors|Coordonnées hors|permission|403|400/i.test(msg)) return true;
  return false;
}

/**
 * POST séquentiel avec retry/backoff + dead-letter (erreurs permanentes / max attempts).
 * @returns {{ remaining, deadLetter, synced, errors: string[] }}
 */
export async function drainOfflineQueue(items, postPoint, {
  now = Date.now,
  maxAttempts = MAX_SYNC_ATTEMPTS,
} = {}) {
  const remaining = [];
  const deadLetter = [];
  const errors = [];
  let synced = 0;
  const t = now();

  for (const item of items) {
    if (item.next_retry_at && item.next_retry_at > t) {
      remaining.push(item);
      continue;
    }
    try {
      await postPoint(item.body);
      synced += 1;
    } catch (err) {
      const attempts = (item.attempts || 0) + 1;
      const lastError = err?.message || String(err);
      const updated = { ...item, attempts, last_error: lastError };
      if (isPermanentPostError(err) || attempts >= maxAttempts) {
        deadLetter.push({ ...updated, dead_at: t });
        errors.push(`Point ${item.client_id || '?'}: ${lastError}`);
      } else {
        remaining.push({ ...updated, next_retry_at: t + backoffMs(attempts) });
        errors.push(`Retry ${attempts}/${maxAttempts}: ${lastError}`);
      }
    }
  }
  return { remaining, deadLetter, synced, errors };
}

/** GeoJSON Feature identique web ↔ mobile (+ client_id idempotent). */
export function buildTerrainPointFeature({
  lon, lat, ph, humidityPct, soilType, collectedAt, source = 'terrain', clientId,
}) {
  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [lon, lat] },
    properties: {
      ph,
      humidity_pct: humidityPct,
      soil_type: soilType,
      collected_at: collectedAt,
      source,
      client_id: clientId || newClientId(),
    },
  };
}

/** Statut popup carte à partir de la réponse light API. */
export function mapPointValidationStatus(props = {}) {
  if (props.validation_status) return props.validation_status;
  return props.is_validated ? 'validated' : 'pending';
}

/** Mode filtre validation: validated | pending | all | rejected */
export function validationFilterParams(mode) {
  if (mode === 'validated') return { is_validated: 'true' };
  if (mode === 'pending') return { validation_status: 'pending' };
  if (mode === 'rejected') return { validation_status: 'rejected' };
  return {};
}
