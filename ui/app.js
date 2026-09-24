'use strict';

const RES   = () => (typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'spz-pausemenu');
const inNui = () => typeof GetParentResourceName === 'function';

function post(name, body) {
  if (!inNui()) return Promise.resolve();
  return fetch(`https://${RES()}/${name}`, { method: 'POST', body: JSON.stringify(body || {}) }).catch(() => {});
}

const esc  = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const pad2 = (n) => String(n).padStart(2, '0');
const $    = (id) => document.getElementById(id);
const root = $('root');

const S = { open: false, items: [], sel: 0, modal: null, lastSound: 0 };

function sound(name) {
  const now = performance.now();
  if (name === 'nav' && now - S.lastSound < 45) return;
  S.lastSound = now;
  post('sound', { name });
}

// ── Rendering ─────────────────────────────────────────────────────────────────
function renderList() {
  $('list').innerHTML = S.items.map((it, i) => `
    <button class="item ${i === S.sel ? 'active' : ''} ${it.danger ? 'danger' : ''}" data-i="${i}" style="--d:${80 + i * 45}ms">
      <span class="item-idx">${pad2(i + 1)}</span>
      <span class="item-label">${esc(it.label)}</span>
      <span class="item-desc">${esc(it.desc)}</span>
    </button>`).join('');
}

function paintSelection() {
  document.querySelectorAll('#list .item').forEach((el, i) => el.classList.toggle('active', i === S.sel));
}

// Same file mapping as the leaderboard: S-tier 3/4/5 art is named RANK3/4/5.
const RANK_FILES = (() => {
  const m = {};
  for (const t of ['A', 'B', 'C']) for (let i = 1; i <= 5; i++) m[t + i] = `RANK${t}${i}`;
  m.S1 = 'RANKS1'; m.S2 = 'RANKS2'; m.S3 = 'RANK3'; m.S4 = 'RANK4'; m.S5 = 'RANK5';
  return m;
})();
function rankArt(rank) {
  const mm = /^([SABCD])\s*-?\s*(\d)$/i.exec(String(rank || '').trim());
  const f = mm && RANK_FILES[mm[1].toUpperCase() + mm[2]];
  return f ? `ranks/${f}.svg` : null;
}

function renderDriver(p) {
  p = p || {};
  const name = p.name || 'Driver';
  const rank = p.rank || 'D-5';
  const cls  = String(rank).charAt(0).toUpperCase();
  const num  = p.raceNumber != null ? String(p.raceNumber) : '';
  const art  = rankArt(rank);

  const meta = [
    `<span class="cls-${esc(cls)}">${esc(rank)}</span>`,
    p.crew ? `<span class="crew">${esc(p.crew)}</span>` : '',
    p.nation ? `<span>${esc(String(p.nation).toUpperCase())}</span>` : '',
  ].filter(Boolean).join('<i class="sep"></i>');

  $('driver').innerHTML = `
    <div class="plate ${num ? '' : 'empty'}">${num ? esc(num) : '#'}</div>
    <div class="d-names">
      <span class="d-name">${esc(name)}</span>
      <span class="d-meta">${meta}</span>
    </div>
    ${art ? `<img class="rank-img" src="${art}" alt="${esc(rank)}" />` : ''}`;
}

function renderStatus(st) {
  const kicker = document.querySelector('.menu-kicker');
  const live = !!(st && st.live);
  kicker.classList.toggle('live', live);
  kicker.lastChild.textContent = live ? 'Race live' : 'Paused';
}

// ── Selection ─────────────────────────────────────────────────────────────────
function select(i, withSound = true) {
  const n = S.items.length;
  if (!n) return;
  i = (i + n) % n;
  if (i === S.sel) return;
  S.sel = i;
  if (withSound) sound('nav');
  paintSelection();
}

function choose(i) {
  const it = S.items[i];
  if (!it) return;
  if (it.confirm) { openModal(it); return; }
  post('select', { id: it.id });
  if (!inNui()) closeMenu(true);
}

// ── Confirm ───────────────────────────────────────────────────────────────────
function openModal(it) {
  S.modal = { item: it, choice: 0 };   // Cancel is the default
  $('modalTitle').textContent   = it.confirm.title || 'Are you sure?';
  $('modalBody').textContent    = it.confirm.body || '';
  $('modalConfirm').textContent = it.label;
  $('modal').classList.remove('hidden');
  paintModal();
  sound('nav');
}

function paintModal() {
  $('modalCancel').classList.toggle('active', !!S.modal && S.modal.choice === 0);
  $('modalConfirm').classList.toggle('active', !!S.modal && S.modal.choice === 1);
}

function closeModal(withSound = true) {
  S.modal = null;
  $('modal').classList.add('hidden');
  if (withSound) sound('back');
}

function confirmModal() {
  if (!S.modal) return;
  if (S.modal.choice === 1) {
    const id = S.modal.item.id;
    closeModal(false);
    post('select', { id });
    if (!inNui()) closeMenu(true);
  } else {
    closeModal();
  }
}

