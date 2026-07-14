/**
 * OpenWeather — intégration carte (popup, contrôle, badge, parcelles).
 */
import { MARITIME_CENTER } from './core/mapUtils.js';
import { notifyError } from './core/ui.js';

let clickProbeEnabled = false;
let autoBadgeEnabled = true;
let weatherConfigured = null; // null = unknown, false = no key, true = ok
let clickHandler = null;
let moveendHandler = null;
let moveDebounce = null;
let lastProbeMarker = null;
let weatherControl = null;

function escapeHtml(s) {
  const d = document.createElement('div');
  d.textContent = s ?? '';
  return d.innerHTML;
}

function getMap() {
  return window.SigSolsMap?.getMap?.();
}

function iconUrl(icon) {
  if (!icon) return '';
  return `https://openweathermap.org/img/wn/${icon}@2x.png`;
}

export function formatCurrentBlock(data) {
  const c = data?.current || {};
  const icon = c.icon ? `<img src="${iconUrl(c.icon)}" alt="" width="48" height="48" class="weather-popup-icon" />` : '';
  const loc = c.location || data?.city || '';
  return `
    <div class="weather-current weather-current--popup">
      ${icon}
      <div>
        <strong class="weather-temp">${c.temp_c != null ? `${Math.round(c.temp_c)}°C` : '—'}</strong>
        ${c.feels_like_c != null ? `<span class="weather-feels">ressenti ${Math.round(c.feels_like_c)}°C</span>` : ''}
        <p>${escapeHtml(c.description || '—')}${loc ? ` · ${escapeHtml(loc)}` : ''}</p>
        <p class="weather-meta">
          Humidité ${c.humidity_pct ?? '—'}% · Vent ${c.wind_speed_ms ?? '—'} m/s
          ${c.wind_deg != null ? ` (${c.wind_deg}°)` : ''}
          ${c.rain_1h_mm ? ` · Pluie ${c.rain_1h_mm} mm/h` : ''}
        </p>
      </div>
    </div>`;
}

function formatForecastList(items) {
  if (!items?.length) return '<p class="weather-empty">Aucune prévision.</p>';
  return `<ul class="weather-forecast-list">
    ${items.map((f) => {
      const when = f.dt ? new Date(f.dt * 1000).toLocaleString('fr-FR', {
        weekday: 'short', hour: '2-digit', minute: '2-digit',
      }) : '—';
      const pop = f.pop != null ? `${Math.round(f.pop * 100)}% pluie` : '';
      return `<li>
        <span>${when}</span>
        <strong>${f.temp_c != null ? `${Math.round(f.temp_c)}°C` : '—'}</strong>
        <em>${escapeHtml(f.description || '')}</em>
        <small>${pop}</small>
      </li>`;
    }).join('')}
  </ul>`;
}

function formatPopupHtml(data, lat, lon) {
  if (!data?.current) {
    return `<p class="weather-popup-err">${escapeHtml(data?.detail || data?.error || 'Météo indisponible')}</p>`;
  }
  return `
    <div class="weather-map-popup">
      <strong>OpenWeather</strong>
      <p class="weather-coords">${lat.toFixed(4)}°, ${lon.toFixed(4)}°</p>
      ${formatCurrentBlock(data)}
      <p class="weather-popup-credit"><small>Données © OpenWeatherMap</small></p>
    </div>`;
}

export function updateMapBadge(data) {
  const badge = document.getElementById('weather-map-badge');
  if (!badge) return;
  const cur = data?.current;
  if (!cur || cur.temp_c == null) {
    badge.classList.add('hidden');
    return;
  }
  badge.classList.remove('hidden');
  const icon = cur.icon ? `<img src="${iconUrl(cur.icon)}" alt="" width="22" height="22" />` : '';
  badge.innerHTML = `${icon}<span>${Math.round(cur.temp_c)}°C · ${escapeHtml(cur.description || '')}</span>`;
}

function setProbeMarker(lat, lon) {
  const map = getMap();
  if (!map) return;
  if (lastProbeMarker) {
    map.removeLayer(lastProbeMarker);
    lastProbeMarker = null;
  }
  lastProbeMarker = L.circleMarker([lat, lon], {
    radius: 7,
    color: '#1d4ed8',
    fillColor: '#3b82f6',
    fillOpacity: 0.75,
    weight: 2,
  }).addTo(map);
}

