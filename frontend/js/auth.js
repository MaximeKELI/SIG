/**
 * Interface d'authentification — connexion, inscription, profil, déconnexion.
 */
import { toast } from './core/toast.js';
import { notifyError, notifySuccess } from './core/ui.js';
import { trackAuth } from './core/activityTracker.js';

const ROLE_LABELS = {
  admin: 'Administrateur',
  agent: 'Agent',
  public: 'Public',
};

function $(id) {
  return document.getElementById(id);
}

function profilePhotoUrl(path) {
  if (!path) return '';
  if (path.startsWith('http')) return path;
  return `${window.location.origin}${path.startsWith('/') ? '' : '/'}${path}`;
}

function renderProfileStats(user) {
  const el = $('prof-stats');
  if (!el) return;
  const s = user?.profile_stats;
  if (!s) {
    el.textContent = '';
    return;
  }
  const parts = [
    `${s.videos ?? 0} vidéo(s) publiée(s)`,
    `${s.shorts ?? 0} short(s)`,
  ];
  if (s.pending > 0) {
    parts.push(`${s.pending} en attente de validation`);
  }
  el.textContent = parts.join(' · ');
}

function renderProfileAvatar(user) {
  const img = $('prof-avatar-img');
  const ph = $('prof-avatar-placeholder');
  const headerImg = $('header-avatar-img');
  const headerPh = $('header-avatar-placeholder');
  const url = user?.profile_photo_url ? profilePhotoUrl(user.profile_photo_url) : '';
  const initial = (user?.first_name?.[0] || user?.username?.[0] || '?').toUpperCase();

  if (img) {
    if (url) {
      img.src = url;
      img.classList.remove('hidden');
      ph?.classList.add('hidden');
    } else {
      img.classList.add('hidden');
      img.removeAttribute('src');
      if (ph) {
        ph.textContent = initial;
        ph.classList.remove('hidden');
      }
    }
  } else if (ph) {
    ph.textContent = initial;
    ph.classList.remove('hidden');
  }

  if (headerImg) {
    if (url) {
      headerImg.src = url;
      headerImg.classList.remove('hidden');
      headerPh?.classList.add('hidden');
    } else {
      headerImg.classList.add('hidden');
      headerImg.removeAttribute('src');
      if (headerPh) {
        headerPh.textContent = initial;
        headerPh.classList.remove('hidden');
      }
    }
  } else if (headerPh) {
    headerPh.textContent = initial;
    headerPh.classList.remove('hidden');
  }
}

function showAuthTab(tab) {
  const loginForm = $('auth-login-form');
  const registerForm = $('auth-register-form');
  document.querySelectorAll('[data-auth-tab]').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.authTab === tab);
  });
  loginForm?.classList.toggle('hidden', tab !== 'login');
  registerForm?.classList.toggle('hidden', tab !== 'register');
}

function renderAuthUI() {
  const guest = $('auth-guest');
  const logged = $('auth-user');
  const user = SigSolsAPI.getUser();
  const authed = SigSolsAPI.isAuthenticated();

  const adminNav = document.querySelector('.nav-btn[data-view="admin"]');
  if (authed && user) {
    document.getElementById('welcome-banner')?.classList.add('hidden');
    guest?.classList.add('hidden');
    logged?.classList.remove('hidden');
    const label = $('auth-user-label');
    if (label) {
      label.textContent = `${user.username} · ${ROLE_LABELS[user.role] || user.role}`;
    }
    renderProfileAvatar(user);
    adminNav?.classList.toggle('hidden', user.role !== 'admin');
    window.SigSolsFeatures?.applyPublicMode();
    window.SigSolsFeatures?.connectWebSocket();
    window.SigSolsFeatures?.loadAlerts();
    window.SigSolsFeatures?.loadNotifications();
    window.SigSolsFeaturesHub?.refreshNotificationBadge?.();
    window.dispatchEvent(new Event('sig-auth-changed'));
    window.SigSolsVideos?.updateAuthPanels?.();
  } else {
    guest?.classList.remove('hidden');
    logged?.classList.add('hidden');
    adminNav?.classList.add('hidden');
    window.dispatchEvent(new Event('sig-auth-changed'));
    window.SigSolsVideos?.updateAuthPanels?.();
  }
}

async function handleForgotPassword() {
  const email = prompt('Email du compte :');
  if (!email) return;
  const msg = $('auth-message');
  try {
    await SigSolsAPI.api('/platform/password/reset/', {
      method: 'POST',
      body: JSON.stringify({ email }),
    });
    if (msg) {
      msg.textContent = 'Si un compte existe, un email a été envoyé (voir logs serveur en dev).';
      msg.className = 'auth-message success';
    }
  } catch (e) {
    if (msg) {
      msg.textContent = e.message;
      msg.className = 'auth-message error';
    }
  }
}

