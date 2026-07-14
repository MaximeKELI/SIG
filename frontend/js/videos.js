/**
 * Vidéos communauté & Shorts — upload, likes, commentaires et réponses.
 */

const API = () => window.SigSolsAPI;
const ORIGIN = () => window.location.origin;

const CATEGORY_LABELS = {
  sols: 'Sols & agriculture',
  nasa: 'NASA & satellite',
  sig: 'SIG & cartographie',
  formation: 'Formation',
  autre: 'Autre',
};

function mediaUrl(path) {
  if (!path) return '';
  if (path.startsWith('http')) return path;
  return `${ORIGIN()}${path.startsWith('/') ? '' : '/'}${path}`;
}

function escapeHtml(s) {
  const d = document.createElement('div');
  d.textContent = s ?? '';
  return d.innerHTML;
}

function statusLabel(status) {
  const map = {
    pending: 'En attente',
    published: 'Publié',
    rejected: 'Refusé',
  };
  return map[status] || status;
}

function statusClass(status) {
  return `video-status video-status--${status}`;
}

async function fetchPosts(kind, extraParams = {}) {
  const params = new URLSearchParams({ kind, ordering: '-created_at', ...extraParams });
  const data = await API().api(`/videos/posts/?${params}`);
  return data.results ?? data;
}

async function fetchComments(postId) {
  return API().api(`/videos/posts/${postId}/comments/`);
}

function buildCommentTree(comments) {
  const byId = new Map();
  const roots = [];
  comments.forEach((c) => {
    byId.set(c.id, { ...c, replies: [] });
  });
  byId.forEach((c) => {
    if (c.parent_id && byId.has(c.parent_id)) {
      byId.get(c.parent_id).replies.push(c);
    } else {
      roots.push(c);
    }
  });
  return roots;
}

export function likeApiPath(target, id) {
  return target === 'post'
    ? `/videos/posts/${id}/toggle_like/`
    : `/videos/comments/${id}/toggle_like/`;
}

export { buildCommentTree };

function likeBtnHtml(liked, count, target, id, label = 'J’aime') {
  const cls = liked ? 'video-like-btn is-liked' : 'video-like-btn';
  const n = Number(count) || 0;
  const on = Boolean(liked);
  return `<button type="button" class="${cls}" data-like-target="${target}" data-like-id="${id}" aria-pressed="${on}">
    <span class="video-like-icon" aria-hidden="true">${on ? '♥' : '♡'}</span> ${label}
    <span class="video-like-count">${n}</span>
  </button>`;
}

function updateLikeButton(btn, liked, count) {
  btn.classList.toggle('is-liked', liked);
  btn.setAttribute('aria-pressed', String(Boolean(liked)));
  const icon = btn.querySelector('.video-like-icon');
  if (icon) icon.textContent = liked ? '♥' : '♡';
  const countEl = btn.querySelector('.video-like-count');
  if (countEl) countEl.textContent = String(Number(count) || 0);
}

function authorAvatarHtml(photoUrl, displayName) {
  const initial = (displayName?.[0] || '?').toUpperCase();
  const src = photoUrl ? mediaUrl(photoUrl) : '';
  if (src) {
    return `<img class="comment-avatar" src="${src}" alt="" width="32" height="32" />`;
  }
  return `<span class="comment-avatar comment-avatar--ph">${escapeHtml(initial)}</span>`;
}

