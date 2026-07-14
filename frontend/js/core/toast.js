/** Notifications toast non bloquantes — structure icon + message + dismiss. */
let container = null;

const ICONS = {
  success: '✓',
  error: '!',
  warning: '!',
  info: 'i',
};

export function initToast() {
  if (container) return;
  container = document.createElement('div');
  container.id = 'toast-container';
  container.className = 'toast-container';
  container.setAttribute('aria-live', 'polite');
  container.setAttribute('aria-atomic', 'false');
  document.body.appendChild(container);
}

export function toast(message, type = 'info', duration = 4200) {
  initToast();
  const el = document.createElement('div');
  el.className = `toast toast-${type}`;
  el.setAttribute('role', type === 'error' ? 'alert' : 'status');

  const icon = document.createElement('span');
  icon.className = 'toast-icon';
  icon.setAttribute('aria-hidden', 'true');
  icon.textContent = ICONS[type] || ICONS.info;

  const text = document.createElement('span');
  text.className = 'toast-message';
  text.textContent = message;

  const dismiss = document.createElement('button');
  dismiss.type = 'button';
  dismiss.className = 'toast-dismiss';
  dismiss.setAttribute('aria-label', 'Fermer');
  dismiss.textContent = '×';

  el.append(icon, text, dismiss);
  container.appendChild(el);
  requestAnimationFrame(() => el.classList.add('toast-visible'));

  const remove = () => {
    el.classList.remove('toast-visible');
    el.classList.add('toast-exit');
    setTimeout(() => el.remove(), 320);
  };
  dismiss.addEventListener('click', remove);
  el.addEventListener('click', (e) => {
    if (e.target === dismiss) return;
  });
  setTimeout(remove, duration);
}
