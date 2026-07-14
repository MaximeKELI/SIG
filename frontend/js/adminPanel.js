/**
 * Cockpit administration — charge /platform/admin/cockpit/ et pilote les onglets.
 */
import { notifyError, notifySuccess, showLoading } from './core/ui.js';

let adminPanelReady = false;
let cockpitCache = null;

function setText(id, v) {
  const el = document.getElementById(id);
  if (el) el.textContent = v ?? '—';
}

function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function switchTab(name) {
  document.querySelectorAll('.admin-tab').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.admTab === name);
  });
  document.querySelectorAll('.admin-tab-panel').forEach((panel) => {
    panel.classList.toggle('active', panel.dataset.admPanel === name);
  });
}

export async function trainMlModel() {
  const algo = document.getElementById('adm-ml-algo')?.value || 'RandomForest';
  const msg = document.getElementById('adm-ml-status');
  if (!confirm('Réentraîner le modèle IA ? (peut prendre 1–2 min)')) return;
  showLoading(true);
  try {
    const r = await SigSolsAPI.api('/ml/train/', {
      method: 'POST',
      body: JSON.stringify({ algorithm: algo }),
    });
    if (msg) msg.textContent = `F1 macro : ${r.f1_macro ?? '—'}`;
    notifySuccess('Modèle IA réentraîné.');
    await loadAdminCockpit();
  } catch (e) {
    notifyError(e);
    if (msg) msg.textContent = e.message;
  } finally {
    showLoading(false);
  }
}

export async function triggerNasaIngest() {
  const msg = document.getElementById('adm-nasa-status');
  showLoading(true);
  try {
    const r = await SigSolsAPI.api('/nasa/ingest/', {
      method: 'POST',
      body: JSON.stringify({ enrich_points: true }),
    });
    if (msg) {
      msg.textContent = `Ingestion : ${JSON.stringify(r.ingested || r).slice(0, 120)}…`;
    }
    notifySuccess('Ingestion NASA lancée.');
  } catch (e) {
    notifyError(e);
    if (msg) msg.textContent = e.message;
  } finally {
    showLoading(false);
  }
}

function renderOverview(data) {
  const o = data.overview || {};
  setText('adm-users', o.users_total);
  setText('adm-users-active', o.users_active);
  setText('adm-points', o.soil_points);
  setText('adm-pending', o.pending_validation);
  setText('adm-videos', o.videos_published);
  setText('adm-quizzes', o.quizzes_completed_period);
  setText('adm-agents', o.live_agents);
  setText('adm-alerts', o.active_alerts);
  setText('adm-events', o.events_total);
  setText('adm-events-today', o.events_today);

  const soil = data.soil_stats || {};
  const soilUl = document.getElementById('adm-soil-stats');
  if (soilUl) {
    soilUl.innerHTML = `
      <li>Points validés <em>${soil.total_points ?? '—'}</em></li>
      <li>pH moyen <em>${soil.avg_ph ?? '—'}</em></li>
      <li>Humidité moy. <em>${soil.avg_humidity ?? '—'} %</em></li>
      <li>NDVI moy. <em>${soil.avg_ndvi ?? '—'}</em></li>
      <li>Zones dégradées <em>${soil.degraded_zones_count ?? '—'}</em></li>
    `;
  }

  const ml = o.ml_model;
  setText(
    'adm-ml-overview',
    ml
      ? `${ml.algorithm || '—'} · F1 ${ml.f1_macro ?? '—'} · ${String(ml.trained_at || '').slice(0, 16)}`
      : 'Aucun modèle actif',
  );

  const roles = document.getElementById('adm-roles');
  if (roles) {
    roles.innerHTML = (data.users?.by_role || o.users_by_role || [])
      .map((r) => `<li>${escapeHtml(r.role)} <em>${r.count}</em></li>`)
      .join('') || '<li>—</li>';
  }
}

