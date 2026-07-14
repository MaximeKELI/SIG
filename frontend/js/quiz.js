import {
  QUIZ_TIMER_SECONDS,
  buildAnswerBody,
  formatAnswerFeedback,
  formatFinishMessage,
  formatLeaderboardRow,
  formatPoolInfo,
  isQuizComplete,
  updateProgress,
} from './core/quizUtils.js';
import { notifyError } from './core/ui.js';
import { trackActivity } from './core/activityTracker.js';

let quizSession = null;
let quizQuestions = [];
let quizIndex = 0;
let quizTimer = null;
let timeLeft = QUIZ_TIMER_SECONDS;
let answerInFlight = false;

/** URL PDF fiche ; { download: true } force l’en-tête attachment (téléchargement). */
export function sheetPdfAbsoluteUrl(sheetId, { download = false } = {}) {
  let u = `${window.location.origin}/api/v1/education/sheets/${sheetId}/pdf/`;
  if (download) u += (u.includes('?') ? '&' : '?') + 'download=1';
  return u;
}

export function openSheetPdfModal(sheet) {
  trackActivity('sheet_open', { sheet_id: sheet.id, title: sheet.title }, 'sheet');
  const url = sheetPdfAbsoluteUrl(sheet.id);
  const modal = document.getElementById('sheet-pdf-modal');
  const titleEl = document.getElementById('sheet-pdf-modal-title');
  const frame = document.getElementById('sheet-pdf-frame');
  const dl = document.getElementById('sheet-pdf-download');
  const hint = document.querySelector('.sheet-pdf-hint');
  if (!modal || !frame || !dl) {
    window.open(url, '_blank', 'noopener,noreferrer');
    return;
  }
  if (titleEl) titleEl.textContent = sheet.title || 'Fiche pédagogique';
  dl.href = sheetPdfAbsoluteUrl(sheet.id, { download: true });
  document.getElementById('sheet-pdf-newtab')?.setAttribute('href', url);
  if (hint) {
    hint.textContent = 'Chargement du document…';
    hint.classList.remove('sheet-pdf-hint--error');
  }
  frame.onload = () => {
    if (hint) hint.textContent = 'Lecture intégrée. Sinon : « Nouvel onglet » ou « Télécharger ».';
  };
  frame.onerror = () => {
    if (hint) {
      hint.textContent = 'Affichage intégré indisponible — ouvrez « Nouvel onglet » ou téléchargez le PDF.';
      hint.classList.add('sheet-pdf-hint--error');
    }
  };
  frame.src = url;
  modal.classList.remove('hidden');
}

function getQuizCount() {
  const el = document.getElementById('quiz-count');
  return el ? parseInt(el.value, 10) || 10 : 10;
}

async function loadQuizStats() {
  const info = document.getElementById('quiz-pool-info');
  if (!info) return;
  try {
    const data = await SigSolsAPI.api('/education/quiz/stats/');
    info.textContent = formatPoolInfo(data);
    info.dataset.loaded = '1';
  } catch {
    info.textContent = 'Banque : 100 questions par niveau (après chargement serveur).';
  }
}

async function startQuiz() {
  const difficulty = document.getElementById('quiz-difficulty').value;
  const count = getQuizCount();
  trackActivity('quiz_start', { difficulty, count }, 'quiz');
  const examMode = document.getElementById('quiz-exam-mode')?.checked ?? false;
  const data = await SigSolsAPI.api('/education/quiz/start/', {
    method: 'POST',
    body: JSON.stringify({ difficulty, count, exam_mode: examMode }),
  });
  if (data.timer_seconds) {
    timeLeft = data.timer_seconds;
  }
  quizSession = data.session_id;
  quizQuestions = data.questions;
  quizIndex = 0;
  document.getElementById('quiz-area').classList.remove('hidden');
  document.getElementById('btn-quiz-finish').classList.add('hidden');
  document.getElementById('btn-quiz-certificate')?.classList.add('hidden');
  document.getElementById('quiz-score').textContent = '0';
  document.getElementById('quiz-feedback').textContent = '';
  document.getElementById('quiz-total').textContent = String(quizQuestions.length);
  document.getElementById('btn-quiz-start').disabled = true;
  updateProgress(quizIndex, quizQuestions.length);
  showQuestion();
}

