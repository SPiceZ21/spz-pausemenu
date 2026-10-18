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

const S = { open: false, items: [], sel: 0, modal: null, lastSound: 0, player: null, live: false, face: null };

function sound(name) {
  const now = performance.now();
  if (name === 'nav' && now - S.lastSound < 45) return;
  S.lastSound = now;
  post('sound', { name });
}

// ── Rendering ─────────────────────────────────────────────────────────────────
const ICON = {
  resume:   '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7 4.5v15l12.5-7.5z"/></svg>',
  map:      '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a7 7 0 0 0-7 7c0 5.2 7 13 7 13s7-7.8 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5z"/></svg>',
  hub:      '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 3 2 11.5h3V21h5.5v-6h3v6H19v-9.5h3z"/></svg>',
  settings: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M19.4 13a7.6 7.6 0 0 0 0-2l2.1-1.6-2-3.5-2.5 1a7.4 7.4 0 0 0-1.7-1L14.9 3h-4l-.4 2.9a7.4 7.4 0 0 0-1.7 1l-2.5-1-2 3.5L6.4 11a7.6 7.6 0 0 0 0 2l-2.1 1.6 2 3.5 2.5-1a7.4 7.4 0 0 0 1.7 1l.4 2.9h4l.4-2.9a7.4 7.4 0 0 0 1.7-1l2.5 1 2-3.5zM12.9 15.5a3.5 3.5 0 1 1 0-7 3.5 3.5 0 0 1 0 7z" transform="translate(-0.9 0)"/></svg>',
  leave:    '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M5 3h2v18H5zm4 1.5 9 2.5v9l-9 2.5z"/></svg>',
  disconnect: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M12 3v8"/><path d="M6.3 6.8a8 8 0 1 0 11.4 0"/></svg>',
};
ICON.leave_minigame = ICON.leave;
ICON.leave_queue = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M4 6h10M4 12h10M4 18h6"/><path d="m16 15 5 5m0-5-5 5"/></svg>';
ICON.q_join    = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M5 2h2v20H5zm3 1h11l-2.5 4L19 11H8z"/></svg>';
ICON.q_car     = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M5 11 6.6 6.4A2 2 0 0 1 8.5 5h7a2 2 0 0 1 1.9 1.4L19 11a2 2 0 0 1 2 2v4h-2v1.5a1.5 1.5 0 0 1-3 0V17H8v1.5a1.5 1.5 0 0 1-3 0V17H3v-4a2 2 0 0 1 2-2zm2.2-.2h9.6L15.6 7H8.4zM6.5 15a1.3 1.3 0 1 0 0-2.6 1.3 1.3 0 0 0 0 2.6zm11 0a1.3 1.3 0 1 0 0-2.6 1.3 1.3 0 0 0 0 2.6z"/></svg>';
ICON.q_board   = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 13h5v8H3zm6.5-6h5v14h-5zM16 10h5v11h-5z"/></svg>';
ICON.q_results = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7 3h10v2h3v3a4 4 0 0 1-4 4h-.3A5 5 0 0 1 13 14.9V18h3v3H8v-3h3v-3.1A5 5 0 0 1 8.3 12H8a4 4 0 0 1-4-4V5h3zm0 4H6v1a2 2 0 0 0 1 1.7zm10 0v2.7A2 2 0 0 0 18 8V7z"/></svg>';
ICON.q_crew    = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm8 0a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM9 13c-3.9 0-7 1.8-7 4.5V20h14v-2.5C16 14.8 12.9 13 9 13zm8 0c-.6 0-1.2 0-1.7.1 1.6 1.1 2.7 2.6 2.7 4.4V20h4v-2.5c0-2.6-2.3-4.5-5-4.5z"/></svg>';
ICON.q_char    = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 3 3 6l2 4 2-1v12h10V9l2 1 2-4-5-3c-.5 1.7-2.1 3-4 3S8.5 4.7 8 3z"/></svg>';
ICON.q_tour    = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>';