function renderCommentItem(c, postId, depth = 0) {
  const canReply = depth === 0;
  const replyForm = canReply && API().isAuthenticated()
    ? `<form class="video-reply-form hidden" data-post-id="${postId}" data-parent-id="${c.id}">
        <input type="text" name="text" placeholder="Répondre…" maxlength="2000" required />
        <button type="submit" class="btn-sm btn-auth-primary">Répondre</button>
      </form>`
    : '';
  const repliesHtml = (c.replies || [])
    .map((r) => renderCommentItem(r, postId, depth + 1))
    .join('');
  return `
    <div class="video-comment ${depth > 0 ? 'video-comment--reply' : ''}" data-comment-id="${c.id}">
      <div class="video-comment-head">
        ${authorAvatarHtml(c.author_profile_photo_url, c.author_display)}
        <p class="video-comment-author"><strong>${escapeHtml(c.author_display)}</strong>
          <time>${new Date(c.created_at).toLocaleString('fr-FR')}</time></p>
      </div>
      <p class="video-comment-text">${escapeHtml(c.text)}</p>
      <div class="video-comment-actions">
        ${likeBtnHtml(c.liked_by_me, c.like_count, 'comment', c.id)}
        ${canReply ? `<button type="button" class="btn-link btn-reply-toggle" data-parent="${c.id}">Répondre</button>` : ''}
      </div>
      ${replyForm}
      <div class="video-replies">${repliesHtml}</div>
    </div>`;
}

function renderEngagementBlock(post) {
  const authed = API().isAuthenticated();
  const commentForm = authed
    ? `<form class="video-comment-form" data-post-id="${post.id}">
        <textarea name="text" rows="2" placeholder="Ajouter un commentaire…" maxlength="2000" required></textarea>
        <button type="submit" class="btn-auth-primary btn-sm">Commenter</button>
      </form>`
    : '<p class="video-login-hint">Connectez-vous pour commenter ou aimer.</p>';

  const shareFav = authed
    ? `<button type="button" class="btn-link btn-sm" data-share-video="${post.id}">Partager</button>
       <button type="button" class="btn-link btn-sm" data-fav-video="${post.id}">☆ Favori</button>`
    : '';
  return `
    <div class="video-engagement" data-post-id="${post.id}">
      <div class="video-engagement-bar">
        ${likeBtnHtml(post.liked_by_me, post.like_count ?? 0, 'post', post.id)}
        <span class="video-comment-total">💬 ${post.comment_count ?? 0} commentaire(s)</span>
        ${shareFav}
      </div>
      ${commentForm}
      <div class="video-comments-list" id="comments-${post.id}">
        <p class="panel-lead">Chargement des commentaires…</p>
      </div>
    </div>`;
}

function renderModerationActions(post) {
  if (!post.can_moderate || post.status !== 'pending') return '';
  return `
    <div class="video-mod-actions">
      <button type="button" class="btn-auth-primary btn-sm" data-action="approve" data-id="${post.id}">Publier</button>
      <button type="button" class="btn-auth-outline btn-sm" data-action="reject" data-id="${post.id}">Refuser</button>
    </div>`;
}

function renderOwnerDelete(post) {
  if (!post.is_mine && !post.can_moderate) return '';
  return `
    <button type="button" class="btn-auth-outline btn-sm" data-action="delete-post" data-id="${post.id}" title="Supprimer">
      Supprimer
    </button>`;
}

function renderVideoCard(post) {
  const src = mediaUrl(post.file_url);
  const thumb = post.thumbnail_url ? mediaUrl(post.thumbnail_url) : '';
  const poster = thumb ? ` poster="${thumb}"` : '';
  const cat = CATEGORY_LABELS[post.category] || '';
  const authorLink = post.author_username
    ? `<button type="button" class="btn-link community-author-link" data-username="${escapeHtml(post.author_username)}">${escapeHtml(post.author_display)}</button>`
    : escapeHtml(post.author_display);
  return `
    <article class="video-card" role="listitem" data-id="${post.id}">
      <div class="video-card-media">
        <video controls preload="metadata" src="${src}"${poster}></video>
        ${post.is_featured ? '<span class="video-badge">À la une</span>' : ''}
        ${cat ? `<span class="video-cat-badge">${escapeHtml(cat)}</span>` : ''}
      </div>
      <div class="video-card-body">
        <h3>${escapeHtml(post.title)}</h3>
        <p class="video-meta video-meta--author">
          ${authorAvatarHtml(post.author_profile_photo_url, post.author_display)}
          <span>${authorLink} · ${post.view_count} vues</span>
        </p>
        <span class="${statusClass(post.status)}">${statusLabel(post.status)}</span>
        ${post.description ? `<p class="video-desc">${escapeHtml(post.description)}</p>` : ''}
        ${post.rejection_reason && post.status === 'rejected'
    ? `<p class="video-reject">${escapeHtml(post.rejection_reason)}</p>` : ''}
        ${renderModerationActions(post)}
        ${renderOwnerDelete(post)}
        ${post.status === 'published' ? renderEngagementBlock(post) : ''}
      </div>
    </article>`;
}