function showQuestion() {
  if (isQuizComplete(quizIndex, quizQuestions.length)) {
    document.getElementById('btn-quiz-finish').classList.remove('hidden');
    clearInterval(quizTimer);
    updateProgress(quizQuestions.length, quizQuestions.length);
    return;
  }
  const q = quizQuestions[quizIndex];
  document.getElementById('quiz-current').textContent = String(quizIndex + 1);
  updateProgress(quizIndex, quizQuestions.length);
  document.getElementById('quiz-question').textContent = q.text;
  const choices = document.getElementById('quiz-choices');
  choices.innerHTML = '';
  q.choices.forEach((c, i) => {
    const btn = document.createElement('button');
    btn.className = 'quiz-choice';
    btn.textContent = c;
    btn.style.animationDelay = `${i * 0.05}s`;
    btn.onclick = () => submitAnswer(i);
    choices.appendChild(btn);
  });
  timeLeft = QUIZ_TIMER_SECONDS;
  document.getElementById('quiz-timer').textContent = timeLeft;
  clearInterval(quizTimer);
  quizTimer = setInterval(() => {
    timeLeft -= 1;
    document.getElementById('quiz-timer').textContent = timeLeft;
    if (timeLeft <= 0) submitAnswer(-1);
  }, 1000);
}

async function submitAnswer(selectedIndex) {
  if (answerInFlight) return;
  answerInFlight = true;
  clearInterval(quizTimer);
  const q = quizQuestions[quizIndex];
  const buttons = document.querySelectorAll('#quiz-choices .quiz-choice');
  buttons.forEach((b) => { b.disabled = true; });

  try {
    const r = await SigSolsAPI.api(`/education/quiz/${quizSession}/answer/`, {
      method: 'POST',
      body: JSON.stringify(buildAnswerBody(q.id, selectedIndex)),
    });
    const feedback = document.getElementById('quiz-feedback');
    feedback.textContent = formatAnswerFeedback(r);
    feedback.className = r.correct ? 'quiz-feedback quiz-feedback--ok' : 'quiz-feedback quiz-feedback--ko';
    document.getElementById('quiz-score').textContent = r.session_score;
    quizIndex += 1;
    answerInFlight = false;
    setTimeout(showQuestion, 1500);
  } catch (e) {
    notifyError(e);
    answerInFlight = false;
    buttons.forEach((b) => { b.disabled = false; });
    timeLeft = QUIZ_TIMER_SECONDS;
    document.getElementById('quiz-timer').textContent = timeLeft;
    quizTimer = setInterval(() => {
      timeLeft -= 1;
      document.getElementById('quiz-timer').textContent = timeLeft;
      if (timeLeft <= 0) submitAnswer(-1);
    }, 1000);
  }
}

async function finishQuiz() {
  const r = await SigSolsAPI.api(`/education/quiz/${quizSession}/finish/`, { method: 'POST', body: '{}' });
  const finalScore = r.final_score ?? r.score ?? 0;
  trackActivity('quiz_finish', { score: finalScore, total: r.total_questions }, 'quiz');
  document.getElementById('quiz-feedback').textContent = formatFinishMessage(r);
  document.getElementById('quiz-feedback').className = 'quiz-feedback quiz-feedback--ok';
  document.getElementById('btn-quiz-start').disabled = false;
  document.getElementById('btn-quiz-finish').classList.add('hidden');
  const certBtn = document.getElementById('btn-quiz-certificate');
  if (certBtn && quizSession && finalScore >= 10) {
    certBtn.classList.remove('hidden');
    certBtn.onclick = async (e) => {
      e.preventDefault();
      certBtn.disabled = true;
      try {
        await SigSolsAPI.download(
          `/education/quiz/${quizSession}/certificate/`,
          `certificat-quiz-${quizSession}.pdf`,
        );
      } catch (err) {
        notifyError(err);
      } finally {
        certBtn.disabled = false;
      }
    };
  } else if (certBtn) {
    certBtn.classList.add('hidden');
    certBtn.onclick = null;
  }
  loadLeaderboard();
  loadBadges();
}

