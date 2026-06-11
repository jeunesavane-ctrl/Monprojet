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

/* Échappe le HTML — à utiliser sur TOUTE donnée saisie par un utilisateur
   avant injection via innerHTML (noms, notes, motifs, produits, titres…).
   Empêche le XSS stocké : un nom de produit "<img src=x onerror=…>" ne
   s'exécute plus dans le navigateur du manager. */
const escHtml = s => String(s ?? '')
  .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
  .replace(/"/g,'&quot;').replace(/'/g,'&#39;');

/* Échappe une chaîne destinée à un littéral JS entre apostrophes dans un
   attribut onclick="fn('…')". Indispensable pour les noms ouest-africains
   (N'Diaye, N'Guessan…) dont l'apostrophe cassait le handler. */
const jsStr = s => String(s ?? '')
  .replace(/\\/g,'\\\\').replace(/'/g,"\\'")
  .replace(/"/g,'&quot;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
  .replace(/\r?\n/g,' ');

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
  { href:'dashboard.html',  label:'Dashboard',  roles:['manager','owner','associe'] },
  { href:'saisie.html',     label:'Saisie',     roles:['staff'] },
  { href:'chicha.html',     label:'Chicha',     roles:['chicha','manager','owner'] },
  { href:'achats.html',     label:'Achats',     roles:['achats','manager','owner'] },
  { href:'caisse.html',     label:'Caisse',     roles:['caissier','manager','owner','associe'] },
  { href:'rapport.html',    label:'Rapport',    roles:['manager','owner'] },
  { href:'pointage.html',   label:'Pointage',   roles:['manager','owner'] },
  { href:'historique.html', label:'Historique', roles:['staff','caissier','chicha','achats','manager','owner','associe'] },
  { href:'fiche.html',      label:'Ma Fiche',   roles:['staff','caissier','chicha','achats'] },
  { href:'avance.html',     label:'Avance',     roles:['staff','caissier','chicha','achats'] },
  { href:'produits.html',   label:'Produits',   roles:['manager','owner'] },
  { href:'rh.html',         label:'RH',         roles:['manager','owner'] },
  { href:'avances.html',    label:'Avances',    roles:['manager','owner'] },
  { href:'charges.html',    label:'Charges',    roles:['manager','owner'] },
  { href:'finances.html',   label:'Finances',   roles:['owner','manager','associe'] },
  { href:'bilan.html',      label:'Bilan',      roles:['owner','manager','associe'] },
  { href:'associes.html',   label:'Associés',   roles:['owner','associe'] },
  { href:'parametres.html', label:'Paramètres', roles:['owner'] },
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
      role==='owner'    ? (extra.nom || 'Gestionnaire') :
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
    .map(n => {
      const dotId = n.href.replace('.html','');
      const dot = `<span id="nbadge-${dotId}" class="nav-dot" style="display:none"></span>`;
      return `<a class="nav-item${n.href===cur?' active':''}" href="${n.href}">${n.label}${dot}</a>`;
    })
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
  loadNavBadges();
  return true;
}

/* ── BADGES NAV ──────────────────────────────────────────────── */
async function loadNavBadges() {
  if (!db) return;
  const role = ML.getRole();
  if (!['caissier','manager','owner','associe'].includes(role)) return;
  try {
    const isManager = ['manager','owner'].includes(role);

    const [rembRes, avanceRes] = await Promise.all([
      db.from('remboursements_ecart').select('id').eq('statut','en_attente'),
      isManager
        ? db.from('avances').select('id').eq('statut','en_attente')
        : Promise.resolve({ data: [] })
    ]);

    const rembCount   = (rembRes.data   || []).length;
    const avanceCount = (avanceRes.data || []).length;

    const setBadge = (id, count, label) => {
      const el = $(id);
      if (el && count > 0) {
        el.style.display = 'inline-block';
        el.title = `${count} ${label}${count > 1 ? 's' : ''} en attente`;
      }
    };

    setBadge('nbadge-caisse',  rembCount,   'remboursement');
    setBadge('nbadge-avances', avanceCount, 'avance');
  } catch {}
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
