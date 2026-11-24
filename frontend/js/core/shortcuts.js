import { toast } from './toast.js';
import { t } from './i18n.js?v=23';

export function initShortcuts() {
  document.addEventListener('keydown', (e) => {
    if (e.target.matches('input, textarea, select') && e.key !== 'Escape') return;
    if (e.key === '?' && !e.ctrlKey && !e.metaKey) {
      e.preventDefault();
      toast(t('shortcut.help'), 'info', 6000);
      return;
    }
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    const views = { h: 'home', m: 'map', d: 'dashboard', q: 'quiz', s: 'sheets', a: 'admin' };
    const v = views[e.key.toLowerCase()];
    if (!v) return;
    const btn = document.querySelector(`.nav-btn[data-view="${v}"]`);
    if (btn && !btn.classList.contains('hidden')) {
      e.preventDefault();
      btn.click();
    }
    if (e.key === 'Escape') {
      document.querySelectorAll('.auth-modal:not(.hidden), .app-modal:not(.hidden)').forEach((m) => {
        m.classList.add('hidden');
      });
      document.getElementById('sidebar')?.classList.remove('sidebar-open');
    }
  });
}