function renderQueues(data) {
  const soils = document.getElementById('adm-pending-list');
  if (soils) {
    const list = data.queues?.pending_soils || [];
    soils.innerHTML = list.length
      ? list.map((p) => `
          <li>
            #${p.id} — ${escapeHtml(p.soil_type || 'sol')} · pH ${p.ph ?? '—'}
            <button type="button" class="btn-sm" data-validate-point="${p.id}" data-action="validate">OK</button>
            <button type="button" class="btn-sm" data-validate-point="${p.id}" data-action="reject">Refuser</button>
          </li>`).join('')
      : '<li>Aucun point en attente</li>';
    soils.querySelectorAll('[data-validate-point]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        try {
          await window.SigSolsFeatures?.validatePoint?.(
            parseInt(btn.dataset.validatePoint, 10),
            btn.dataset.action,
          );
          await loadAdminCockpit();
        } catch (e) {
          notifyError(e);
        }
      });
    });
  }

  const videos = document.getElementById('adm-videos-pending');
  if (videos) {
    const list = data.queues?.pending_videos || [];
    videos.innerHTML = list.length
      ? list.map((v) => `
          <li>
            #${v.id} — ${escapeHtml(v.title || 'vidéo')}
            <button type="button" class="btn-sm" data-approve-video="${v.id}">Publier</button>
            <button type="button" class="btn-sm" data-reject-video="${v.id}">Refuser</button>
          </li>`).join('')
      : '<li>Aucune vidéo en attente (publication auto activée)</li>';
    videos.querySelectorAll('[data-approve-video]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        try {
          await SigSolsAPI.api(`/videos/posts/${btn.dataset.approveVideo}/approve/`, { method: 'POST' });
          notifySuccess('Vidéo publiée.');
          await loadAdminCockpit();
        } catch (e) {
          notifyError(e);
        }
      });
    });
    videos.querySelectorAll('[data-reject-video]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        try {
          await SigSolsAPI.api(`/videos/posts/${btn.dataset.rejectVideo}/reject/`, {
            method: 'POST',
            body: JSON.stringify({ reason: 'Refusé par un administrateur.' }),
          });
          notifySuccess('Vidéo refusée.');
          await loadAdminCockpit();
        } catch (e) {
          notifyError(e);
        }
      });
    });
  }
}

function renderModeration(data) {
  const comments = document.getElementById('adm-comments-moderation');
  if (comments) {
    const list = data.queues?.comments || [];
    comments.innerHTML = list.length
      ? list.map((c) => `
          <li>
            #${c.id} — <strong>${escapeHtml(c.author_display || c.author_username)}</strong> :
            ${escapeHtml((c.text || '').slice(0, 100))}
            <button type="button" class="btn-sm" data-hide-comment="${c.id}">Masquer</button>
          </li>`).join('')
      : '<li>Aucun commentaire</li>';
    comments.querySelectorAll('[data-hide-comment]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        try {
          await SigSolsAPI.api(`/videos/comments/${btn.dataset.hideComment}/hide/`, { method: 'POST' });
          notifySuccess('Commentaire masqué.');
          await loadAdminCockpit();
        } catch (e) {
          notifyError(e);
        }
      });
    });
  }
}

function renderUsers(data) {
  const tbody = document.getElementById('adm-users-table');
  if (!tbody) return;
  const rows = data.users?.recent || [];
  tbody.innerHTML = rows.map((u) => `
    <tr>
      <td>${u.id}</td>
      <td>${escapeHtml(u.username)}${u.first_name ? ` (${escapeHtml(u.first_name)})` : ''}</td>
      <td>${escapeHtml(u.role)}</td>
      <td>${escapeHtml(u.region || '—')}</td>
      <td>${String(u.date_joined || '').slice(0, 10)}</td>
    </tr>`).join('') || '<tr><td colspan="5">Aucun utilisateur</td></tr>';
}

