/**
 * Bootstrap UX : thème, i18n, toasts, raccourcis, onboarding, connexion.
 */
import { initToast } from './core/toast.js';
import { initI18n, toggleLang, applyI18n } from './core/i18n.js?v=21';
import { initTheme, toggleTheme } from './core/theme.js?v=21';
import { initShortcuts } from './core/shortcuts.js?v=21';
import { initOnboarding } from './core/onboarding.js?v=21';
import {
  initConnectionBanner,
  initModals,
} from './core/ui.js?v=21';
import { initUxShell, updateOfflineQueuePill } from './core/ux.js?v=21';
import { initGallery } from './gallery.js?v=21';

export function initAppShell() {
  initToast();
  initI18n();
  initTheme();
  initShortcuts();
  initConnectionBanner();
  initUxShell();
  initModals();
  initGallery();
  window.SigSolsUx = { updateOfflineQueuePill };
  document.getElementById('btn-theme')?.addEventListener('click', toggleTheme);
  document.getElementById('btn-lang')?.addEventListener('click', () => {
    toggleLang();
    applyI18n();
  });
  document.getElementById('btn-help-tour')?.addEventListener('click', () => {
    localStorage.removeItem('sig_sols_onboarding_done');
    initOnboarding();
  });
  const welcome = document.getElementById('welcome-banner');
  if (welcome && !SigSolsAPI?.isAuthenticated?.()) {
    welcome.classList.remove('hidden');
  }
  setTimeout(initOnboarding, 800);
}

window.SigSolsInit = { initAppShell };
