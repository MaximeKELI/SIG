/**
 * Client API REST + authentification JWT.
 * @param {{ baseUrl: string, storage?: Storage, fetchFn?: typeof fetch }} config
 */
export function createApiClient({ baseUrl, storage, fetchFn = fetch }) {
  const store = storage || {
    getItem: () => null,
    setItem: () => {},
    removeItem: () => {},
  };

  const TOKEN_KEY = 'sig_sols_token';
  const REFRESH_KEY = 'sig_sols_refresh';
  const USER_KEY = 'sig_sols_user';

  let accessToken = store.getItem(TOKEN_KEY) || '';
  let refreshToken = store.getItem(REFRESH_KEY) || '';

  function persistSession(data) {
    accessToken = data.access || '';
    refreshToken = data.refresh || refreshToken;
    store.setItem(TOKEN_KEY, accessToken);
    if (refreshToken) store.setItem(REFRESH_KEY, refreshToken);
    if (data.user) store.setItem(USER_KEY, JSON.stringify(data.user));
  }

  function clearSession() {
    accessToken = '';
    refreshToken = '';
    store.removeItem(TOKEN_KEY);
    store.removeItem(REFRESH_KEY);
    store.removeItem(USER_KEY);
  }

  function getUser() {
    try {
      const raw = store.getItem(USER_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  }

  function setUser(user) {
    if (user) store.setItem(USER_KEY, JSON.stringify(user));
    else store.removeItem(USER_KEY);
  }

  async function parseError(res) {
    const err = await res.json().catch(() => ({ detail: res.statusText }));
    if (typeof err === 'object' && err !== null) {
      if (err.detail) return String(err.detail);
      const parts = Object.entries(err).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`);
      if (parts.length) return parts.join(' · ');
    }
    return JSON.stringify(err);
  }

  async function refreshAccessToken() {
    if (!refreshToken) throw new Error('Session expirée — reconnectez-vous.');
    const res = await fetchFn(`${baseUrl}/auth/token/refresh/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh: refreshToken }),
    });
    if (!res.ok) {
      clearSession();
      throw new Error('Session expirée — reconnectez-vous.');
    }
    const data = await res.json();
    accessToken = data.access;
    store.setItem(TOKEN_KEY, accessToken);
    if (data.refresh) {
      refreshToken = data.refresh;
      store.setItem(REFRESH_KEY, refreshToken);
    }
    return data;
  }

  async function api(path, options = {}, retried = false) {
    const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
    if (accessToken) headers.Authorization = `Bearer ${accessToken}`;
    const res = await fetchFn(`${baseUrl}${path}`, { ...options, headers });
    if (res.status === 401 && refreshToken && !retried && !path.includes('/auth/token/')) {
      await refreshAccessToken();
      return api(path, options, true);
    }
    if (!res.ok) throw new Error(await parseError(res));
    if (res.status === 204) return null;
    const ct = res.headers.get('content-type') || '';
    let payload;
    if (ct.includes('application/json')) payload = await res.json();
    else payload = res;
    try {
      const { trackApi } = await import('./activityTracker.js');
      trackApi(path, (options.method || 'GET').toUpperCase(), res.status);
    } catch { /* tracker optional */ }
    return payload;
  }

  async function login(username, password) {
    const data = await api('/auth/token/', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    });
    persistSession(data);
    return data;
  }

  async function register(payload) {
    const data = await api('/auth/register/', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    if (data.user) setUser(data.user);
    return data;
  }

  async function logout() {
    try {
      if (accessToken) {
        await api('/auth/logout/', {
          method: 'POST',
          body: JSON.stringify(refreshToken ? { refresh: refreshToken } : {}),
        });
      }
    } catch {
      /* déconnexion locale même si le serveur échoue */
    }
    clearSession();
  }

  async function fetchProfile() {
    const user = await api('/auth/profile/');
    setUser(user);
    return user;
  }

  async function updateProfile(payload) {
    const user = await api('/auth/profile/', {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
    setUser(user);
    return user;
  }

  async function uploadProfilePhoto(file) {
    const fd = new FormData();
    fd.append('profile_photo', file);
    const user = await upload('/auth/profile/photo/', fd);
    setUser(user);
    return user;
  }

  async function removeProfilePhoto() {
    const headers = {};
    if (accessToken) headers.Authorization = `Bearer ${accessToken}`;
    const res = await fetchFn(`${baseUrl}/auth/profile/photo/`, {
      method: 'DELETE',
      headers,
    });
    if (res.status === 401 && refreshToken) {
      await refreshAccessToken();
      return removeProfilePhoto();
    }
    if (!res.ok) throw new Error(await parseError(res));
    const user = await res.json();
    setUser(user);
    return user;
  }

  async function changePassword(oldPassword, newPassword, newPasswordConfirm) {
    return api('/auth/password/change/', {
      method: 'POST',
      body: JSON.stringify({
        old_password: oldPassword,
        new_password: newPassword,
        new_password_confirm: newPasswordConfirm,
      }),
    });
  }

  function getToken() {
    return accessToken;
  }

  function setToken(token) {
    accessToken = token;
    store.setItem(TOKEN_KEY, token);
  }

  function isAuthenticated() {
    return Boolean(accessToken);
  }

  async function updateLocation(payload) {
    return api('/auth/location/', { method: 'POST', body: JSON.stringify(payload) });
  }

  async function getLiveLocations() {
    return api('/auth/locations/live/');
  }

  async function clearLocation() {
    return api('/auth/location/', { method: 'DELETE' });
  }

  async function upload(path, formData, retried = false) {
    const headers = {};
    if (accessToken) headers.Authorization = `Bearer ${accessToken}`;
    const res = await fetchFn(`${baseUrl}${path}`, { method: 'POST', headers, body: formData });
    if (res.status === 401 && refreshToken && !retried) {
      await refreshAccessToken();
      return upload(path, formData, true);
    }
    if (!res.ok) throw new Error(await parseError(res));
    return res.json();
  }

  async function download(path, filename) {
    const headers = {};
    if (accessToken) headers.Authorization = `Bearer ${accessToken}`;
    const res = await fetchFn(`${baseUrl}${path}`, { headers });
    if (res.status === 401 && refreshToken) {
      await refreshAccessToken();
      return download(path, filename);
    }
    if (!res.ok) throw new Error(await parseError(res));
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  }

  return {
    api,
    login,
    register,
    logout,
    fetchProfile,
    updateProfile,
    uploadProfilePhoto,
    removeProfilePhoto,
    changePassword,
    refreshAccessToken,
    getToken,
    setToken,
    getUser,
    setUser,
    isAuthenticated,
    clearSession,
    updateLocation,
    getLiveLocations,
    clearLocation,
    download,
    upload,
  };
}