export async function loadWeatherStatus() {
  const statusEl = document.getElementById('weather-status-msg');
  if (!statusEl) return false;
  try {
    const status = await SigSolsAPI.api('/weather/status/');
    weatherConfigured = Boolean(status.ok);
    statusEl.textContent = status.message || (status.ok ? 'OpenWeather OK' : 'Non configuré');
    statusEl.classList.toggle('weather-status--ok', weatherConfigured);
    statusEl.classList.toggle('weather-status--err', !weatherConfigured);
    if (weatherConfigured && autoBadgeEnabled) {
      refreshWeatherAtMapCenter('current', { silent: true });
    } else {
      document.getElementById('weather-map-badge')?.classList.add('hidden');
    }
    return weatherConfigured;
  } catch (e) {
    weatherConfigured = false;
    statusEl.textContent = e.message || 'OpenWeather indisponible';
    statusEl.classList.add('weather-status--err');
    document.getElementById('weather-map-badge')?.classList.add('hidden');
    return false;
  }
}

export async function fetchWeatherAt(lat, lon, kind = 'current') {
  const path = kind === 'forecast'
    ? `/weather/forecast/?lat=${lat}&lon=${lon}`
    : `/weather/current/?lat=${lat}&lon=${lon}`;
  return SigSolsAPI.api(path);
}

export async function showWeatherAtPoint(lat, lon, latlng = null) {
  const map = getMap();
  if (!map) return null;
  const ll = latlng || L.latLng(lat, lon);
  const popup = L.popup({ maxWidth: 300, className: 'weather-leaflet-popup' })
    .setLatLng(ll)
    .setContent('<p class="weather-loading">Chargement météo…</p>')
    .openOn(map);

  try {
    const data = await fetchWeatherAt(lat, lon, 'current');
    popup.setContent(formatPopupHtml(data, lat, lon));
    updateMapBadge(data);
    setProbeMarker(lat, lon);
    const out = document.getElementById('weather-out');
    if (out) {
      out.innerHTML = `<p class="weather-coords">${lat.toFixed(3)}°, ${lon.toFixed(3)}°</p>${formatCurrentBlock(data)}`;
    }
    return data;
  } catch (e) {
    const msg = e.message || e.detail || 'Erreur météo';
    popup.setContent(`<p class="weather-popup-err">${escapeHtml(msg)}</p>`);
    notifyError(e);
    return null;
  }
}

export async function refreshWeatherAtMapCenter(kind = 'current', { silent = false } = {}) {
  const map = getMap();
  const out = document.getElementById('weather-out');
  if (!map) {
    if (!silent) notifyError({ message: 'Carte non initialisée.' });
    return null;
  }
  if (weatherConfigured === false) {
    if (out && !silent) {
      out.innerHTML = '<p class="parcel-weather parcel-weather--warn">OpenWeather non configuré (.env)</p>';
    }
    document.getElementById('weather-map-badge')?.classList.add('hidden');
    return null;
  }
  const c = map.getCenter();
  const lat = c.lat;
  const lon = c.lng;
  if (out && !silent) out.textContent = 'Chargement météo…';
  try {
    const data = await fetchWeatherAt(lat, lon, kind);
    weatherConfigured = true;
    if (out) {
      out.innerHTML = kind === 'forecast'
        ? `<p class="weather-coords">${lat.toFixed(3)}°, ${lon.toFixed(3)}°</p>${formatForecastList(data.forecast)}`
        : `<p class="weather-coords">${lat.toFixed(3)}°, ${lon.toFixed(3)}°</p>${formatCurrentBlock(data)}`;
    }
    if (kind === 'current') updateMapBadge(data);
    return data;
  } catch (e) {
    const msg = e.message || e.detail || 'Erreur météo';
    if (/non configuré|OPENWEATHER_API_KEY/i.test(String(msg))) {
      weatherConfigured = false;
      document.getElementById('weather-map-badge')?.classList.add('hidden');
    }
    if (out) out.textContent = msg;
    if (!silent) notifyError(e);
    return null;
  }
}

function bindClickProbe() {
  const map = getMap();
  if (!map) return;

  if (clickHandler) {
    map.off('click', clickHandler);
    clickHandler = null;
  }

  if (!clickProbeEnabled) return;

  clickHandler = (e) => {
    const { lat, lng } = e.latlng;
    showWeatherAtPoint(lat, lng, e.latlng);
  };
  map.on('click', clickHandler);
}

function bindAutoBadge() {
  const map = getMap();
  if (!map) return;

  if (moveendHandler) {
    map.off('moveend', moveendHandler);
    moveendHandler = null;
  }

  if (!autoBadgeEnabled) return;

  moveendHandler = () => {
    if (weatherConfigured === false) return;
    clearTimeout(moveDebounce);
    moveDebounce = setTimeout(() => {
      refreshWeatherAtMapCenter('current', { silent: true });
    }, 800);
  };
  map.on('moveend', moveendHandler);
}

