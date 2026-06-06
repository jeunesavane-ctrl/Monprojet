/* ================================================================
   MEDELLIN LOUNGE — SHARED JS v2.0
   Auth · Supabase · Utils · Navigation
================================================================ */

/* ── CONFIG ──────────────────────────────────────────────────── */
const SB_URL = 'https://stpmokparkaybgkabbeo.supabase.co';
const SB_KEY = 'sb_publishable_3L6fyV-zEZMX-EZaNHBPPQ_Hnsmee0Z';

/* ── SUPABASE ────────────────────────────────────────────────── */
let db = null;
try {
  if (typeof supabase !== 'undefined')
    db = supabase.createClient(SB_URL, SB_KEY);
} catch(e) { console.warn('Supabase:', e.message); }

/* ── AUTH ────────────────────────────────────────────────────── */
const ML = {
  getRole()   { return sessionStorage.getItem('ml_role'); },
  getHashes() {
    try { return JSON.parse(sessionStorage.getItem('ml_hashes') || '{}'); }
    catch { return {}; }
  },
  setSession(role, hashes, extra = null) {
    sessionStorage.setItem('ml_role', role);
    sessionStorage.setItem('ml_hashes', JSON.stringify(hashes));
    if (extra) sessionStorage.setItem('ml_extra', JSON.stringify(extra));
    else sessionStorage.removeItem('ml_extra');
    ML._logConnection(role, extra?.nom || null);
  },
  getExtra() {
    try { return JSON.parse(sessionStorage.getItem('ml_extra') || '{}'); }
    catch { return {}; }
  },
  lock() {
    sessionStorage.clear();
    window.location.href = 'index.html';
  },
  guard(allowedRoles = ['staff','caissier','chicha','achats','manager','owner']) {
    const role = ML.getRole();
    if (!role || !allowedRoles.includes(role)) {
      window.location.href = 'index.html';
      return false;
    }
    return true;
  },
  async _logConnection(role, nom = null) {
    if (!db) return;
    try {
      await db.from('logs').insert({
        role,
        action: nom || 'login',
        timestamp: new Date().toISOString()
      });
    } catch {}
  },
  async logAction(description) {
    if (!db) return;
    const role = this.getRole();
    if (!role) return;
    try {
      await db.from('logs').insert({
        role,
        action: description,
        timestamp: new Date().toISOString()
      });
    } catch {}
  },

  /* Auto-lock après inactivité */
  _lockTimer: null,
  _LOCK_DELAY: 10 * 60 * 1000, // 10 minutes
  resetLockTimer() {
    clearTimeout(ML._lockTimer);
    ML._lockTimer = setTimeout(() => {
      toast('Session expirée — reconnexion requise', 'ko');
      setTimeout(() => ML.lock(), 1800);
    }, ML._LOCK_DELAY);
  },
  initAutoLock() {
    ['click','touchstart','keydown','scroll','input'].forEach(ev =>
      document.addEventListener(ev, () => ML.resetLockTimer(), { passive:true })
    );
    ML.resetLockTimer();
  }
};

/* ── UTILS ───────────────────────────────────────────────────── */
const gnf = n =>
  new Intl.NumberFormat('fr-FR').format(Math.round(n ?? 0)) + ' GNF';

const frDate = d => {
  const dt = d ? new Date(d.includes('T') ? d : d+'T12:00:00') : new Date();
  return dt.toLocaleDateString('fr-FR',{weekday:'long',day:'numeric',
    month:'long',year:'numeric'});
};
const frDateShort = d => {
  const dt = d ? new Date(d.includes('T') ? d : d+'T12:00:00') : new Date();
  return dt.toLocaleDateString('fr-FR',{day:'numeric',month:'short'});
};
const frMonth = d => {
  const dt = d ? new Date(d.includes('T') ? d : d+'T12:00:00') : new Date();
  return dt.toLocaleDateString('fr-FR',{month:'long',year:'numeric'});
};
const todayISO = () => new Date().toISOString().slice(0,10);
const pad3 = n => String(n).padStart(3,'0');

