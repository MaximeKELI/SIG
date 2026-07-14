import { phColorHex } from './core/phColor.js';
import {
  parseLiveUsers,
  peerLocationStyle,
  selfLocationStyle,
} from './core/geolocationUtils.js';
import { createLocationTracker } from './core/locationTracker.js';
import {
  MARITIME_CENTER,
  bboxFromLeaflet,
  buildSoilFiltersQuery,
  markerStyleForPoint,
  nasaTileUrl,
  parseSoilPointsList,
} from './core/mapUtils.js';
import { mapPointValidationStatus } from './core/offlineQueue.js';
import {
  analyzeBboxNdvi,
  initSentinelMapTools,
  loadSentinelToggles,
} from './sentinelMap.js';
import {
  initWeatherMapTools,
  loadWeatherStatus,
  showWeatherAtPoint,
} from './weatherMap.js';
import { showLoading } from './core/ui.js';
import { notifyError, notifySuccess } from './core/ui.js';
import { toast } from './core/toast.js';

let map, markersLayer, usersLayer, nasaOverlays = {};
let mapReady = false;
let loadDebounce = null;
let loadSeq = 0;
let bboxLoadEnabled = true;
let locationTracker = null;
let selfMarker = null;
let accuracyCircle = null;
const peerMarkers = new Map();

const basemaps = {
  osm: L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© OpenStreetMap',
  }),
  satellite: L.tileLayer(
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    { attribution: 'Esri' },
  ),
  topo: L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {
    attribution: 'OpenTopoMap',
  }),
};

function initMap() {
  map = L.map('map', { center: MARITIME_CENTER, zoom: 9 });
  basemaps.osm.addTo(map);
  L.control.layers(
    { 'OpenStreetMap': basemaps.osm, 'Satellite': basemaps.satellite, 'Topographique': basemaps.topo },
  ).addTo(map);
  markersLayer = L.layerGroup().addTo(map);
  usersLayer = L.layerGroup().addTo(map);
  mapReady = true;
  window.SigSolsFeatures?.initMapAdvanced(map, markersLayer);
  window.SigSolsParcel?.initParcelTools?.();
  let lastZoomTrack = 0;
  let lastPanTrack = 0;
  map.on('moveend', () => {
    if (bboxLoadEnabled) {
      clearTimeout(loadDebounce);
      loadDebounce = setTimeout(() => loadSoilPoints({ showOverlay: false }), 450);
    }
    const now = Date.now();
    if (now - lastPanTrack < 2000) return;
    lastPanTrack = now;
    import('./core/activityTracker.js').then(({ trackMapPan }) => {
      trackMapPan(map.getCenter(), map.getZoom());
    }).catch(() => {});
  });
  map.on('zoomend', () => {
    const now = Date.now();
    if (now - lastZoomTrack < 800) return;
    lastZoomTrack = now;
    import('./core/activityTracker.js').then(({ trackMapZoom }) => {
      trackMapZoom(map.getZoom(), map.getCenter());
    }).catch(() => {});
  });
  loadSoilPoints({ showOverlay: true });
  loadNasaToggles();
  loadSentinelToggles();
  initSentinelMapTools();
  loadWeatherStatus().then(() => initWeatherMapTools());
}

function updateSelfMarker(lat, lon, accuracy_m) {
  if (!map) return;
  const latlng = [lat, lon];
  if (!selfMarker) {
    selfMarker = L.circleMarker(latlng, selfLocationStyle()).addTo(usersLayer);
    selfMarker.bindPopup('<strong>Ma position</strong>');
  } else {
    selfMarker.setLatLng(latlng);
  }
  if (accuracyCircle) {
    usersLayer.removeLayer(accuracyCircle);
    accuracyCircle = null;
  }
  if (accuracy_m && accuracy_m < 500) {
    accuracyCircle = L.circle(latlng, {
      radius: accuracy_m,
      color: '#3b82f6',
      fillOpacity: 0.08,
      weight: 1,
    }).addTo(usersLayer);
  }
}

function peerMarkerIcon(u) {
  const color = u.role === 'admin' ? '#b45309' : '#059669';
  const photo = u.profilePhotoUrl
    ? (u.profilePhotoUrl.startsWith('http') ? u.profilePhotoUrl : `${window.location.origin}${u.profilePhotoUrl}`)
    : '';
  if (photo) {
    return L.divIcon({
      className: 'peer-marker-icon',
      html: `<img src="${photo}" alt="" width="32" height="32" style="border-radius:50%;border:2px solid ${color};object-fit:cover" />`,
      iconSize: [32, 32],
      iconAnchor: [16, 16],
    });
  }
  return L.divIcon({
    className: 'peer-marker-icon',
    html: `<span style="display:block;width:14px;height:14px;border-radius:50%;background:${color};border:2px solid #fff"></span>`,
    iconSize: [14, 14],
    iconAnchor: [7, 7],
  });
}

