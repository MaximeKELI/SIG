import { phColorHex } from './phColor.js';

export const MARITIME_CENTER = [6.4, 1.35];

/** Normalise la réponse API points (pagination ou GeoJSON). */
export function parseSoilPointsList(data) {
  if (!data) return [];
  if (Array.isArray(data)) return data;
  if (data.results) return data.results;
  if (data.features) {
    return data.features.map((f) => ({
      ...(f.properties || {}),
      lon: f.geometry?.coordinates?.[0],
      lat: f.geometry?.coordinates?.[1],
    }));
  }
  return [];
}

export function buildSoilFiltersQuery({
  phMin, phMax, soilType, validated, validationMode, bbox, light = true,
}) {
  const params = new URLSearchParams();
  if (light) params.set('light', '1');
  if (phMin) params.set('ph_min', phMin);
  if (phMax) params.set('ph_max', phMax);
  if (soilType) params.set('soil_type', soilType);
  // Mode: validated | pending | rejected | all (prioritaire sur le booléen legacy)
  const mode = validationMode
    || (validated === true ? 'validated' : validated === false ? 'all' : null);
  if (mode === 'validated') params.set('is_validated', 'true');
  else if (mode === 'pending') params.set('validation_status', 'pending');
  else if (mode === 'rejected') params.set('validation_status', 'rejected');
  if (bbox) params.set('bbox', bbox);
  return params.toString();
}

export function bboxFromLeaflet(map) {
  if (!map) return '';
  const b = map.getBounds();
  const sw = b.getSouthWest();
  const ne = b.getNorthEast();
  return `${sw.lng},${sw.lat},${ne.lng},${ne.lat}`;
}

export function markerStyleForPoint(point) {
  const color = phColorHex(point.ph_color || 'green');
  return { fillColor: color, radius: 7, color: '#333', weight: 1, fillOpacity: 0.85 };
}

export function nasaTileUrl(origin, product, dateStr) {
  return `${origin}/api/v1/nasa/tiles/${product}/${dateStr}/{z}/{x}/{y}.png`;
}

export function sentinelTileUrl(origin, layer) {
  return `${origin}/api/v1/sentinel/tiles/${layer}/{z}/{x}/{y}.png`;
}