// ── Map tile: GTA's own map art (map.webp, stitched from the game's minimap
// textures: 2 x 3 tiles of 4500 world units, top-left at world -4140, 8400).
const MAP = { img: 'map.webp', w: 2560, x0: -4140, y0: 8400, worldW: 9000, span: 1600 };
const MAP_ART = `
  <div class="map-real" id="mapReal">
    <img class="map-img" id="mapImg" src="${MAP.img}" alt="" draggable="false" />
    <span class="map-wp hidden" id="mapWp"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a7 7 0 0 0-7 7c0 5.2 7 13 7 13s7-7.8 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5z"/></svg></span>
    <span class="map-me" id="mapMe"><svg viewBox="0 0 24 24"><path d="M12 2 20 21 12 16.5 4 21z" fill="#fff" stroke="#000" stroke-width="1.2" stroke-linejoin="round"/></svg></span>
  </div>`;

// Centre the map on the player, arrow = heading (GTA: degrees, counter-clockwise from north).
function placeMap() {
  const p = S.mapPos;
  const box = $('mapReal'), img = $('mapImg');
  if (!p || !box || !img) return;
  const W = box.clientWidth, H = box.clientHeight;
  if (!W || !H) return;
  const ppu = MAP.w / MAP.worldW;                    // image px per world unit
  const scale = W / ((p.span || MAP.span) * ppu);    // screen px per image px
  const toPx = (x, y) => [(x - MAP.x0) * ppu * scale, (MAP.y0 - y) * ppu * scale];
  const [mx, my] = toPx(p.x, p.y);
  img.style.width = `${MAP.w * scale}px`;
  img.style.transform = `translate(${W / 2 - mx}px, ${H / 2 - my}px)`;
  $('mapMe').style.transform = `translate(-50%, -50%) rotate(${-(p.h || 0)}deg)`;

  const wp = $('mapWp');
  if (p.wx != null && p.wy != null) {
    const [wx, wy] = toPx(p.wx, p.wy);
    // Off the tile: pinned to the edge, pointing the way.
    const pad = 16;
    const x = Math.min(W - pad, Math.max(pad, W / 2 + (wx - mx)));
    const y = Math.min(H - pad, Math.max(pad, H / 2 + (wy - my)));
    wp.style.left = `${x}px`; wp.style.top = `${y}px`;
    wp.classList.remove('hidden');
  } else {
    wp.classList.add('hidden');
  }
}
window.addEventListener('resize', placeMap);

const ARROW = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>';

// Small context on each card, in the kit's pill-badge style.
function tileBadges(it) {
  const b = (cls, text, dot) => `<span class="badge ${cls}">${dot ? '<i class="dot"></i>' : ''}${esc(text)}</span>`;
  switch (it.id) {
    case 'resume':   return S.live ? b('error', 'Race live', true) : b('success', 'Free roam', true);
    case 'map':      return b('', 'Waypoints & blips');
    case 'hub':      return it.badge ? b('primary', it.badge) : '';
    case 'leave':
    case 'leave_minigame': return b('error', 'Ends your run');
    case 'leave_queue': return b('', 'No penalty');
    case 'settings': return `<span class="chips">${b('', 'Graphics')}${b('', 'Audio')}${b('', 'Keys')}</span>`;
    default:         return '';
  }
}

// Bento layout: driver card + map are the big tiles, Resume/Settings stack on the
// right, everything else shares the bottom row (4 columns between them).
function layout(items) {
  const main = items.filter((it) => !it.quick);
  const rest = main.filter((it) => !['resume', 'map', 'settings'].includes(it.id));
  const spans = rest.length === 1 ? [4] : rest.length === 2 ? [2, 2] : rest.length === 3 ? [2, 1, 1] : rest.map(() => 1);
  const cls = {};
  rest.forEach((it, i) => { cls[it.id] = spans[i] === 4 ? 'w4' : spans[i] === 2 ? 'w2' : ''; });
  cls.map = 'w2 h2';
  const order = ['map', 'resume', 'settings', ...rest.map((it) => it.id)];
  return { cls, order, quick: items.filter((it) => it.quick) };
}