async function handleLogin() {
  const msg = $('auth-message');
  try {
    await SigSolsAPI.login(
      $('login-user')?.value?.trim(),
      $('login-pass')?.value,
    );
    if (msg) {
      msg.textContent = '';
      msg.className = 'auth-message';
    }
    renderAuthUI();
    notifySuccess('Connexion réussie.');
    trackAuth('login', { username: $('login-user')?.value?.trim() });
    SigSolsMap.loadSoilPoints();
    SigSolsFeatures.loadAlerts();
    SigSolsFeatures.loadNotifications();
    SigSolsFeatures.connectWebSocket();
    if ($('share-location')?.checked) SigSolsMap.startLiveLocation();
  } catch (e) {
    notifyError(e);
    if (msg) {
      msg.textContent = e.message;
      msg.className = 'auth-message error';
    }
  }
}

async function handleRegister() {
  const msg = $('auth-message');
  if (!$('reg-privacy')?.checked) {
    if (msg) {
      msg.textContent = 'Vous devez accepter la politique de confidentialité pour créer un compte.';
      msg.className = 'auth-message error';
    }
    return;
  }
  try {
    await SigSolsAPI.register({
      username: $('reg-user')?.value?.trim(),
      email: $('reg-email')?.value?.trim() || '',
      password: $('reg-pass')?.value,
      password_confirm: $('reg-pass2')?.value,
      first_name: $('reg-first')?.value?.trim(),
      last_name: $('reg-last')?.value?.trim(),
      age: parseInt($('reg-age')?.value, 10),
      phone: $('reg-phone')?.value?.trim() || '',
      gender: $('reg-gender')?.value || '',
      city: $('reg-city')?.value?.trim() || '',
      region: $('reg-region')?.value?.trim() || 'Maritime',
      profession: $('reg-profession')?.value?.trim() || '',
      education_level: $('reg-education')?.value || '',
      motivation: $('reg-motivation')?.value?.trim() || '',
      pseudonym: $('reg-pseudo')?.value?.trim() || '',
      role: $('reg-role')?.value || 'public',
      organization: $('reg-org')?.value?.trim() || '',
      consent_analytics: !!$('reg-consent')?.checked,
    });
    trackAuth('register', { username: $('reg-user')?.value?.trim() });
    if (msg) {
      msg.textContent = 'Compte créé — connectez-vous.';
      msg.className = 'auth-message success';
    }
    showAuthTab('login');
    $('login-user').value = $('reg-user')?.value || '';
  } catch (e) {
    if (msg) {
      msg.textContent = e.message;
      msg.className = 'auth-message error';
    }
  }
}

async function handleLogout() {
  const confirmed = window.confirm('Voulez-vous vraiment vous déconnecter ?');
  if (!confirmed) {
    toast('Déconnexion annulée.', 'info');
    return;
  }
  trackAuth('logout');
  await SigSolsMap.stopLiveLocation();
  await SigSolsAPI.logout();
  renderAuthUI();
  $('auth-profile-modal')?.classList.add('hidden');
  document.getElementById('welcome-banner')?.classList.remove('hidden');
  toast('Déconnexion réussie.', 'info');
}

function openProfileModal() {
  const user = SigSolsAPI.getUser();
  if (!user) return;
  $('prof-email').value = user.email || '';
  $('prof-first').value = user.first_name || '';
  $('prof-last').value = user.last_name || '';
  $('prof-org').value = user.organization || '';
  $('prof-phone').value = user.phone || '';
  $('prof-pseudo').value = user.pseudonym || '';
  $('prof-bio').value = user.bio || '';
  $('prof-photo-file').value = '';
  renderProfileAvatar(user);
  renderProfileStats(user);
  $('profile-message').textContent = '';
  $('auth-profile-modal')?.classList.remove('hidden');
}

async function saveProfile() {
  const msg = $('profile-message');
  try {
    await SigSolsAPI.updateProfile({
      email: $('prof-email').value,
      first_name: $('prof-first').value,
      last_name: $('prof-last').value,
      organization: $('prof-org').value,
      phone: $('prof-phone').value,
      pseudonym: $('prof-pseudo').value,
      bio: $('prof-bio').value?.trim().slice(0, 300),
    });
    if (msg) {
      msg.textContent = 'Profil enregistré.';
      msg.className = 'auth-message success';
    }
    renderProfileStats(SigSolsAPI.getUser());
    renderAuthUI();
  } catch (e) {
    if (msg) {
      msg.textContent = e.message;
      msg.className = 'auth-message error';
    }
  }
}

