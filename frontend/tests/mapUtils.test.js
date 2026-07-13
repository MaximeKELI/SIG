import assert from 'node:assert/strict';
import { describe, it } from 'vitest';
import {
  MARITIME_CENTER,
  buildSoilFiltersQuery,
  markerStyleForPoint,
  nasaTileUrl,
  parseSoilPointsList,
} from '../js/core/mapUtils.js';

describe('parseSoilPointsList', () => {
  it('pagination DRF', () => {
    const list = parseSoilPointsList({ results: [{ id: 1, lon: 1.2, lat: 6.3 }] });
    assert.equal(list.length, 1);
  });

  it('tableau direct', () => {
    assert.equal(parseSoilPointsList([{ id: 1 }]).length, 1);
  });

  it('GeoJSON features', () => {
    const list = parseSoilPointsList({
      features: [{ properties: { id: 2, ph: 6 }, geometry: { coordinates: [1.1, 6.2] } }],
    });
    assert.equal(list[0].lon, 1.1);
  });

  it('GeoJSON sans properties', () => {
    const list = parseSoilPointsList({
      features: [{ geometry: { coordinates: [1.0, 6.0] } }],
    });
    assert.equal(list[0].lon, 1.0);
  });

  it('vide si null', () => {
    assert.deepEqual(parseSoilPointsList(null), []);
    assert.deepEqual(parseSoilPointsList({}), []);
  });
});

describe('buildSoilFiltersQuery', () => {
  it('construit les paramètres', () => {
    const q = buildSoilFiltersQuery({ phMin: '5', phMax: '7', soilType: 'limoneux' });
    assert.ok(q.includes('light=1'));
    assert.ok(q.includes('ph_min=5'));
    assert.ok(q.includes('ph_max=7'));
    assert.ok(q.includes('soil_type=limoneux'));
  });

  it('filtre validés uniquement (défaut carte)', () => {
    const q = buildSoilFiltersQuery({ validated: true });
    assert.ok(q.includes('is_validated=true'));
    assert.ok(q.includes('light=1'));
  });

  it('sans light', () => {
    const q = buildSoilFiltersQuery({ light: false });
    assert.ok(!q.includes('light='));
  });
});

describe('markerStyleForPoint', () => {
  it('couleur par défaut verte', () => {
    const s = markerStyleForPoint({});
    assert.equal(s.fillColor, '#40916c');
  });

  it('couleur rouge', () => {
    assert.equal(markerStyleForPoint({ ph_color: 'red' }).fillColor, '#c1121f');
  });
});

describe('nasaTileUrl', () => {
  it('template tuile NASA', () => {
    const url = nasaTileUrl('http://localhost:8081', 'MOD13Q1', '2026-05-01');
    assert.ok(url.includes('MOD13Q1'));
    assert.ok(url.includes('{z}'));
  });
});

describe('MARITIME_CENTER', () => {
  it('coordonnées Togo Maritime', () => {
    assert.equal(MARITIME_CENTER[0], 6.4);
    assert.equal(MARITIME_CENTER[1], 1.35);
  });
});
