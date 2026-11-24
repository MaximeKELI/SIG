/**
 * Galerie DUSOL — lightbox + motion Accueil (parallax + révélations scroll).
 */

function ensureLightbox() {
  let box = document.getElementById('sig-gallery-lightbox');
  if (box) return box;
  box = document.createElement('div');
  box.id = 'sig-gallery-lightbox';
  box.className = 'sig-gallery-lightbox hidden';
  box.setAttribute('role', 'dialog');
  box.setAttribute('aria-modal', 'true');
  box.setAttribute('aria-label', 'Aperçu photo');
  box.innerHTML = `
    <div class="sig-gallery-lightbox__inner">
      <button type="button" class="sig-gallery-lightbox__close" aria-label="Fermer">×</button>
      <button type="button" class="sig-gallery-lightbox__nav sig-gallery-lightbox__nav--prev" aria-label="Précédente">‹</button>
      <img alt="" />
      <button type="button" class="sig-gallery-lightbox__nav sig-gallery-lightbox__nav--next" aria-label="Suivante">›</button>
      <p class="sig-gallery-lightbox__caption"></p>
    </div>
  `;
  document.body.appendChild(box);
  return box;
}

function prefersReducedMotion() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function initHomeCarousel() {
  const root = document.querySelector('[data-home-carousel]');
  if (!root) return;

  const slides = [...root.querySelectorAll('.home-stage__slide')];
  if (slides.length < 2) return;

  const stage = root.closest('.home-stage');
  const dotsWrap = stage?.querySelector('[data-carousel-dots]');
  const captionEl = stage?.querySelector('[data-carousel-caption]');
  const btnPrev = stage?.querySelector('[data-carousel-prev]');
  const btnNext = stage?.querySelector('[data-carousel-next]');
  const reduce = prefersReducedMotion();
  const INTERVAL = reduce ? 999999 : 5200;
  let index = Math.max(0, slides.findIndex((s) => s.classList.contains('is-active')));
  if (index < 0) index = 0;
  let timer = null;
  let locked = false;

  const dots = slides.map((_, i) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'home-stage__dot' + (i === index ? ' is-active' : '');
    b.setAttribute('role', 'tab');
    b.setAttribute('aria-label', `Diapositive ${i + 1}`);
    b.addEventListener('click', () => go(i, true));
    dotsWrap?.appendChild(b);
    return b;
  });

  const setCaption = (i) => {
    if (!captionEl) return;
    const next = slides[i].dataset.caption || slides[i].querySelector('img')?.alt || '';
    captionEl.classList.add('is-swap');
    window.setTimeout(() => {
      captionEl.textContent = next;
      captionEl.classList.remove('is-swap');
    }, 220);
  };

  const go = (next, user = false) => {
    if (locked || next === index) return;
    locked = true;
    const prev = index;
    index = (next + slides.length) % slides.length;

    slides[prev].classList.remove('is-active');
    slides[prev].classList.add('is-leaving');
    slides[index].classList.add('is-active');
    dots.forEach((d, i) => d.classList.toggle('is-active', i === index));
    setCaption(index);

    window.setTimeout(() => {
      slides[prev].classList.remove('is-leaving');
      locked = false;
    }, reduce ? 0 : 1200);

    if (user) restart();
  };

  const next = () => go(index + 1);
  const prev = () => go(index - 1);

  const stop = () => {
    if (timer) {
      clearInterval(timer);
      timer = null;
    }
  };

  const start = () => {
    stop();
    if (reduce) return;
    timer = window.setInterval(next, INTERVAL);
  };

  const restart = () => {
    stop();
    start();
  };

  btnPrev?.addEventListener('click', () => {
    prev();
    restart();
  });
  btnNext?.addEventListener('click', () => {
    next();
    restart();
  });

  stage?.addEventListener('mouseenter', stop);
  stage?.addEventListener('mouseleave', start);
  stage?.addEventListener('focusin', stop);
  stage?.addEventListener('focusout', (e) => {
    if (!stage.contains(e.relatedTarget)) start();
  });

  // Touch swipe
  let touchX = null;
  root.addEventListener(
    'touchstart',
    (e) => {
      touchX = e.changedTouches[0]?.clientX ?? null;
    },
    { passive: true },
  );
  root.addEventListener(
    'touchend',
    (e) => {
      if (touchX == null) return;
      const dx = (e.changedTouches[0]?.clientX ?? touchX) - touchX;
      touchX = null;
      if (Math.abs(dx) < 48) return;
      if (dx < 0) next();
      else prev();
      restart();
    },
    { passive: true },
  );

  document.addEventListener('visibilitychange', () => {
    if (document.hidden) stop();
    else start();
  });

  setCaption(index);
  start();
}