// ── Open / close ──────────────────────────────────────────────────────────────
function openMenu(data) {
  S.open  = true;
  S.items = data.items || [];
  S.sel   = 0;
  S.modal = null;

  root.classList.remove('hidden', 'out');
  void root.offsetWidth;   // restart the entrance animations on every open

  $('modal').classList.add('hidden');
  renderDriver(data.player);
  renderStatus(data.status);
  renderList();
}

let closeTimer = null;
function closeMenu(local) {
  if (!S.open) return;
  S.open = false;
  S.modal = null;
  root.classList.add('out');
  clearTimeout(closeTimer);
  closeTimer = setTimeout(() => {
    if (!S.open) root.classList.add('hidden');
    root.classList.remove('out');
  }, 180);
  if (!local) post('close');
}

// Race state changed under an open menu: keep the selection by id.
function replaceItems(items, status) {
  const keep = S.items[S.sel] && S.items[S.sel].id;
  S.items = items || [];
  const i = S.items.findIndex((it) => it.id === keep);
  S.sel = i >= 0 ? i : 0;
  renderStatus(status);
  renderList();
}

// ── Input ─────────────────────────────────────────────────────────────────────
document.addEventListener('keydown', (e) => {
  if (!S.open) return;
  const k = e.key;

  if (S.modal) {
    if (['ArrowLeft', 'ArrowRight', 'Tab', 'a', 'd', 'A', 'D'].includes(k)) {
      S.modal.choice = S.modal.choice ? 0 : 1; paintModal(); sound('nav');
    } else if (k === 'Enter' || k === ' ') confirmModal();
    else if (k === 'Escape' || k === 'Backspace') closeModal();
    e.preventDefault();
    return;
  }

  if (k === 'ArrowUp' || k === 'w' || k === 'W') select(S.sel - 1);
  else if (k === 'ArrowDown' || k === 's' || k === 'S') select(S.sel + 1);
  else if (k === 'Enter' || k === ' ') choose(S.sel);
  else if (k === 'Escape' || k === 'Backspace') closeMenu();
  else return;
  e.preventDefault();
});

$('list').addEventListener('mouseover', (e) => {
  const el = e.target.closest('.item');
  if (el && !S.modal) select(Number(el.dataset.i));
});
$('list').addEventListener('click', (e) => {
  const el = e.target.closest('.item');
  if (el && !S.modal) choose(Number(el.dataset.i));
});

$('modalCancel').addEventListener('mouseenter', () => { if (S.modal) { S.modal.choice = 0; paintModal(); } });
$('modalConfirm').addEventListener('mouseenter', () => { if (S.modal) { S.modal.choice = 1; paintModal(); } });
$('modalCancel').addEventListener('click', () => closeModal());
$('modalConfirm').addEventListener('click', () => { if (S.modal) { S.modal.choice = 1; confirmModal(); } });

// ── Theme (server.cfg spz_theme_* convars, pushed from spz-core) ─────────────
const THEME_VARS = { accent: '--accent', bg: '--bg' };
const THEME_RGB_VARS = { accent: '--accent-rgb' };
function hexToRgbTriplet(hex) {
  const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex || '');
  return m ? `${parseInt(m[1], 16)}, ${parseInt(m[2], 16)}, ${parseInt(m[3], 16)}` : null;
}
function applyTheme(theme) {
  if (!theme) return;
  for (const key in THEME_VARS) if (theme[key]) document.documentElement.style.setProperty(THEME_VARS[key], theme[key]);
  for (const key in THEME_RGB_VARS) {
    const rgb = theme[key] && hexToRgbTriplet(theme[key]);
    if (rgb) document.documentElement.style.setProperty(THEME_RGB_VARS[key], rgb);
  }
}

// ── Lua → NUI ─────────────────────────────────────────────────────────────────
window.addEventListener('message', (ev) => {
  const m = ev.data || {};
  if (m.action === 'open') openMenu(m);
  else if (m.action === 'close') closeMenu(true);
  else if (m.action === 'menu') { if (S.open) replaceItems(m.items, m.status); }
  else if (m.action === 'theme') applyTheme(m.theme);
});

// ── Browser preview (outside FiveM) ───────────────────────────────────────────
if (!inNui()) {
  // Stand-in for the game world: bright daylight, the hardest case for legibility.
  document.body.style.background =
    'linear-gradient(180deg,#8fb8de 0%,#c9dbe8 42%,#b9a58a 43%,#6f655a 60%,#3b3834 100%)';
  openMenu({
    player: { name: 'SpiceZ', rank: 'B-2', crew: '[NR]', nation: 'in', raceNumber: 21 },
    status: { live: false },
    items: [
      { id: 'resume',     label: 'Resume',   desc: 'Back to the session.' },
      { id: 'map',        label: 'Map',      desc: 'Waypoints, blips and the race route.' },
      // Freeroam only — client/main.lua leaves this row out during a race.
      { id: 'hub',        label: 'Hub', desc: "Teleport back to Pop's Diner.",
        confirm: { title: 'Teleport to hub?',
                   body: 'You will be moved across the map. Your car comes with you if you are driving it.' } },
      { id: 'settings',   label: 'Settings', desc: 'Graphics, audio, controls and key bindings.' },
      { id: 'disconnect', label: 'Quit',     desc: 'Leave the server.', danger: true,
        confirm: { title: 'Quit?', body: 'You will leave the server.' } },
    ],
  });
}
