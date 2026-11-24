/**
 * Galerie DUSOL — lightbox légère pour #view-home.
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

export function initGallery() {
  const items = [...document.querySelectorAll('.home-band__shot, .sig-gallery__item')];
  if (!items.length) return;

  document.querySelectorAll('[data-scroll-to]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-scroll-to');
      const target = id ? document.getElementById(id) : null;
      const scroller = document.getElementById('view-home');
      if (!target || !scroller) return;
      const top = target.offsetTop;
      scroller.scrollTo({ top, behavior: 'smooth' });
    });
  });

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