function quickHtml(it, i, d) {
  return `
    <button class="tile quick" data-i="${i}" data-id="${esc(it.id)}" style="--d:${d}ms">
      <span class="t-chip">${ICON[it.id] || ICON.resume}</span>
      <span class="q-label">${esc(it.label)}</span>
    </button>`;
}

function tileHtml(it, i, cls, d) {
  const icon = ICON[it.id] || ICON.resume;
  // In game the tile is a see-through window onto GTA's own map (client/main.lua
  // moves the big radar under it). The drawn map is only the browser preview.
  if (it.id === 'map') return `
    <button class="tile map ${cls || ''}" data-i="${i}" data-id="map" style="--d:${d}ms">
      ${MAP_ART}
      <div class="t-head"><span class="t-chip">${icon}</span>${tileBadges(it)}</div>
      <div class="t-foot">
        <div class="t-text"><span class="t-label">${esc(it.label)}</span><span class="t-desc">${esc(it.desc)}</span></div>
        <span class="t-go">${ARROW}</span>
      </div>
    </button>`;
  return `
    <button class="tile ${cls || ''} ${it.danger ? 'danger' : ''}" data-i="${i}" data-id="${esc(it.id)}" style="--d:${d}ms">
      <span class="t-ghost">${icon}</span>
      <div class="t-head">
        <span class="t-chip">${icon}</span>
        ${tileBadges(it)}
      </div>
      <div class="t-foot">
        <div class="t-text">
          <span class="t-label">${esc(it.label)}</span>
          <span class="t-desc">${esc(it.desc)}</span>
        </div>
        <span class="t-go">${ARROW}</span>
      </div>
    </button>`;
}

function renderList() {
  const { cls, order, quick } = layout(S.items);
  const idx = (id) => S.items.findIndex((it) => it.id === id);
  const tiles = order.map(idx).filter((i) => i >= 0)
    .map((i, k) => tileHtml(S.items[i], i, cls[S.items[i].id], 120 + k * 40));
  $('bento').innerHTML = `<div class="tile driver h2" id="driver" style="--d:60ms"></div>` + tiles.join('');
  $('quick').innerHTML = quick.map((it, k) => quickHtml(it, S.items.indexOf(it), 300 + k * 30)).join('');
  $('quick').classList.toggle('hidden', !quick.length);
  renderDriver(S.player);
  paintSelection();
  requestAnimationFrame(placeMap);
}

function tileEls() { return [...document.querySelectorAll('.stage .tile[data-i]')]; }

function paintSelection() {
  tileEls().forEach((el) => el.classList.toggle('active', Number(el.dataset.i) === S.sel));
}

// Arrow keys move to the nearest tile in that direction (by tile centres).
function move(dx, dy) {
  const els = tileEls();
  const cur = els.find((el) => Number(el.dataset.i) === S.sel);
  if (!cur) return select(0);
  const c = cur.getBoundingClientRect();
  const cx = c.left + c.width / 2, cy = c.top + c.height / 2;
  let best = null, bestScore = Infinity;
  for (const el of els) {
    if (el === cur) continue;
    const r = el.getBoundingClientRect();
    // overlap with the current tile on the cross axis counts as "straight ahead"
    const ex = Math.max(r.left, Math.min(cx, r.right)), ey = Math.max(r.top, Math.min(cy, r.bottom));
    const along = dx ? (ex - cx) * dx : (ey - cy) * dy;
    if (along <= 1) continue;
    const across = dx ? Math.abs(ey - cy) : Math.abs(ex - cx);
    const score = along + across * 2.5;
    if (score < bestScore) { bestScore = score; best = el; }
  }
  if (best) select(Number(best.dataset.i));
}