async function loadLeaderboard() {
  const data = await SigSolsAPI.api('/education/quiz/leaderboard/');
  const ol = document.getElementById('leaderboard');
  ol.innerHTML = '';
  (data.top_10 || []).forEach((row, i) => {
    const li = document.createElement('li');
    li.textContent = formatLeaderboardRow(row, i);
    li.style.animationDelay = `${i * 0.06}s`;
    ol.appendChild(li);
  });
}

async function loadBadges() {
  if (!SigSolsAPI.getToken()) return;
  const data = await SigSolsAPI.api('/education/quiz/badges/');
  const ul = document.getElementById('my-badges');
  ul.innerHTML = '';
  data.forEach((b, i) => {
    const li = document.createElement('li');
    li.textContent = b.badge;
    li.className = 'badge-item';
    li.style.animationDelay = `${i * 0.05}s`;
    ul.appendChild(li);
  });
}

async function loadSheets() {
  const list = document.getElementById('sheets-list');
  if (!list) return;
  list.innerHTML = '<p class="sheets-loading">Chargement des fiches…</p>';
  try {
    const data = await SigSolsAPI.api('/education/sheets/');
    const rows = data.results || data;
    if (!Array.isArray(rows) || !rows.length) {
      list.innerHTML = '<p class="sheets-empty">Aucune fiche pour le moment. Lancez <code>seed_demo_data</code> côté serveur.</p>';
      return;
    }
    list.innerHTML = '';
    rows.forEach((s, i) => {
      const article = document.createElement('article');
      article.className = 'sheet-card sheet-card--interactive';
      article.style.animationDelay = `${i * 0.08}s`;
      const pdfUrl = sheetPdfAbsoluteUrl(s.id);

      const head = document.createElement('div');
      head.className = 'sheet-card-head';

      const titleBtn = document.createElement('button');
      titleBtn.type = 'button';
      titleBtn.className = 'sheet-title-btn';
      titleBtn.textContent = s.title;
      titleBtn.title = 'Ouvrir le document PDF (lecture ou téléchargement)';
      titleBtn.addEventListener('click', () => openSheetPdfModal(s));

      head.appendChild(titleBtn);

      const excerpt = document.createElement('p');
      excerpt.className = 'sheet-excerpt';
      excerpt.textContent = s.content_fr || '';

      const actions = document.createElement('div');
      actions.className = 'sheet-actions';

      const readBtn = document.createElement('button');
      readBtn.type = 'button';
      readBtn.className = 'btn-sheet-read';
      readBtn.textContent = 'Ouvrir le PDF';
      readBtn.addEventListener('click', () => openSheetPdfModal(s));

      const dl = document.createElement('a');
      dl.className = 'btn-sheet-download';
      dl.href = sheetPdfAbsoluteUrl(s.id, { download: true });
      dl.target = '_blank';
      dl.rel = 'noopener noreferrer';
      dl.textContent = 'Télécharger';

      const favBtn = document.createElement('button');
      favBtn.type = 'button';
      favBtn.className = 'btn-sheet-fav';
      favBtn.textContent = '☆ Favori';
      favBtn.addEventListener('click', async () => {
        if (!SigSolsAPI.isAuthenticated()) {
          alert('Connectez-vous pour enregistrer un favori.');
          return;
        }
        try {
          await window.SigSolsCommunity?.toggleFavorite?.('sheet', s.id);
          favBtn.textContent = '★ Favori';
          window.SigSolsFeatures?.notifySuccess?.('Fiche ajoutée aux favoris.');
        } catch (e) {
          notifyError(e);
        }
      });

      actions.append(readBtn, dl, favBtn);
      article.append(head, excerpt, actions);
      list.appendChild(article);
    });
    list.classList.add('animate-stagger');
    window.SigSolsAnimations?.refreshStagger?.(list);
  } catch (e) {
    list.innerHTML = '<p class="sheets-empty">Impossible de charger les fiches. Vérifiez la connexion au serveur.</p>';
    notifyError(e);
  }
}

window.SigSolsQuiz = {
  startQuiz,
  finishQuiz,
  loadLeaderboard,
  loadBadges,
  loadSheets,
  loadQuizStats,
  openSheetPdfModal,
  sheetPdfAbsoluteUrl,
};