export function setWeatherClickProbe(enabled) {
  clickProbeEnabled = Boolean(enabled);
  const map = getMap();
  if (map && clickProbeEnabled) {
    map.getContainer().classList.add('map-weather-probe');
  } else if (map) {
    map.getContainer().classList.remove('map-weather-probe');
  }
  bindClickProbe();
}

export function setWeatherAutoBadge(enabled) {
  autoBadgeEnabled = Boolean(enabled);
  bindAutoBadge();
  if (autoBadgeEnabled && weatherConfigured === true) {
    refreshWeatherAtMapCenter('current', { silent: true });
  } else {
    document.getElementById('weather-map-badge')?.classList.add('hidden');
  }
}

function addMapControl() {
  const map = getMap();
  if (!map || weatherControl) return;

  const WeatherCtrl = L.Control.extend({
    options: { position: 'topright' },
    onAdd() {
      const btn = L.DomUtil.create('button', 'leaflet-weather-btn');
      btn.type = 'button';
      btn.title = 'Météo au centre de la carte';
      btn.innerHTML = '☁';
      btn.setAttribute('aria-label', 'Météo');
      L.DomEvent.disableClickPropagation(btn);
      L.DomEvent.on(btn, 'click', (e) => {
        L.DomEvent.stop(e);
        const c = map.getCenter();
        showWeatherAtPoint(c.lat, c.lng, c);
      });
      return btn;
    },
  });

  weatherControl = new WeatherCtrl();
  weatherControl.addTo(map);
}

export function initWeatherMapTools() {
  document.getElementById('btn-weather-current')?.addEventListener('click', () => {
    refreshWeatherAtMapCenter('current');
  });
  document.getElementById('btn-weather-forecast')?.addEventListener('click', () => {
    refreshWeatherAtMapCenter('forecast');
  });
  document.getElementById('btn-weather-fit-maritime')?.addEventListener('click', () => {
    getMap()?.setView(MARITIME_CENTER, 9);
    setTimeout(() => refreshWeatherAtMapCenter('current'), 400);
  });

  document.getElementById('weather-click-probe')?.addEventListener('change', (e) => {
    setWeatherClickProbe(e.target.checked);
  });

  const autoEl = document.getElementById('weather-auto-badge');
  if (autoEl) {
    autoBadgeEnabled = autoEl.checked;
    autoEl.addEventListener('change', (e) => setWeatherAutoBadge(e.target.checked));
  }

  addMapControl();
  bindAutoBadge();
  if (weatherConfigured === true && autoBadgeEnabled) {
    refreshWeatherAtMapCenter('current', { silent: true });
  } else if (weatherConfigured === false) {
    document.getElementById('weather-map-badge')?.classList.add('hidden');
  }
}

export function displayWeatherParcelSummary(weather, parcelName = '') {
  const out = document.getElementById('weather-out');
  if (!out) return;

  if (!weather) {
    out.innerHTML = '';
    return;
  }
  if (weather.configured === false) {
    out.innerHTML = '<p class="parcel-weather parcel-weather--warn">OpenWeather non configuré (.env)</p>';
    document.getElementById('weather-map-badge')?.classList.add('hidden');
    return;
  }
  if (weather.error) {
    out.innerHTML = `<p class="weather-popup-err">${escapeHtml(weather.error)}</p>`;
    document.getElementById('weather-map-badge')?.classList.add('hidden');
    return;
  }
  if (weather.current) {
    const label = parcelName ? ` — ${escapeHtml(parcelName)}` : '';
    out.innerHTML = `<p class="weather-coords">Météo parcelle${label}</p>${formatCurrentBlock(weather)}`;
    updateMapBadge(weather);
  }
}

export function clearWeatherParcelSummary() {
  const out = document.getElementById('weather-out');
  if (out) out.innerHTML = '';
  document.getElementById('weather-map-badge')?.classList.add('hidden');
}

export function formatWeatherHtml(weather) {
  if (!weather) return '';
  if (weather.configured === false) {
    return '<p class="parcel-weather parcel-weather--warn">OpenWeather non configuré (.env)</p>';
  }
  if (weather.error) {
    return `<p class="parcel-weather parcel-weather--warn">Météo : ${escapeHtml(weather.error)}</p>`;
  }
  const c = weather.current || {};
  if (c.temp_c == null && !c.description) return '';
  const tips = (weather.agro_tips || []).slice(0, 2).map((t) => ` · ${escapeHtml(t)}`).join('');
  return `<p class="parcel-weather">Météo : <strong>${c.temp_c != null ? `${Math.round(c.temp_c)}°C` : '—'}</strong>`
    + `, ${escapeHtml(c.description || '')}`
    + ` · humidité ${c.humidity_pct ?? '—'}%${tips}</p>`;
}