function renderShortCard(post) {
  const src = mediaUrl(post.file_url);
  return `
    <article class="short-card" role="listitem" data-id="${post.id}">
      <video controls playsinline preload="metadata" src="${src}"></video>
      <div class="short-card-info">
        <strong>${escapeHtml(post.title)}</strong>
        <span>${escapeHtml(post.author_display)}</span>
        <span class="${statusClass(post.status)}">${statusLabel(post.status)}</span>
        ${renderModerationActions(post)}
        ${renderOwnerDelete(post)}
      </div>
      ${post.status === 'published' ? renderEngagementBlock(post) : ''}
    </article>`;
}

async function loadCommentsForPost(postId) {
  const box = document.getElementById(`comments-${postId}`);
  if (!box) return;
  try {
    const list = await fetchComments(postId);
    const tree = buildCommentTree(list);
    box.innerHTML = tree.length
      ? tree.map((c) => renderCommentItem(c, postId)).join('')
      : '<p class="panel-lead">Aucun commentaire — soyez le premier.</p>';
  } catch (e) {
    box.innerHTML = `<p class="parcel-status">${escapeHtml(e.message)}</p>`;
  }
}

async function loadAllComments(container) {
  const blocks = container.querySelectorAll('.video-engagement[data-post-id]');
  await Promise.all(
    [...blocks].map((el) => loadCommentsForPost(el.dataset.postId)),
  );
}

async function toggleLike(target, id, btn) {
  if (!API().isAuthenticated()) {
    alert('Connectez-vous pour aimer.');
    return;
  }
  const path = likeApiPath(target, id);
  const res = await API().api(path, { method: 'POST' });
  btn.classList.toggle('is-liked', res.liked);
  btn.setAttribute('aria-pressed', String(res.liked));
  btn.querySelector('.video-like-count').textContent = res.like_count;
  const icon = res.liked ? '♥' : '♡';
  btn.childNodes[0].textContent = icon + ' ';
}

async function submitComment(postId, text, parentId = null) {
  const body = { text };
  if (parentId) body.parent_id = parentId;
  await API().api(`/videos/posts/${postId}/comments/`, {
    method: 'POST',
    body: JSON.stringify(body),
  });
  await loadCommentsForPost(postId);
  const card = document.querySelector(`.video-card[data-id="${postId}"], .short-card[data-id="${postId}"]`);
  const total = card?.querySelector('.video-comment-total');
  if (total) {
    const list = await fetchComments(postId);
    total.textContent = `💬 ${list.length} commentaire(s)`;
  }
}

function isEngagementView(el) {
  return el?.closest('#view-videos, #view-shorts, #view-community');
}

function bindShareAndFav(container) {
  container?.querySelectorAll('[data-share-video]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = btn.dataset.shareVideo;
      const url = `${ORIGIN()}/?view=videos&video=${id}`;
      navigator.clipboard?.writeText(url).then(
        () => window.SigSolsFeatures?.notifySuccess?.('Lien copié.'),
        () => prompt('Copiez ce lien :', url),
      );
    });
  });
  container?.querySelectorAll('[data-fav-video]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      try {
        await window.SigSolsCommunity?.toggleFavorite?.('video', parseInt(btn.dataset.favVideo, 10));
        btn.textContent = '★ Favori';
        window.SigSolsFeatures?.notifySuccess?.('Ajouté aux favoris.');
      } catch (e) {
        alert(e.message || 'Erreur');
      }
    });
  });
  container?.querySelectorAll('.community-author-link').forEach((btn) => {
    btn.addEventListener('click', () => {
      window.SigSolsCommunity?.openPublicProfile?.(btn.dataset.username);
    });
  });
}

let engagementDelegationReady = false;

