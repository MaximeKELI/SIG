/**
 * Suivi d’activité utilisateur — envoi par lots vers l’API platform/activity/.
 */
const FLUSH_MS = 4000;
const MAX_QUEUE = 80;

let queue = [];
let flushTimer = null;
let currentView = 'map';

function getSessionId() {
  const key = 'sig_sols_session_id';
  let id = sessionStorage.getItem(key);
  if (!id) {
    id = `${Date.now()}-${Math.random().toString(36).slice(2, 12)}`;
    sessionStorage.setItem(key, id);
  }
  return id;
}

function clientMeta() {
  return {
    path: location.pathname,
    href: location.href.split('?')[0],
    lang: navigator.language || '',
    screen: `${window.screen?.width || 0}x${window.screen?.height || 0}`,
  };
}

export function setActivityView(viewName) {
  currentView = viewName || 'map';
}

function hasAnalyticsConsent() {
  const u = window.SigSolsAPI?.getUser?.();
  return u?.consent_analytics === true;
}

export function trackActivity(eventType, detail = {}, category = 'other') {
  if (!hasAnalyticsConsent()) return;
  queue.push({
    event_type: String(eventType).slice(0, 80),
    category: String(category).slice(0, 20),
    view_name: currentView,
    detail: { ...detail, ...clientMeta(), ts: Date.now() },
  });
  if (queue.length >= MAX_QUEUE) flushActivity();
  else scheduleFlush();
}

function scheduleFlush() {
  if (flushTimer) return;
  flushTimer = setTimeout(() => {
    flushTimer = null;
    flushActivity();
  }, FLUSH_MS);
}

export async function flushActivity() {
  if (!hasAnalyticsConsent()) {
    queue = [];
    return;
  }
  if (!queue.length) return;
  const batch = queue.splice(0, MAX_QUEUE);
  const body = {
    session_id: getSessionId(),
    events: batch,
  };
  try {
    const headers = { 'Content-Type': 'application/json' };
    const token = window.SigSolsAPI?.getToken?.();
    if (token) headers.Authorization = `Bearer ${token}`;
    await fetch(`${window.location.origin}/api/v1/platform/activity/`, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
      keepalive: true,
    });
  } catch {
    queue.unshift(...batch);
  }
}

export function initActivityTracker() {
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') flushActivity();
  });
  window.addEventListener('beforeunload', () => flushActivity());
  trackActivity('session_start', {}, 'navigation');
}

export function trackNav(view) {
  setActivityView(view);
  trackActivity('view_open', { view }, 'navigation');
}

export function trackMapZoom(zoom, center) {
  trackActivity('map_zoom', {
    zoom,
    lat: center?.lat,
    lon: center?.lng ?? center?.lon,
  }, 'map');
}

export function trackMapPan(center, zoom) {
  trackActivity('map_pan', {
    zoom,
    lat: center?.lat,
    lon: center?.lng ?? center?.lon,
  }, 'map');
}

export function trackAuth(action, detail = {}) {
  trackActivity(action, detail, 'auth');
}

export function trackApi(path, method, status) {
  trackActivity('api_call', { path, method, status }, 'api');
}