function initHomeMotion() {
  const home = document.getElementById('view-home');
  if (!home) return;

  const stage = home.querySelector('[data-home-parallax]');
  const media = stage?.querySelector('.home-stage__media');
  const copy = stage?.querySelector('.home-stage__copy');
  const bands = [...home.querySelectorAll('[data-reveal]')];

  const revealBand = (band) => {
    band.classList.add('is-inview');
  };

  if (!prefersReducedMotion() && 'IntersectionObserver' in window) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            revealBand(entry.target);
            io.unobserve(entry.target);
          }
        });
      },
      {
        root: home,
        rootMargin: '0px 0px -8% 0px',
        threshold: 0.12,
      },
    );
    bands.forEach((band) => io.observe(band));
  } else {
    bands.forEach(revealBand);
  }

  if (prefersReducedMotion() || !stage || !media) return;

  let ticking = false;
  const onScroll = () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => {
      const y = home.scrollTop;
      const stageH = stage.offsetHeight || 1;
      const progress = Math.min(1, Math.max(0, y / stageH));

      media.style.transform = `translate3d(0, ${y * 0.38}px, 0) scale(${1 + progress * 0.06})`;
      if (copy) {
        copy.style.transform = `translate3d(0, ${y * 0.18}px, 0)`;
        copy.style.opacity = String(1 - progress * 1.15);
        copy.style.filter = progress > 0.05 ? `blur(${progress * 8}px)` : 'none';
      }

      stage.style.setProperty('--home-scroll', String(progress));
      ticking = false;
    });
  };

  home.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  // Soft tilt on pointer move (desktop)
  stage.addEventListener('pointermove', (e) => {
    if (e.pointerType === 'touch') return;
    const rect = stage.getBoundingClientRect();
    const px = (e.clientX - rect.left) / rect.width - 0.5;
    const py = (e.clientY - rect.top) / rect.height - 0.5;
    media.style.setProperty('--tilt-x', `${px * 12}px`);
    media.style.setProperty('--tilt-y', `${py * 8}px`);
    if (!home.scrollTop) {
      media.style.transform = `translate3d(calc(var(--tilt-x, 0px) * -1), calc(var(--tilt-y, 0px) * -1), 0) scale(1.02)`;
    }
  });

  stage.addEventListener('pointerleave', () => {
    if (home.scrollTop > 8) return;
    media.style.transform = '';
  });
}

function initLightbox(items) {
  if (!items.length) return;

  const box = ensureLightbox();
  const img = box.querySelector('img');
  const caption = box.querySelector('.sig-gallery-lightbox__caption');
  const btnClose = box.querySelector('.sig-gallery-lightbox__close');
  const btnPrev = box.querySelector('.sig-gallery-lightbox__nav--prev');
  const btnNext = box.querySelector('.sig-gallery-lightbox__nav--next');
  let index = 0;

  const show = (i) => {
    index = (i + items.length) % items.length;
    const a = items[index];
    img.src = a.getAttribute('href');
    img.alt = a.querySelector('img')?.alt || '';
    caption.textContent = a.dataset.caption || img.alt || '';
    box.classList.remove('hidden');
    document.body.classList.add('modal-open');
  };

  const hide = () => {
    box.classList.add('hidden');
    img.removeAttribute('src');
    if (![...document.querySelectorAll('.modal, [id$="-modal"], .sig-gallery-lightbox')].some(
      (el) => !el.classList.contains('hidden'),
    )) {
      document.body.classList.remove('modal-open');
    }
  };

  items.forEach((a, i) => {
    a.addEventListener('click', (e) => {
      e.preventDefault();
      show(i);
    });
  });

  btnClose?.addEventListener('click', hide);
  btnPrev?.addEventListener('click', () => show(index - 1));
  btnNext?.addEventListener('click', () => show(index + 1));
  box.addEventListener('click', (e) => {
    if (e.target === box) hide();
  });
  document.addEventListener('keydown', (e) => {
    if (box.classList.contains('hidden')) return;
    if (e.key === 'Escape') hide();
    if (e.key === 'ArrowLeft') show(index - 1);
    if (e.key === 'ArrowRight') show(index + 1);
  });
}

export function initGallery() {
  const items = [...document.querySelectorAll('.home-band__shot, .sig-gallery__item')];

  document.querySelectorAll('[data-scroll-to]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-scroll-to');
      const target = id ? document.getElementById(id) : null;
      const scroller = document.getElementById('view-home');
      if (!target || !scroller) return;
      scroller.scrollTo({ top: target.offsetTop, behavior: 'smooth' });
    });
  });

  initHomeCarousel();
  initHomeMotion();
  initLightbox(items);
}