function initEngagementDelegation() {
  if (engagementDelegationReady) return;
  engagementDelegationReady = true;

  document.addEventListener('click', async (e) => {
    const likeBtn = e.target.closest('[data-like-target]');
    if (likeBtn && isEngagementView(likeBtn)) {
      e.preventDefault();
      try {
        await toggleLike(likeBtn.dataset.likeTarget, likeBtn.dataset.likeId, likeBtn);
      } catch (err) {
        const msg = err.message || 'Erreur';
        if (/not found|404/i.test(msg)) {
          alert('API indisponible — exécutez : ./scripts/reload-web.sh');
        } else {
          alert(msg);
        }
      }
      return;
    }
    const replyBtn = e.target.closest('.btn-reply-toggle');
    if (replyBtn && isEngagementView(replyBtn)) {
      const comment = replyBtn.closest('.video-comment');
      const form = comment?.querySelector('.video-reply-form');
      form?.classList.toggle('hidden');
      form?.querySelector('input')?.focus();
    }
  });

  document.addEventListener('submit', async (e) => {
    const form = e.target.closest('.video-comment-form, .video-reply-form');
    if (!form || !isEngagementView(form)) return;
    e.preventDefault();
    const postId = form.dataset.postId;
    const text = form.querySelector('[name="text"]')?.value?.trim();
    if (!text) return;
    const parentId = form.classList.contains('video-reply-form')
      ? parseInt(form.dataset.parentId, 10)
      : null;
    try {
      await submitComment(postId, text, parentId || null);
      form.reset();
      if (form.classList.contains('video-reply-form')) {
        form.classList.add('hidden');
      }
    } catch (err) {
      const msg = err.message || 'Erreur';
      if (/not found|404/i.test(msg)) {
        alert('Commentaires indisponibles — redémarrez le serveur web.');
      } else if (/401|session/i.test(msg)) {
        alert('Connectez-vous pour commenter.');
      } else {
        alert(msg);
      }
    }
  });
}

function bindEngagement() {
  initEngagementDelegation();
}

function bindModeration(container) {
  container?.querySelectorAll('[data-action]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const id = btn.dataset.id;
      const action = btn.dataset.action;
      try {
        if (action === 'approve') {
          await API().api(`/videos/posts/${id}/approve/`, { method: 'POST' });
        } else if (action === 'delete-post') {
          if (!confirm('Supprimer définitivement cette publication ?')) return;
          await API().api(`/videos/posts/${id}/`, { method: 'DELETE' });
        } else if (action === 'reject') {
          const reason = prompt('Motif du refus (optionnel) :') || '';
          await API().api(`/videos/posts/${id}/reject/`, {
            method: 'POST',
            body: JSON.stringify({ reason }),
          });
        } else {
          return;
        }
        loadVideos();
        loadShorts();
        loadAdminPending?.();
      } catch (e) {
        alert(e.message || 'Erreur modération');
      }
    });
  });
}

function updateAuthPanels() {
  const authed = API()?.isAuthenticated?.();
  document.querySelectorAll('.auth-required').forEach((el) => {
    el.classList.toggle('hidden', !authed);
  });
  document.getElementById('videos-login-hint')?.classList.toggle('hidden', authed);
  document.getElementById('shorts-login-hint')?.classList.toggle('hidden', authed);
}

async function loadVideos() {
  updateAuthPanels();
  const grid = document.getElementById('videos-grid');
  const modBox = document.getElementById('videos-pending-admin');
  if (!grid) return;
  window.SigSolsAnimations?.setLoadingState?.(grid, true);
  grid.innerHTML = '<p class="panel-lead">Chargement…</p>';
  try {
    const posts = await fetchPosts('video', getVideoFilterParams());
    if (!posts.length) {
      grid.innerHTML = '<p class="panel-lead">Aucune vidéo publiée pour le moment.</p>';
    } else {
      grid.innerHTML = posts.map(renderVideoCard).join('');
      grid.classList.add('animate-stagger');
      window.SigSolsAnimations?.refreshStagger?.(grid);
      bindModeration(grid);
      bindEngagement();
      bindShareAndFav(grid);
      await loadAllComments(grid);
    }
    window.SigSolsAnimations?.setLoadingState?.(grid, false);
    const user = API().getUser?.();
    if (user?.role === 'admin' && modBox) {
      const pending = await API().api('/videos/posts/pending/');
      const list = pending.results ?? pending;
      modBox.innerHTML = list.length
        ? `<h3>Modération vidéos (${list.length})</h3>${list.map(renderVideoCard).join('')}`
        : '';
      modBox.classList.toggle('hidden', !list.length);
      bindModeration(modBox);
    } else if (modBox) {
      modBox.classList.add('hidden');
    }
  } catch (e) {
    grid.innerHTML = `<p class="parcel-status">${escapeHtml(e.message)}</p>`;
    window.SigSolsAnimations?.setLoadingState?.(grid, false);
  }
}

