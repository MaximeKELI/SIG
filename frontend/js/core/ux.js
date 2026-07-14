/**
 * Micro-interactions shell : auth compacte, chips validation, sidebar, file offline.
 */
import { readDeadLetter, readOfflineQueue } from './offlineQueue.js';

export function initAuthCompact() {
  const header = document.querySelector('.app-header');
  const cta = document.getElementById('btn-auth-cta');
  const guest = document.getElementById('auth-guest');
  if (!header || !cta || !guest) return;

  cta.addEventListener('click', (e) => {
    e.stopPropagation();
    header.classList.add('auth-open');
    guest.querySelector('#login-user')?.focus();
  });

  document.addEventListener('click', (e) => {
    if (!header.classList.contains('auth-open')) return;
    if (guest.contains(e.target) || cta.contains(e.target)) return;
    header.classList.remove('auth-open');
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') header.classList.remove('auth-open');
  });
}

export function initValidationChips() {
  const select = document.getElementById('filter-validation');
  const chips = document.querySelectorAll('.chip[data-validation]');
  if (!select || !chips.length) return;

  const syncChips = () => {
    chips.forEach((chip) => {
      chip.classList.toggle('active', chip.dataset.validation === select.value);
    });
  };

  chips.forEach((chip) => {
    chip.addEventListener('click', () => {
      select.value = chip.dataset.validation;
      syncChips();
      select.dispatchEvent(new Event('change', { bubbles: true }));
      document.getElementById('btn-apply-filters')?.click();
    });
  });

  select.addEventListener('change', syncChips);
  syncChips();
}

export function setSidebarOpen(open) {
  const sidebar = document.getElementById('sidebar');
  const btn = document.getElementById('btn-sidebar-toggle');
  const backdrop = document.getElementById('sidebar-backdrop');
  if (!sidebar) return;
  sidebar.classList.toggle('sidebar-open', open);
  btn?.setAttribute('aria-expanded', open ? 'true' : 'false');
  if (backdrop) {
    backdrop.hidden = !open;
    backdrop.classList.toggle('visible', open);
  }
  document.body.classList.toggle('sidebar-is-open', open);
}

export function initSidebarUx() {
  const btn = document.getElementById('btn-sidebar-toggle');
  const close = document.getElementById('btn-sidebar-close');
  const backdrop = document.getElementById('sidebar-backdrop');
  const sidebar = document.getElementById('sidebar');
  if (!sidebar) return;

  btn?.addEventListener('click', () => {
    setSidebarOpen(!sidebar.classList.contains('sidebar-open'));
  });
  close?.addEventListener('click', () => setSidebarOpen(false));
  backdrop?.addEventListener('click', () => setSidebarOpen(false));

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && sidebar.classList.contains('sidebar-open')) {
      setSidebarOpen(false);
    }
  });
}

export function updateOfflineQueuePill() {
  const pill = document.getElementById('offline-queue-pill');
  const countEl = document.getElementById('offline-queue-count');
  const label = document.getElementById('offline-queue-label');
  if (!pill) return;
  const pending = readOfflineQueue().length;
  const dead = readDeadLetter().length;
  const total = pending + dead;
  if (total === 0) {
    pill.classList.add('hidden');
    return;
  }
  pill.classList.remove('hidden');
  if (countEl) countEl.textContent = String(pending || dead);
  if (label) {
    label.textContent = pending
      ? (pending > 1 ? 'points à synchroniser' : 'point à synchroniser')
      : (dead > 1 ? 'points invalides' : 'point invalide');
  }
}

export function initOfflineQueuePill() {
  const pill = document.getElementById('offline-queue-pill');
  if (!pill) return;
  pill.addEventListener('click', () => {
    window.SigSolsFeatures?.syncOfflineQueue?.();
    updateOfflineQueuePill();
  });
  updateOfflineQueuePill();
  window.addEventListener('online', () => setTimeout(updateOfflineQueuePill, 400));
}

export function initUxShell() {
  initAuthCompact();
  initValidationChips();
  initSidebarUx();
  initOfflineQueuePill();
}
