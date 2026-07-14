document.querySelectorAll('.nav-btn').forEach((btn) => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.nav-btn').forEach((b) => b.classList.remove('active'));
    document.querySelectorAll('.view').forEach((v) => {
      v.classList.remove('active');
      v.style.removeProperty('animation');
      v.style.removeProperty('opacity');
      v.style.removeProperty('visibility');
    });
    btn.classList.add('active');
    const viewName = btn.dataset.view;
    const target = document.getElementById('view-' + viewName);
    if (!target) return;
    target.classList.add('active');
    target.style.opacity = '1';
    target.style.visibility = 'visible';
    target.querySelectorAll('.animate-stagger').forEach((grid) => {
      window.SigSolsAnimations?.refreshStagger?.(grid);
    });
    document.getElementById('welcome-banner')?.classList.add('hidden');
    import('./core/activityTracker.js').then(({ trackNav }) => trackNav(viewName)).catch(() => {});
    if (viewName === 'map') {
      setTimeout(() => {
        SigSolsMap.getMap()?.invalidateSize?.();
        window.SigSolsMap?.loadSentinelToggles?.();
        window.SigSolsMap?.loadWeatherStatus?.();
        const last = window.SigSolsParcel?.getLastParcelData?.();
        if (last) window.SigSolsParcel?.refreshLiveParcelInfo?.(false);
      }, 200);
    }
    if (viewName === 'dashboard') {
      SigSolsDashboard.loadDashboard();
      SigSolsDashboard.renderDashboardParcelExternal?.();
    }
    if (viewName === 'quiz') {
      SigSolsQuiz.loadQuizStats?.();
      SigSolsQuiz.loadLeaderboard();
      SigSolsQuiz.loadBadges();
      window.SigSolsFeaturesHub?.loadLearningPath?.();
      window.SigSolsFeaturesHub?.loadWeeklyChallenge?.();
    }
    if (viewName === 'sheets') SigSolsQuiz.loadSheets();
    if (viewName === 'videos') window.SigSolsVideos?.loadVideos?.();
    if (viewName === 'shorts') {
      window.SigSolsVideos?.loadShorts?.();
      window.SigSolsFeaturesHub?.loadStories?.();
    }
    if (viewName === 'community') window.SigSolsCommunity?.loadCommunity?.();
    if (viewName === 'my-dashboard') window.SigSolsFeaturesHub?.loadPersonalDashboard?.();
    if (viewName === 'admin') {
      window.SigSolsVideos?.loadAdminPending?.();
      window.SigSolsVideos?.loadCommentsModeration?.();
      window.SigSolsFeaturesHub?.loadModerationJournal?.();
      SigSolsFeatures.loadAdminDashboard();
      SigSolsFeatures.loadPendingValidation?.();
      SigSolsFeatures.initAdminExports?.();
      window.SigSolsAdminAnalytics?.loadAdminAnalytics?.();
      window.SigSolsAdminAnalytics?.loadRecentActivity?.();
    }
  });
});

document.getElementById('btn-apply-filters')?.addEventListener('click', () => SigSolsMap.loadSoilPoints({ showOverlay: true }));
document.getElementById('btn-export-geojson')?.addEventListener('click', () => {
  if (SigSolsAPI.isAuthenticated()) {
    SigSolsMap.exportWithAuth('/points/geojson/', 'points.geojson');
  } else {
    window.open('/api/v1/points/geojson/', '_blank');
  }
});
document.getElementById('btn-export-csv')?.addEventListener('click', () => {
  if (SigSolsAPI.isAuthenticated()) {
    SigSolsMap.exportWithAuth('/points/export-csv/', 'points.csv');
  } else {
    window.open('/api/v1/points/export-csv/', '_blank');
  }
});
document.getElementById('btn-predict')?.addEventListener('click', () => SigSolsMap.runPrediction());
document.getElementById('btn-location-toggle')?.addEventListener('click', () => SigSolsMap.toggleLiveLocation());
document.getElementById('share-location')?.addEventListener('change', (e) => {
  if (e.target.checked && SigSolsAPI.isAuthenticated()) SigSolsMap.startLiveLocation();
  else if (!e.target.checked) SigSolsMap.stopLiveLocation();
});
document.getElementById('btn-heatmap')?.addEventListener('click', () => {
  const m = SigSolsMap.getMap?.();
  if (m) SigSolsFeatures.toggleHeatmap(m, 'ph');
});
document.getElementById('btn-near-me')?.addEventListener('click', () => {
  const m = SigSolsMap.getMap?.();
  if (m) window.SigSolsTools?.searchProximity?.(m) || SigSolsFeatures.nearMe(m);
});
document.getElementById('btn-trajectory')?.addEventListener('click', () => {
  const m = SigSolsMap.getMap?.();
  if (m) SigSolsFeatures.showTrajectory(m);
});
document.getElementById('btn-zone-report')?.addEventListener('click', () => {
  const code = document.getElementById('adm-zone-code')?.value?.trim();
  if (code) window.open(`/api/v1/platform/reports/zone/${encodeURIComponent(code)}/`, '_blank');
});
document.getElementById('btn-quiz-start')?.addEventListener('click', () => SigSolsQuiz.startQuiz());
document.getElementById('btn-quiz-finish')?.addEventListener('click', () => SigSolsQuiz.finishQuiz());

window.addEventListener('online', () => SigSolsFeatures.syncOfflineQueue());

document.getElementById('proximity-radius')?.addEventListener('input', (e) => {
  const el = document.getElementById('proximity-radius-label');
  if (el) el.textContent = `${e.target.value} m`;
});

document.addEventListener('DOMContentLoaded', async () => {
  window.SigSolsInit?.initAppShell?.();
  const { initActivityTracker, initAdminAnalytics } = await Promise.all([
    import('./core/activityTracker.js'),
    import('./adminAnalytics.js'),
  ]).then(([a, b]) => ({ initActivityTracker: a.initActivityTracker, initAdminAnalytics: b.initAdminAnalytics }));
  initActivityTracker();
  initAdminAnalytics();
  SigSolsMap.initMap();
  SigSolsQuiz.loadQuizStats?.();
  await SigSolsAuth.initAuth();
  SigSolsFeatures.applyPublicMode();
  if (SigSolsAPI.isAuthenticated()) {
    document.getElementById('welcome-banner')?.classList.add('hidden');
    SigSolsMap.loadSoilPoints();
    SigSolsFeatures.loadAlerts();
    SigSolsFeatures.loadNotifications();
    SigSolsFeatures.connectWebSocket();
    SigSolsFeatures.syncOfflineQueue();
  }
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/frontend/sw.js').catch(() => {});
  }
  window.SigSolsTools?.initTools?.();
  window.SigSolsAdminPanel?.initAdminPanel?.();
  const { initChatbot } = await import('./chat.js');
  initChatbot();
  const params = new URLSearchParams(window.location.search);
  const deepView = params.get('view');
  if (deepView) {
    document.querySelector(`.nav-btn[data-view="${deepView}"]`)?.click();
    const user = params.get('user');
    if (deepView === 'community' && user) {
      setTimeout(() => window.SigSolsCommunity?.loadPublicProfile?.(user), 400);
    }
    const videoId = params.get('video');
    if (deepView === 'videos' && videoId) {
      setTimeout(() => {
        document.querySelector(`.video-card[data-id="${videoId}"]`)?.scrollIntoView({ behavior: 'smooth' });
      }, 600);
    }
  }
});