function renderPeerMarkers(users) {
  if (!usersLayer) return;
  const seen = new Set();
  parseLiveUsers({ users }).forEach((u) => {
    seen.add(u.id);
    const latlng = [u.lat, u.lon];
    let marker = peerMarkers.get(u.id);
    if (!marker) {
      marker = L.marker(latlng, { icon: peerMarkerIcon(u) });
      const profileBtn = u.username
        ? `<br/><button type="button" class="btn-link map-profile-link" data-username="${u.username}">Voir profil</button>`
        : '';
      marker.bindPopup(`<strong>${u.displayName}</strong><br/>Rôle: ${u.role}${profileBtn}`);
      marker.addTo(usersLayer);
      peerMarkers.set(u.id, marker);
    } else {
      marker.setLatLng(latlng);
      marker.setIcon(peerMarkerIcon(u));
    }
  });
  peerMarkers.forEach((marker, id) => {
    if (!seen.has(id)) {
      usersLayer.removeLayer(marker);
      peerMarkers.delete(id);
    }
  });
}

async function startLiveLocation() {
  if (!SigSolsAPI.getToken()) {
    toast('Connectez-vous pour partager votre position.', 'warning');
    return;
  }
  if (locationTracker?.isActive()) return;
  locationTracker = createLocationTracker({
    api: (path, opts) => SigSolsAPI.api(path, opts),
    onSelfUpdate: (p) => updateSelfMarker(p.lat, p.lon, p.accuracy_m),
    onPeersUpdate: (data) => renderPeerMarkers(data.users),
    onError: (e) => {
      const el = document.getElementById('location-status');
      if (el) el.textContent = e.message;
    },
  });
  try {
    await locationTracker.start();
    const el = document.getElementById('location-status');
    if (el) el.textContent = 'Position partagée en direct';
    document.getElementById('btn-location-toggle')?.classList.add('active');
    notifySuccess('GPS activé.');
  } catch (e) {
    notifyError(e);
  }
}

async function stopLiveLocation() {
  if (locationTracker) {
    await locationTracker.stop();
    locationTracker = null;
  }
  usersLayer?.clearLayers();
  peerMarkers.clear();
  selfMarker = null;
  accuracyCircle = null;
  const el = document.getElementById('location-status');
  if (el) el.textContent = 'Localisation désactivée';
  document.getElementById('btn-location-toggle')?.classList.remove('active');
}

async function toggleLiveLocation() {
  if (locationTracker?.isActive()) await stopLiveLocation();
  else await startLiveLocation();
}

async function loadSoilPoints({ showOverlay = true } = {}) {
  const seq = ++loadSeq;
  if (showOverlay) showLoading(true);
  try {
    const validationMode = document.getElementById('filter-validation')?.value || 'validated';
    const query = buildSoilFiltersQuery({
      phMin: document.getElementById('filter-ph-min')?.value,
      phMax: document.getElementById('filter-ph-max')?.value,
      soilType: document.getElementById('filter-soil-type')?.value,
      validationMode,
      bbox: document.getElementById('filter-bbox')?.checked ? bboxFromLeaflet(map) : '',
    });
    const data = await SigSolsAPI.api('/points/?' + query);
    if (seq !== loadSeq) return;
    markersLayer.clearLayers();
    window.SigSolsFeatures?.clearClusters();
    parseSoilPointsList(data).forEach((props) => {
      const coords = [props.lon, props.lat];
      const style = markerStyleForPoint(props);
      const marker = L.circleMarker([coords[1], coords[0]], style);
      const status = mapPointValidationStatus(props);
      const lon = coords[0];
      const lat = coords[1];
      marker.bindPopup(`
        <strong>Point #${props.id}</strong> (${status})<br/>
        pH: ${props.ph} · Humidité: ${props.humidity_pct}%<br/>
        Type: ${props.soil_type}<br/>
        NDVI terrain: ${props.ndvi_3m_avg ?? '—'} · SMAP: ${props.smap_moisture_avg ?? '—'}<br/>
        <button type="button" class="btn-sm" data-sentinel-point="${lat},${lon}">NDVI Sentinel (zone)</button>
        <button type="button" onclick="predictAtPoint(${props.ph}, ${props.humidity_pct}, '${props.soil_type}')">Prédire fertilité</button>
        <button type="button" onclick="SigSolsFeatures.loadNdviChart(${props.id}, 'ndvi-${props.id}')">Série NDVI NASA</button>
        <div id="ndvi-${props.id}"></div>
      `);
      marker.on('popupopen', () => {
        const sentinelBtn = document.querySelector(`[data-sentinel-point="${lat},${lon}"]`);
        sentinelBtn?.addEventListener('click', () => {
          const d = 0.015;
          analyzeBboxNdvi([lon - d, lat - d, lon + d, lat + d], `point #${props.id}`);
        }, { once: true });
        const weatherBtn = document.querySelector(`[data-weather-point="${lat},${lon}"]`);
        weatherBtn?.addEventListener('click', () => {
          showWeatherAtPoint(lat, lon);
        }, { once: true });
      });
      // Un seul parent Leaflet : cluster si dispo, sinon layer brute (évite flash double-add)
      if (!window.SigSolsFeatures?.addMarkerToCluster?.(marker)) {
        markersLayer.addLayer(marker);
      }
    });
  } catch (e) {
    if (seq === loadSeq) notifyError(e);
  } finally {
    if (showOverlay && seq === loadSeq) showLoading(false);
  }
}