// Same file mapping as the leaderboard: RANK<tier><sub> for every tier.
const RANK_FILES = (() => {
  const m = {};
  for (const t of ['A', 'B', 'C', 'S']) for (let i = 1; i <= 5; i++) m[t + i] = `RANK${t}${i}`;
  return m;
})();
function rankArt(rank) {
  const mm = /^([SABCD])\s*-?\s*(\d)$/i.exec(String(rank || '').trim());
  const f = mm && RANK_FILES[mm[1].toUpperCase() + mm[2]];
  return f ? `ranks/${f}.svg` : null;
}

const LICENSES = ['Class C · Street', 'Class B · Sport', 'Class A · Pro', 'Class S · Elite'];
// Panchang is wide: keep stat values to ~4 characters (1742, 48K, 1.3M).
function num0(v) {
  if (v == null || v === '') return '—';
  const n = Number(v), a = Math.abs(n);
  if (a >= 1e6) return (n / 1e6).toFixed(a >= 1e7 ? 0 : 1) + 'M';
  if (a >= 1e4) return Math.round(n / 1e3) + 'K';
  return String(Math.round(n));
}
function hours(min) {
  if (min == null) return '—';
  const h = Math.floor(Number(min) / 60);
  return h >= 1 ? `${h}h` : `${Math.round(Number(min))}m`;
}

function renderDriver(p) {
  p = p || {};
  const name = p.name || 'Driver';
  const rank = p.rank || 'D-5';
  const cls  = String(rank).charAt(0).toUpperCase();
  const num  = p.raceNumber != null ? String(p.raceNumber) : '';
  const art  = rankArt(rank);
  const st   = p.stats || {};
  const lic  = LICENSES[Number(st.license)] || null;

  const badges = [
    p.crew ? `<span class="badge primary">${esc(p.crew)}</span>` : '',
    p.nation ? `<span class="badge">${esc(String(p.nation).toUpperCase())}</span>` : '',
    lic ? `<span class="badge">${esc(lic)}</span>` : '',
  ].filter(Boolean).join('');

  const stat = (label, value, accent) =>
    `<div class="stat"><span class="stat-v ${accent || ''}">${value}</span><span class="stat-l">${label}</span></div>`;

  const el = $('driver');
  if (!el) return;
  el.innerHTML = `
    <div class="d-row">
      <div class="face ${S.face ? '' : 'empty'}">
        ${S.face ? `<img src="https://nui-img/${esc(S.face)}/${esc(S.face)}" alt="" />` : '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 12a5 5 0 1 0 0-10 5 5 0 0 0 0 10zm0 2c-4.4 0-9 2.2-9 5.5V22h18v-2.5C21 16.2 16.4 14 12 14z"/></svg>'}
      </div>
      <div class="d-id">
        <span class="d-name">${esc(name)}</span>
        <span class="chips"><span class="badge cls-${esc(cls)}">${esc(rank)}</span>${badges}</span>
      </div>
    </div>
    <div class="d-mid">
      <div class="plate ${num ? '' : 'empty'}">${num ? esc(num) : '#'}</div>
      ${art ? `<img class="rank-img" src="${art}" alt="${esc(rank)}" />` : ''}
    </div>
    <div class="stat-grid">
      ${stat('iRating', num0(st.iRating), 'accent')}
      ${stat('Safety', st.sr != null ? Number(st.sr).toFixed(2) : '—')}
      ${stat('Podiums', num0(st.podiums))}
      ${stat('XP', num0(st.xp))}
      ${stat('Credits', num0(st.credits))}
      ${stat('Played', hours(st.playtime))}
    </div>`;
}

function renderStatus(st) {
  const kicker = document.querySelector('.menu-kicker');
  const live = !!(st && st.live);
  S.live = live;
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
  S.player = data.player;
  S.face = null;            // a fresh headshot follows in a 'face' message
  renderStatus(data.status);
  renderList();
  tickClock();
}