async function loadShorts() {
  updateAuthPanels();
  const feed = document.getElementById('shorts-feed');
  if (!feed) return;
  window.SigSolsAnimations?.setLoadingState?.(feed, true);
  feed.innerHTML = '<p class="panel-lead">Chargement…</p>';
  try {
    const posts = await fetchPosts('short');
    feed.innerHTML = posts.length
      ? posts.map(renderShortCard).join('')
      : '<p class="panel-lead">Aucun short pour le moment.</p>';
    feed.classList.add('animate-stagger');
    window.SigSolsAnimations?.refreshStagger?.(feed);
    bindModeration(feed);
    bindEngagement();
    bindShareAndFav(feed);
    await loadAllComments(feed);
    window.SigSolsAnimations?.setLoadingState?.(feed, false);
  } catch (e) {
    feed.innerHTML = `<p class="parcel-status">${escapeHtml(e.message)}</p>`;
    window.SigSolsAnimations?.setLoadingState?.(feed, false);
  }
}

async function loadAdminPending() {
  const ul = document.getElementById('adm-videos-pending');
  if (!ul || API().getUser?.()?.role !== 'admin') return;
  try {
    const data = await API().api('/videos/posts/pending/');
    const list = data.results ?? data;
    ul.innerHTML = list.length
      ? list.map((p) => `<li>${escapeHtml(p.title)} (${p.kind}) — ${escapeHtml(p.author_username)}
          <button type="button" class="btn-sm" data-adm-approve="${p.id}">OK</button>
          <button type="button" class="btn-sm" data-adm-reject="${p.id}">Refuser</button></li>`).join('')
      : '<li>Aucune vidéo en attente</li>';
    ul.querySelectorAll('[data-adm-approve]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        await API().api(`/videos/posts/${btn.dataset.admApprove}/approve/`, { method: 'POST' });
        loadAdminPending();
      });
    });
    ul.querySelectorAll('[data-adm-reject]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        await API().api(`/videos/posts/${btn.dataset.admReject}/reject/`, {
          method: 'POST',
          body: JSON.stringify({ reason: 'Refusé depuis l’admin' }),
        });
        loadAdminPending();
      });
    });
  } catch {
    ul.innerHTML = '<li>Erreur chargement vidéos</li>';
  }
}

async function captureThumbnailFromVideo(file) {
  return new Promise((resolve) => {
    const video = document.createElement('video');
    video.preload = 'auto';
    video.muted = true;
    const url = URL.createObjectURL(file);
    video.onloadeddata = () => {
      video.currentTime = Math.min(1, (video.duration || 2) * 0.1);
    };
    video.onseeked = () => {
      const canvas = document.createElement('canvas');
      const w = 320;
      const h = Math.max(1, Math.round(w * (video.videoHeight / video.videoWidth) || 0.5625));
      canvas.width = w;
      canvas.height = h;
      canvas.getContext('2d')?.drawImage(video, 0, 0, w, h);
      canvas.toBlob((blob) => {
        URL.revokeObjectURL(url);
        resolve(blob ? new File([blob], 'thumb.jpg', { type: 'image/jpeg' }) : null);
      }, 'image/jpeg', 0.85);
    };
    video.onerror = () => {
      URL.revokeObjectURL(url);
      resolve(null);
    };
    video.src = url;
  });
}

