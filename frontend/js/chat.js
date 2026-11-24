/**
 * Assistant IA Gemini — chatbot flottant SIG Sols Togo.
 */
import { trackActivity } from './core/activityTracker.js';

const STORAGE_KEY = 'sig_sols_chat_history';
let history = [];
let available = false;
let sending = false;

function loadHistory() {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    history = raw ? JSON.parse(raw) : [];
  } catch {
    history = [];
  }
}

function saveHistory() {
  sessionStorage.setItem(STORAGE_KEY, JSON.stringify(history.slice(-20)));
}

function $(id) {
  return document.getElementById(id);
}

function renderMessages() {
  const box = $('chat-messages');
  if (!box) return;
  if (!history.length) {
    box.innerHTML = '<p class="chat-empty">Posez une question sur les sols, les parcelles, le quiz ou la carte.</p>';
    return;
  }
  box.innerHTML = history.map((m) => `
    <div class="chat-msg chat-msg--${m.role === 'user' ? 'user' : 'bot'}">
      <span class="chat-msg-label">${m.role === 'user' ? 'Vous' : 'Assistant'}</span>
      <div class="chat-msg-body">${escapeHtml(m.content)}</div>
    </div>`).join('');
  box.scrollTop = box.scrollHeight;
}

function escapeHtml(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/\n/g, '<br>');
}

function buildContext() {
  const ctx = {
    view: document.querySelector('.nav-btn.active')?.dataset?.view || 'home',
  };
  const parcel = window.SigSolsParcel?.getLastParcelData?.();
  if (parcel) {
    ctx.parcel = {
      zone_code: parcel.zone_code,
      zone_name: parcel.zone_name,
      area_ha: parcel.area_ha,
      soil_summary: parcel.soil_summary,
      ml_prediction: parcel.ml_prediction,
      ndvi: parcel.ndvi,
      smap: parcel.smap,
    };
  }
  const user = window.SigSolsAPI?.getUser?.();
  if (user) {
    ctx.user = { username: user.username, role: user.role, region: user.region };
  }
  return ctx;
}

function setStatus(text, isError = false) {
  const el = $('chat-status');
  if (!el) return;
  el.textContent = text || '';
  el.classList.toggle('chat-status--error', isError);
}

async function checkStatus() {
  const api = window.SigSolsAPI;
  if (!api?.api) {
    available = false;
    setStatus('API non chargée — rechargez la page.', true);
    return;
  }
  try {
    const data = await api.api('/assistant/status/');
    available = Boolean(data.available);
    setStatus(
      available
        ? `En ligne · ${data.model || 'Gemini'}`
        : 'Assistant indisponible (clé API non configurée)',
      !available,
    );
  } catch (e) {
    available = false;
    setStatus(`Impossible de joindre l’assistant : ${e.message}`, true);
  }
}

async function sendMessage() {
  if (sending) return;
  const input = $('chat-input');
  const text = input?.value?.trim();
  if (!text) {
    setStatus('Saisissez un message.', true);
    return;
  }
  const api = window.SigSolsAPI;
  if (!api?.api) {
    setStatus('API non chargée — rechargez la page.', true);
    return;
  }

  sending = true;
  $('btn-chat-send')?.setAttribute('disabled', 'true');
  input.value = '';

  history.push({ role: 'user', content: text });
  renderMessages();
  saveHistory();
  trackActivity('chat_message', { len: text.length }, 'tool');

  const typing = document.createElement('div');
  typing.className = 'chat-msg chat-msg--bot chat-msg--typing';
  typing.innerHTML = '<span class="chat-msg-label">Assistant</span><div class="chat-msg-body">…</div>';
  $('chat-messages')?.appendChild(typing);

  try {
    const payload = {
      message: text,
      history: history.slice(0, -1).slice(-10),
      context: buildContext(),
    };
    const data = await api.api('/assistant/chat/', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    history.push({ role: 'assistant', content: data.reply });
    trackActivity('chat_reply', {}, 'tool');
  } catch (e) {
    const hint = /not found/i.test(e.message)
      ? ' (le serveur backend doit être redémarré : make fix-web)'
      : '';
    history.push({
      role: 'assistant',
      content: `Désolé, une erreur s’est produite : ${e.message}${hint}`,
    });
  } finally {
    sending = false;
    $('btn-chat-send')?.removeAttribute('disabled');
    saveHistory();
    renderMessages();
    input?.focus();
  }
}

function setChatOpen(open) {
  const panel = $('chat-panel');
  const fab = $('btn-chat-toggle');
  if (!panel) return;
  panel.classList.toggle('hidden', !open);
  fab?.setAttribute('aria-expanded', String(open));
  if (open) {
    renderMessages();
    $('chat-input')?.focus();
  }
}

function toggleChat(forceClose) {
  const panel = $('chat-panel');
  if (!panel) return;
  if (forceClose === true) setChatOpen(false);
  else if (forceClose === false) setChatOpen(true);
  else setChatOpen(panel.classList.contains('hidden'));
}

export function initChatbot() {
  loadHistory();
  checkStatus();

  $('btn-chat-toggle')?.addEventListener('click', () => toggleChat());
  $('btn-chat-close')?.addEventListener('click', () => toggleChat(true));
  $('btn-chat-send')?.addEventListener('click', (e) => {
    e.preventDefault();
    sendMessage();
  });
  $('btn-chat-clear')?.addEventListener('click', () => {
    history = [];
    saveHistory();
    renderMessages();
  });

  $('chat-input')?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  });

  document.querySelectorAll('.chat-suggest').forEach((btn) => {
    btn.addEventListener('click', () => {
      const input = $('chat-input');
      if (input) input.value = btn.dataset.prompt || '';
      toggleChat(false);
      sendMessage();
    });
  });
}

window.SigSolsChat = { initChatbot, toggleChat, checkStatus };