function renderTerrain(data) {
  const live = document.getElementById('adm-live-agents');
  if (live) {
    const agents = data.terrain?.live_agents || [];
    live.innerHTML = agents.length
      ? agents.map((a) => `
          <li>${escapeHtml(a.display_name)} (@${escapeHtml(a.username)}) · ${a.role}
            · ${a.lat?.toFixed?.(4) ?? '—'}, ${a.lon?.toFixed?.(4) ?? '—'}
          </li>`).join('')
      : '<li>Aucun agent live (5 min)</li>';
  }
  const alerts = document.getElementById('adm-drought-alerts');
  if (alerts) {
    const list = data.terrain?.drought_alerts || [];
    alerts.innerHTML = list.length
      ? list.map((a) => `
          <li>${escapeHtml(a.title || a.level || 'Alerte')} — ${escapeHtml(a.message || a.zone_name || '')}</li>
        `).join('')
      : '<li>Aucune alerte active</li>';
  }
}

function renderAudit(data) {
  const audit = document.getElementById('adm-audit');
  if (!audit) return;
  audit.innerHTML = (data.audit || []).map(
    (a) => `<li>${String(a.created_at || '').slice(0, 16)} — ${escapeHtml(a.username || '?')} — ${escapeHtml(a.action)} ${escapeHtml(a.resource)}</li>`,
  ).join('') || '<li>Aucun audit</li>';
}

function renderAnalyticsFromCockpit(data) {
  const an = data.analytics || {};
  window.SigSolsAdminAnalytics?.applyAnalyticsPayload?.(an);
  const recent = document.getElementById('an-recent-activity');
  if (recent) {
    recent.innerHTML = (data.activity_recent || []).map(
      (e) => `<li>${String(e.created_at || '').slice(0, 16)} — ${escapeHtml(e.username || e.session_id?.slice?.(0, 8) || '?')} — <strong>${escapeHtml(e.event_type)}</strong> (${escapeHtml(e.view_name || e.category || '')})</li>`,
    ).join('') || '<li>Aucune activité</li>';
  }
}

export async function loadAdminCockpit() {
  if (!SigSolsAPI.isAuthenticated()) return;
  try {
    const data = await SigSolsAPI.api('/platform/admin/cockpit/?days=30');
    cockpitCache = data;
    renderOverview(data);
    renderQueues(data);
    renderModeration(data);
    renderUsers(data);
    renderTerrain(data);
    renderAudit(data);
    renderAnalyticsFromCockpit(data);

    // Journal unifié (endpoint dédié — enrichit la modération)
    try {
      const journal = await SigSolsAPI.api('/platform/moderation/journal/');
      const ul = document.getElementById('adm-mod-journal');
      const list = journal.results || journal || [];
      if (ul) {
        ul.innerHTML = list.length
          ? list.slice(0, 40).map((j) => `
              <li>[${escapeHtml(j.kind)}] #${j.id} — ${escapeHtml(j.title || j.text || '')}
                · ${escapeHtml(j.author || '')}</li>`).join('')
          : '<li>Journal vide</li>';
      }
    } catch {
      /* optional */
    }
  } catch (e) {
    console.warn('Admin cockpit', e);
    notifyError(e);
  }
}

export function initAdminPanel() {
  if (adminPanelReady) return;
  adminPanelReady = true;

  document.querySelectorAll('.admin-tab').forEach((btn) => {
    btn.addEventListener('click', () => switchTab(btn.dataset.admTab));
  });
  document.getElementById('btn-adm-refresh')?.addEventListener('click', () => {
    loadAdminCockpit();
  });
  document.getElementById('btn-adm-train-ml')?.addEventListener('click', trainMlModel);
  document.getElementById('btn-adm-nasa-ingest')?.addEventListener('click', triggerNasaIngest);
}

window.SigSolsAdminPanel = {
  initAdminPanel,
  trainMlModel,
  triggerNasaIngest,
  loadAdminCockpit,
  getCockpit: () => cockpitCache,
};