const sha256 = async str => {
  const enc = new TextEncoder().encode(str);
  const buf = await crypto.subtle.digest('SHA-256', enc);
  return Array.from(new Uint8Array(buf))
    .map(b => b.toString(16).padStart(2,'0')).join('');
};

const $ = id => document.getElementById(id);

let _toastTimer;
function toast(msg, type = '') {
  const el = $('toast');
  if (!el) return;
  clearTimeout(_toastTimer);
  el.textContent = msg;
  el.className = type + ' show';
  _toastTimer = setTimeout(() => el.className = type, 2800);
}

/* ── NAVIGATION ──────────────────────────────────────────────── */
const NAV = [
  { href:'dashboard.html',  label:'Dashboard',   roles:['manager','owner','associe'] },
  { href:'saisie.html',     label:'Saisie',       roles:['staff'] },
  { href:'chicha.html',     label:'Chicha',       roles:['chicha','manager','owner'] },
  { href:'achats.html',     label:'Achats',       roles:['achats','manager','owner'] },
  { href:'caisse.html',     label:'Caisse',       roles:['caissier','manager','owner','associe'] },
  { href:'rapport.html',    label:'Rapport',      roles:['manager','owner'] },
  { href:'historique.html', label:'Historique',   roles:['staff','caissier','chicha','achats','manager','owner','associe'] },
  { href:'fiche.html',      label:'Ma Fiche',     roles:['staff','chicha','achats'] },
  { href:'produits.html',   label:'Produits',     roles:['manager','owner'] },
  { href:'rh.html',         label:'RH',           roles:['manager','owner'] },
  { href:'finances.html',   label:'Finances',     roles:['owner'] },
  { href:'associes.html',   label:'Associés',     roles:['owner','associe'] },
  { href:'parametres.html', label:'Paramètres',   roles:['owner'] },
];

function renderNav() {
  const role = ML.getRole();
  const nav  = $('app-nav');
  if (!nav || !role) return;

  const cur = window.location.pathname.split('/').pop() || 'dashboard.html';

  const badge = $('role-badge');
  if (badge) {
    const extra = ML.getExtra();
    badge.textContent =
      role==='owner'    ? 'Gestionnaire' :
      role==='manager'  ? (extra.nom || 'Manager') :
      role==='associe'  ? (extra.nom || 'Associé') :
      role==='staff'    ? (extra.nom || 'Staff') :
      role==='caissier' ? (extra.nom || 'Caissier') :
      role==='chicha'   ? (extra.nom || 'Chicha')   :
      role==='achats'   ? (extra.nom || 'Achats')   :
      'Utilisateur';
  }

  nav.innerHTML = NAV
    .filter(n => n.roles.includes(role))
    .map(n => `<a class="nav-item${n.href===cur?' active':''}"
        href="${n.href}">${n.label}</a>`)
    .join('');
}

/* ── PAGE INIT ───────────────────────────────────────────────── */
function initPage(allowedRoles) {
  if (!ML.guard(allowedRoles)) return false;
  renderNav();
  ML.initAutoLock();
  /* Demande permission notifications navigateur */
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission().catch(() => {});
  }
  return true;
}

/* ── SHARED HTML BLOCKS ──────────────────────────────────────── */
/* ── SERVICE WORKER (production uniquement) ──────────────────── */
if ('serviceWorker' in navigator && !location.hostname.includes('localhost')) {
  window.addEventListener('load', () =>
    navigator.serviceWorker.register('sw.js').catch(() => {})
  );
}

const HEADER_HTML = `
<header class="app-header">
  <a class="header-logo" href="dashboard.html">MEDELLIN</a>
  <div class="header-right">
    <span class="role-badge" id="role-badge"></span>
    <button class="btn-lock" onclick="ML.lock()">Verrouiller</button>
  </div>
</header>
<nav id="app-nav" class="app-nav"></nav>`;