async function uploadProfilePhoto() {
  const msg = $('profile-message');
  const file = $('prof-photo-file')?.files?.[0];
  if (!file) {
    if (msg) {
      msg.textContent = 'Choisissez une image (jpg, png, webp, gif — max 5 Mo).';
      msg.className = 'auth-message error';
    }
    return;
  }
  const ext = (file.name.split('.').pop() || '').toLowerCase();
  const okExt = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
  if (!okExt.includes(ext)) {
    const err = 'Format non supporté. Utilisez JPG, PNG, WebP ou GIF.';
    if (msg) {
      msg.textContent = err;
      msg.className = 'auth-message error';
    }
    notifyError(err);
    return;
  }
  if (file.size > 5 * 1024 * 1024) {
    const err = 'Image trop volumineuse (max 5 Mo).';
    if (msg) {
      msg.textContent = err;
      msg.className = 'auth-message error';
    }
    notifyError(err);
    return;
  }
  if (typeof SigSolsAPI.uploadProfilePhoto !== 'function') {
    notifyError('Fonction upload indisponible — rechargez la page (Ctrl+F5).');
    return;
  }
  try {
    if (msg) {
      msg.textContent = 'Envoi en cours…';
      msg.className = 'auth-message';
    }
    const user = await SigSolsAPI.uploadProfilePhoto(file);
    renderProfileAvatar(user);
    renderProfileStats(user);
    renderAuthUI();
    if (msg) {
      msg.textContent = 'Photo enregistrée.';
      msg.className = 'auth-message success';
    }
    notifySuccess('Photo de profil mise à jour.');
  } catch (e) {
    if (msg) {
      msg.textContent = e.message;
      msg.className = 'auth-message error';
    }
    notifyError(e.message);
  }
}

async function removeProfilePhoto() {
  const msg = $('profile-message');
  try {
    const user = await SigSolsAPI.removeProfilePhoto();
    $('prof-photo-file').value = '';
    renderProfileAvatar(user);
    renderAuthUI();
    if (msg) {
      msg.textContent = 'Photo supprimée.';
      msg.className = 'auth-message success';
    }
  } catch (e) {
    if (msg) {
      msg.textContent = e.message;
      msg.className = 'auth-message error';
    }
  }
}

async function savePassword() {
  const msg = $('profile-message');
  try {
    await SigSolsAPI.changePassword(
      $('prof-old-pass').value,
      $('prof-new-pass').value,
      $('prof-new-pass2').value,
    );
    $('prof-old-pass').value = '';
    $('prof-new-pass').value = '';
    $('prof-new-pass2').value = '';
    if (msg) {
      msg.textContent = 'Mot de passe mis à jour.';
      msg.className = 'auth-message success';
    }
  } catch (e) {
    if (msg) {
      msg.textContent = e.message;
      msg.className = 'auth-message error';
    }
  }
}

async function initAuth() {
  document.querySelectorAll('[data-auth-tab]').forEach((btn) => {
    btn.addEventListener('click', () => showAuthTab(btn.dataset.authTab));
  });
  $('btn-login')?.addEventListener('click', handleLogin);
  $('btn-forgot-pass')?.addEventListener('click', handleForgotPassword);
  $('btn-register')?.addEventListener('click', handleRegister);
  $('btn-logout')?.addEventListener('click', handleLogout);
  $('btn-profile')?.addEventListener('click', openProfileModal);
  const closeProfile = () => $('auth-profile-modal')?.classList.add('hidden');
  $('btn-profile-close')?.addEventListener('click', closeProfile);
  $('btn-profile-close-footer')?.addEventListener('click', closeProfile);
  $('btn-profile-save')?.addEventListener('click', saveProfile);
  $('btn-profile-photo-upload')?.addEventListener('click', uploadProfilePhoto);
  $('btn-profile-photo-remove')?.addEventListener('click', removeProfilePhoto);
  $('prof-photo-file')?.addEventListener('change', () => {
    const file = $('prof-photo-file')?.files?.[0];
    if (!file) return;
    const url = URL.createObjectURL(file);
    const img = $('prof-avatar-img');
    const ph = $('prof-avatar-placeholder');
    if (img) {
      img.src = url;
      img.classList.remove('hidden');
      ph?.classList.add('hidden');
    }
  });
  $('btn-password-save')?.addEventListener('click', savePassword);
  $('login-pass')?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') handleLogin();
  });

  if (SigSolsAPI.isAuthenticated()) {
    try {
      await SigSolsAPI.fetchProfile();
    } catch {
      SigSolsAPI.clearSession();
    }
  }
  renderAuthUI();
  showAuthTab('login');
}

window.SigSolsAuth = { initAuth, renderAuthUI };