// Local wall-clock time in the header, refreshed while the menu is open.
function tickClock() {
  if (!S.open) return;
  const d = new Date();
  $('clock').textContent = `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
  setTimeout(tickClock, 15000);
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

  if (k === 'ArrowUp' || k === 'w' || k === 'W') move(0, -1);
  else if (k === 'ArrowDown' || k === 's' || k === 'S') move(0, 1);
  else if (k === 'ArrowLeft' || k === 'a' || k === 'A') move(-1, 0);
  else if (k === 'ArrowRight' || k === 'd' || k === 'D') move(1, 0);
  else if (k === 'Tab') select(S.sel + (e.shiftKey ? -1 : 1));
  else if (k === 'Enter' || k === ' ') choose(S.sel);
  else if (k === 'Escape' || k === 'Backspace') closeMenu();
  else return;
  e.preventDefault();
});

$('quick').addEventListener('mouseover', (e) => {
  const el = e.target.closest('.tile[data-i]');
  if (el && !S.modal) select(Number(el.dataset.i));
});
$('quick').addEventListener('click', (e) => {
  const el = e.target.closest('.tile[data-i]');
  if (el && !S.modal) choose(Number(el.dataset.i));
});
$('bento').addEventListener('mouseover', (e) => {
  const el = e.target.closest('.tile[data-i]');
  if (el && !S.modal) select(Number(el.dataset.i));
});
$('bento').addEventListener('click', (e) => {
  const el = e.target.closest('.tile[data-i]');
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
  else if (m.action === 'pos') { S.mapPos = m; placeMap(); }
  else if (m.action === 'face') { S.face = m.txd || null; if (S.open) renderDriver(S.player); }
});

// ── Browser preview (outside FiveM) ───────────────────────────────────────────
if (!inNui()) {
  setTimeout(() => { S.mapPos = { x: 195, y: -934, h: 30, wx: -1037, wy: -2737 }; placeMap(); }, 50);
  // Stand-in for the game world: bright daylight, the hardest case for legibility.
  document.body.style.background =
    'linear-gradient(180deg,#8fb8de 0%,#c9dbe8 42%,#b9a58a 43%,#6f655a 60%,#3b3834 100%)';
  openMenu({
    player: { name: 'SpiceZ', rank: 'B-2', crew: '[NR]', nation: 'in', raceNumber: 21,
              stats: { iRating: 1742, sr: 3.41, license: 1, podiums: 38, xp: 48210, points: 9120, credits: 125400, playtime: 6420 } },
    status: { live: false },
    _preview: true,
    items: [
      { id: 'resume',     label: 'Resume',   desc: 'Back to the session.' },
      { id: 'map',        label: 'Map',      desc: 'Waypoints, blips and the race route.' },
      // Freeroam only — client/main.lua leaves this row out during a race.
      { id: 'hub',        label: 'Hub', desc: "Teleport back to Pop's Diner.", badge: "Pop's Diner",
        confirm: { title: 'Teleport to hub?',
                   body: 'You will be moved across the map. Your car comes with you if you are driving it.' } },
      { id: 'leave_queue', label: 'Leave queue', danger: true, desc: 'Drop out of the race queue. No penalty.' },
      { id: 'settings',   label: 'Settings', desc: 'Graphics, audio, controls and key bindings.' },
      { id: 'disconnect', label: 'Quit',     desc: 'Leave the server.', danger: true,
        confirm: { title: 'Quit?', body: 'You will leave the server.' } },
      { id: 'q_car', label: 'Spawn car', quick: true },
      { id: 'q_board', label: 'Leaderboard', quick: true },
      { id: 'q_results', label: 'Results', quick: true },
      { id: 'q_crew', label: 'Crew', quick: true },
      { id: 'q_char', label: 'Character', quick: true },
    ],
  });
}
