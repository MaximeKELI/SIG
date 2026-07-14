/**
 * Panneau admin — analytics & activité utilisateurs (data science).
 */
let activityChart = null;

function setText(id, v) {
  const el = document.getElementById(id);
  if (el) el.textContent = v ?? '—';
}

export function applyAnalyticsPayload(data) {
  if (!data) return;
  setText('an-events-total', data.events_total);
  setText('an-events-today', data.events_today);
  setText('an-map-zoom', data.map_zoom_total);
  setText('an-map-pan', data.map_pan_total);
  setText('an-users-total', data.users_total);

  const top = document.getElementById('an-top-users');
  if (top) {
    top.innerHTML = (data.top_users || []).map(
      (u) => `<tr><td><button type="button" class="btn-link an-user-pick" data-uid="${u.user_id}">${u.username}</button></td><td>${u.count}</td></tr>`,
    ).join('') || '<tr><td colspan="2">Aucune donnée</td></tr>';
    top.querySelectorAll('.an-user-pick').forEach((btn) => {
      btn.addEventListener('click', () => loadUserActivity(btn.dataset.uid));
    });
  }

  const ev = document.getElementById('an-event-types');
  if (ev) {
    ev.innerHTML = (data.by_event_type || []).slice(0, 15).map(
      (r) => `<li><span>${r.event_type}</span><em>${r.count}</em></li>`,
    ).join('');
  }

  const age = document.getElementById('an-age-buckets');
  if (age && data.age_distribution) {
    age.innerHTML = Object.entries(data.age_distribution).map(
      ([k, v]) => `<li>${k} : <strong>${v}</strong></li>`,
    ).join('');
  }

  renderActivityChart(data.by_day || []);
}

export async function loadAdminAnalytics() {
  if (!SigSolsAPI.getToken()) return;
  try {
    const data = await SigSolsAPI.api('/platform/admin/analytics/?days=30');
    applyAnalyticsPayload(data);
  } catch (e) {
    console.warn('Analytics', e);
  }
}

function renderActivityChart(byDay) {
  const canvas = document.getElementById('chart-activity-canvas');
  if (!canvas || typeof Chart === 'undefined') return;
  const labels = byDay.map((d) => d.day);
  const values = byDay.map((d) => d.count);
  if (activityChart) activityChart.destroy();
  activityChart = new Chart(canvas, {
    type: 'line',
    data: {
      labels,
      datasets: [{
        label: 'Événements / jour',
        data: values,
        borderColor: '#166534',
        tension: 0.25,
        fill: false,
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: { y: { beginAtZero: true } },
    },
  });
}

export async function loadUserActivity(userId) {
  if (!userId) return;
  const box = document.getElementById('an-user-detail');
  if (!box) return;
  box.innerHTML = '<p>Chargement…</p>';
  try {
    const data = await SigSolsAPI.api(`/platform/admin/activity/users/${userId}/?days=90`);
    const u = data.user || {};
    const types = (data.by_event_type || []).map(
      (t) => `<li>${t.event_type} : <strong>${t.count}</strong></li>`,
    ).join('');
    const timeline = (data.timeline || []).slice(0, 80).map(
      (e) => `<li><time>${(e.created_at || '').slice(0, 19).replace('T', ' ')}</time> — ${e.event_type} <small>(${e.category})</small></li>`,
    ).join('');
    box.innerHTML = `
      <h4>${u.first_name || ''} ${u.last_name || ''} (@${u.username || userId})</h4>
      <p>${u.email || ''} · ${u.age ?? '—'} ans · ${u.role || ''} · ${u.region || ''}</p>
      <p><strong>${data.events_total}</strong> événements (90 j.)</p>
      <ul class="an-type-list">${types || '<li>—</li>'}</ul>
      <h5>Dernières actions</h5>
      <ul class="an-timeline compact-list">${timeline || '<li>—</li>'}</ul>`;
  } catch (e) {
    box.innerHTML = `<p class="error">${e.message}</p>`;
  }
}

export async function loadRecentActivity() {
  const ul = document.getElementById('an-recent-activity');
  if (!ul) return;
  try {
    const rows = await SigSolsAPI.api('/platform/admin/activity/?limit=50');
    const list = rows.results || rows;
    ul.innerHTML = (list || []).map(
      (e) => `<li>${(e.created_at || '').slice(0, 16)} — ${e.username || e.session_id?.slice(0, 8)} — <strong>${e.event_type}</strong> (${e.view_name || e.category})</li>`,
    ).join('');
  } catch {
    ul.innerHTML = '<li>Non disponible</li>';
  }
}

export function initAdminAnalytics() {
  document.getElementById('btn-an-load-user')?.addEventListener('click', () => {
    const id = document.getElementById('an-user-id')?.value?.trim();
    if (id) loadUserActivity(id);
  });
}

window.SigSolsAdminAnalytics = {
  loadAdminAnalytics,
  applyAnalyticsPayload,
  loadUserActivity,
  loadRecentActivity,
  initAdminAnalytics,
};