function handleUpload(form, kind, msgEl) {
  form?.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!API().isAuthenticated()) {
      msgEl.textContent = 'Connectez-vous pour publier.';
      return;
    }
    const fd = new FormData();
    fd.append('kind', kind);
    fd.append('title', form.querySelector('[id$="-title"]')?.value?.trim() || 'Sans titre');
    const cat = document.getElementById('video-category')?.value;
    if (cat && kind === 'video') fd.append('category', cat);
    const tags = document.getElementById('video-tags')?.value?.trim();
    if (tags) fd.append('tags', tags);
    const desc = form.querySelector('[id$="-desc"]')?.value?.trim();
    if (desc) fd.append('description', desc);
    const dur = form.querySelector('[id$="-duration"]')?.value;
    if (dur) fd.append('duration_seconds', dur);
    const fileInput = form.querySelector('input[type="file"][id$="-file"]');
    const thumbInput = form.querySelector('input[type="file"][id$="-thumb"]');
    if (!fileInput?.files?.[0]) {
      msgEl.textContent = 'Choisissez un fichier vidéo.';
      return;
    }
    const videoFile = fileInput.files[0];
    fd.append('file', videoFile);
    if (thumbInput?.files?.[0]) {
      fd.append('thumbnail', thumbInput.files[0]);
    } else if (kind === 'video') {
      msgEl.textContent = 'Génération miniature…';
      const autoThumb = await captureThumbnailFromVideo(videoFile);
      if (autoThumb) fd.append('thumbnail', autoThumb);
    }
    msgEl.textContent = 'Envoi en cours…';
    try {
      const res = await API().upload('/videos/posts/', fd);
      msgEl.textContent = res.status === 'published'
        ? 'Publié ! Visible immédiatement.'
        : (res.status === 'rejected'
          ? (res.rejection_reason || 'Publication refusée par le filtre.')
          : 'Envoi enregistré.');
      form.reset();
      if (kind === 'video') loadVideos();
      else loadShorts();
    } catch (err) {
      msgEl.textContent = err.message || 'Échec de l’envoi';
    }
  });
}

function getVideoFilterParams() {
  const p = {};
  const cat = document.getElementById('video-filter-category')?.value;
  const tag = document.getElementById('video-filter-tag')?.value?.trim().replace(/^#/, '');
  if (cat) p.category = cat;
  if (tag) p.tag = tag;
  return p;
}

document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('btn-video-filter')?.addEventListener('click', () => loadVideos());
  initEngagementDelegation();
  handleUpload(
    document.getElementById('form-video-upload'),
    'video',
    document.getElementById('video-upload-msg'),
  );
  handleUpload(
    document.getElementById('form-short-upload'),
    'short',
    document.getElementById('short-upload-msg'),
  );
  window.addEventListener('sig-auth-changed', () => {
    updateAuthPanels();
    loadVideos();
    loadShorts();
  });
  updateAuthPanels();
});

async function loadCommentsModeration() {
  const ul = document.getElementById('adm-comments-moderation');
  if (!ul || API().getUser?.()?.role !== 'admin') return;
  try {
    const list = await API().api('/videos/comments/moderation/');
    ul.innerHTML = (list || []).slice(0, 30).map((c) => `
      <li>#${c.id} — ${escapeHtml(c.author_display)} : ${escapeHtml((c.text || '').slice(0, 80))}
        <button type="button" class="btn-sm" data-hide-comment="${c.id}">Masquer</button></li>`).join('')
      || '<li>Aucun commentaire récent</li>';
    ul.querySelectorAll('[data-hide-comment]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        await API().api(`/videos/comments/${btn.dataset.hideComment}/hide/`, { method: 'POST' });
        loadCommentsModeration();
      });
    });
  } catch {
    ul.innerHTML = '<li>Modération commentaires indisponible</li>';
  }
}

window.SigSolsVideos = {
  loadVideos,
  loadShorts,
  loadAdminPending,
  loadCommentsModeration,
  updateAuthPanels,
  buildCommentTree,
  likeApiPath,
};