function getMap() {
  return map;
}

function onWsLocation(msg) {
  if (msg.user_id && msg.lat != null) {
    renderPeerMarkers({
      users: [{ id: msg.user_id, lat: msg.lat, lon: msg.lon, role: msg.role || 'agent', displayName: msg.username || 'Agent' }],
    });
  }
}

async function loadNasaToggles() {
  try {
    const summary = await SigSolsAPI.api('/nasa/catalog/summary/');
    const container = document.getElementById('nasa-layers-toggles');
    container.innerHTML = '';
    (summary.by_product || []).forEach((p) => {
      const label = document.createElement('label');
      label.innerHTML = `<input type="checkbox" data-product="${p.product}" /> ${p.product} (${p.count})`;
      label.querySelector('input').addEventListener('change', (e) => toggleNasaLayer(p.product, e.target.checked));
      container.appendChild(label);
    });
  } catch {
  }
}

function toggleNasaLayer(product, on) {
  if (on && !nasaOverlays[product]) {
    const today = new Date().toISOString().slice(0, 10);
    nasaOverlays[product] = L.tileLayer(
      nasaTileUrl(window.location.origin, product, today),
      { opacity: 0.35 },
    ).addTo(map);
  } else if (!on && nasaOverlays[product]) {
    map.removeLayer(nasaOverlays[product]);
    delete nasaOverlays[product];
  }
}

window.predictAtPoint = async (ph, humidity, soilType) => {
  document.getElementById('pred-ph').value = ph;
  document.getElementById('pred-humidity').value = humidity;
  document.getElementById('pred-soil-type').value = soilType;
  await runPrediction();
};

async function runPrediction() {
  try {
    const body = {
      ph: parseFloat(document.getElementById('pred-ph').value),
      humidity_pct: parseFloat(document.getElementById('pred-humidity').value),
      soil_type: document.getElementById('pred-soil-type').value,
    };
    const r = await SigSolsAPI.api('/ml/predict/', { method: 'POST', body: JSON.stringify(body) });
    const el = document.getElementById('pred-result');
    if (el) {
      el.innerHTML = `<strong>${r.predicted_class || r.fertility_class || '—'}</strong>
        <br/>Confiance : ${((r.confidence || 0) * 100).toFixed(0)}%
        <br/><small>${r.recommendation || ''}</small>`;
    }
    notifySuccess('Prédiction terminée.');
  } catch (e) {
    notifyError(e);
  }
}

async function exportWithAuth(path, filename) {
  try {
    await SigSolsAPI.download(path, filename);
    notifySuccess(`Export ${filename} lancé.`);
  } catch (e) {
    notifyError(e);
  }
}

window.SigSolsMap = {
  initMap,
  getMap,
  getBasemaps: () => basemaps,
  loadSoilPoints,
  loadSentinelToggles,
  loadWeatherStatus,
  runPrediction,
  startLiveLocation,
  stopLiveLocation,
  toggleLiveLocation,
  onWsLocation,
  exportWithAuth,
};
