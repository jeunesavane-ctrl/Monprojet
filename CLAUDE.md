# Medellin Lounge — Directive de session v4.0

## Projet
Application web de gestion interne pour **Medellin Lounge** (Conakry, Guinée).
Activité : chicha + boissons. Architecture multi-fichiers statique (HTML/CSS/JS pur).
Pas de framework, pas de build step. Supabase JS v2 via CDN.

---

## Chemins importants
- **Dossier de travail (worktree actif) :** `C:\Users\jeune\Monprojet\.claude\worktrees\gracious-pare-d38438\`
- **Dossier de déploiement Netlify :** `C:\Users\jeune\Downloads\medellin\`
- **Netlify URL :** https://zesty-sunshine-d148e0.netlify.app
- Après toute modification : copier les fichiers modifiés dans `Downloads\medellin\` puis glisser sur Netlify

---

## Structure des fichiers
```
medellin/
├── index.html        ← Login PIN (5 rôles, comptes individuels)
├── dashboard.html    ← Stats + résumé hebdo + validation sessions caisse → rapport
├── saisie.html       ← Staff : saisie live des ventes en service (tablette)
├── caisse.html       ← Caissier : suivi temps réel + validation → manager
├── rapport.html      ← Formulaire rapport (legacy, reste pour historique) 
├── historique.html   ← Historique (staff voit ses propres rapports)
├── produits.html     ← Stocks chicha + boissons + onglet Commande (alertes)
├── rh.html           ← Équipe + Présences + Demandes + Avances + Paie
├── finances.html     ← Bilan, Dividendes, Trésorerie, Charges, +Charge, Évolution
├── parametres.html   ← PINs Gestionnaire+Manager, Comptes Employés+Caissiers, journal
├── associes.html     ← Page associés (owner voir tout, associé voir son %)
├── fiche.html        ← Fiche perso staff (présences, avances, solde)
├── shared.css        ← Styles communs (v4.0 Enterprise Edition)
├── shared.js         ← Auth (ML) + nav + utils + logConnection
├── manifest.json     ← PWA
└── sw.js             ← Cache offline ml-v4 (production uniquement)
```

---

## Credentials Supabase
- **URL :** `https://stpmokparkaybgkabbeo.supabase.co`
- **Anon Key :** `sb_publishable_3L6fyV-zEZMX-EZaNHBPPQ_Hnsmee0Z`
- **RLS :** DÉSACTIVÉ sur toutes les tables (obligatoire — client anon JS)

---

## Tables Supabase (état actuel)
| Table | Colonnes clés |
|-------|--------------|
| `rapports` | id, date, recettes, depenses, net, manager, employe_id, montant_exceptionnel, note_exception, **session_id** |
| `produits` | id, nom, type, quantite, seuil_bas, prix |
| `config` | key, value — PINs hashés + objectif + note_manager |
| `logs` | id, role, action (= nom employé ou 'login'), timestamp |
| `employes` | id, nom, prenom, poste, salaire, **pin_hash**, **role** (staff/caissier/manager), actif |
| `presences` | id, employe_id, date, statut |
| `avances` | id, employe_id, montant, date, rembourse, **statut** (en_attente/approuvee/refusee), **demandeur_id**, **note_demande** |
| `charges` | id, label, montant, mois |
| `associes` | id, nom, pin_hash, pourcentage, actif |
| `sessions_caisse` | id, date (UNIQUE), statut (ouvert→valide_caissier→valide_manager), note_caissier, note_manager, created_at |
| `ventes_session` | id, session_id→sessions_caisse, employe_id→employes, label, type (chicha/boisson/autre), qty, prix_unit, total, valide_staff, created_at |

### SQL à exécuter si pas encore fait (IMPORTANT)
```sql
-- Colonnes individuelles employés
ALTER TABLE employes ADD COLUMN IF NOT EXISTS pin_hash TEXT;
ALTER TABLE employes ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'staff';

-- Colonnes avances (demandes depuis rapport.html)
ALTER TABLE avances ADD COLUMN IF NOT EXISTS statut TEXT DEFAULT 'approuvee';
ALTER TABLE avances ADD COLUMN IF NOT EXISTS demandeur_id UUID;
ALTER TABLE avances ADD COLUMN IF NOT EXISTS note_demande TEXT;

-- Colonnes rapport (dépense exceptionnelle + lien employé + session + caisse complète)
ALTER TABLE rapports ADD COLUMN IF NOT EXISTS montant_exceptionnel INTEGER DEFAULT 0;
ALTER TABLE rapports ADD COLUMN IF NOT EXISTS note_exception TEXT;
ALTER TABLE rapports ADD COLUMN IF NOT EXISTS employe_id UUID;
ALTER TABLE rapports ADD COLUMN IF NOT EXISTS session_id UUID;
ALTER TABLE rapports ADD COLUMN IF NOT EXISTS fond_caisse INTEGER DEFAULT 0;
ALTER TABLE rapports ADD COLUMN IF NOT EXISTS entrees_caisse INTEGER DEFAULT 0;
ALTER TABLE rapports ADD COLUMN IF NOT EXISTS sorties_caisse INTEGER DEFAULT 0;
ALTER TABLE rapports ADD COLUMN IF NOT EXISTS total_reel INTEGER;
ALTER TABLE rapports ADD COLUMN IF NOT EXISTS ecart INTEGER;

-- Nouvelles tables workflow caisse
CREATE TABLE IF NOT EXISTS sessions_caisse (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date DATE UNIQUE NOT NULL,
  statut TEXT DEFAULT 'ouvert',
  note_caissier TEXT,
  note_manager TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ventes_session (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES sessions_caisse(id) ON DELETE CASCADE,
  employe_id UUID REFERENCES employes(id),
  label TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'chicha',
  qty INTEGER NOT NULL DEFAULT 1,
  prix_unit INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL DEFAULT 0,
  valide_staff BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

---

## Système d'authentification (5 rôles)
| Rôle | Source | Accès | Redirection après login |
|------|--------|-------|------------------------|
| `owner` | PIN dans `config.pin_owner` | TOUT — caisse en **lecture seule** | dashboard.html |
| `manager` | PIN dans `config.pin_manager` | Dashboard, Rapport, Historique, Produits, RH, Caisse **lecture seule** | dashboard.html |
| `caissier` | Compte individuel `employes` (role='caissier') | Caisse (lecture + validation), Historique | caisse.html |
| `staff` | Compte individuel `employes` (role='staff') | Saisie ventes, Historique perso, Ma Fiche | saisie.html |
| `associe` | Compte individuel table `associes` (pin_hash) | Dashboard, Historique, Finances, Associés, Caisse **lecture seule** | dashboard.html |

### Règles importantes
- **Caissier** créé par l'owner dans Paramètres → Comptes Employés (role='caissier')
- **Caisse en lecture seule** pour owner/manager/associé — aucune modification possible
- `owner` s'appelle **Gestionnaire** dans l'UI (pas "Propriétaire")
- Le gestionnaire est aussi associé (son % = 100 - somme des autres associés)
- `sessionStorage` stocke : `ml_role`, `ml_hashes`, `ml_extra`
- `ml_extra` contient : `{ nom, employe_id }` pour staff/caissier · `{ nom, pourcentage, id }` pour associé
- Auto-lock : 10 min d'inactivité → retour index.html
- Cycle de rôle dans Paramètres : staff → caissier → manager → staff

---

## shared.js — points clés
```javascript
// Badge affichage selon rôle
badge.textContent =
  role==='owner'    ? 'Gestionnaire' :
  role==='manager'  ? (extra.nom || 'Manager') :
  role==='associe'  ? (extra.nom || 'Associé') :
  role==='staff'    ? (extra.nom || 'Staff') :
  role==='caissier' ? (extra.nom || 'Caissier') : 'Staff';

// Log connexion : stocke le NOM dans action (pas juste le rôle)
async _logConnection(role, nom = null) {
  await db.from('logs').insert({
    role, action: nom || 'login', timestamp: new Date().toISOString()
  });
}

// setSession transmet le nom au log
setSession(role, hashes, extra = null) {
  sessionStorage.setItem('ml_role', role);
  sessionStorage.setItem('ml_hashes', JSON.stringify(hashes));
  if (extra) sessionStorage.setItem('ml_extra', JSON.stringify(extra));
  else sessionStorage.removeItem('ml_extra');
  ML._logConnection(role, extra?.nom || null);
}

// Nav : historique accessible au staff
{ href:'historique.html', label:'Historique', roles:['staff','manager','owner','associe'] }
```

---

## index.html — flux checkPin()
1. Hash SHA-256 du PIN saisi
2. Compare avec `hOwner` → role `owner`
3. Compare avec `hManager` → role `manager`
4. Cherche dans `employesList` (employes avec pin_hash) → role = emp.role, extra = {nom, employe_id}
5. Cherche dans `associesList` → role `associe`, extra = {nom, pourcentage, id}
6. Aucun match → erreur "Code incorrect"
7. **Pas de fallback PIN collectif staff** (supprimé pour sécurité)

---

## parametres.html — sections
- **PIN Gestionnaire** + **PIN Manager** (le PIN Staff a été supprimé)
- **Note pour le Manager** : textarea → sauvegarde avec select+update/insert dans `config`
  ```javascript
  async function saveNoteManager() {
    const { data: existing } = await db.from('config').select('key').eq('key','note_manager');
    if (existing?.length) {
      await db.from('config').update({value: val}).eq('key','note_manager');
    } else {
      await db.from('config').insert({key:'note_manager', value: val});
    }
  }
  ```
- **Comptes Employés** : CRUD complet — créer compte (PIN), donner/retirer accès, changer rôle (staff↔manager)
- **Journal connexions** : affiche nom depuis `l.action` si différent de 'login'

---

## rapport.html — fonctionnalités
- Pré-rempli avec nom de l'employé connecté (extra.nom)
- Dépense exceptionnelle : checkbox → champs montant + note
- Demande d'avance : bouton visible si `employe_id` — modal montant + motif → insert dans `avances` avec statut `en_attente`
- Stocke `employe_id` dans le rapport pour lier à l'employé

---

## historique.html
- Accessible à tous les rôles (staff, manager, owner, associé)
- Staff : voit uniquement ses propres rapports (filtre par `employe_id` ou fallback `manager` = nom)
- Staff : pas de filtre dropdown ni filtre net minimum
- Bannière pour staff : "📋 Vos rapports soumis — X au total"

---

## rh.html — onglets
| Onglet | Accès |
|--------|-------|
| Équipe | owner |
| Présences | owner + manager |
| Demandes | owner + manager — avances `en_attente` avec boutons Approuver/Refuser |
| Avances | owner |
| Paie | owner |

- Badge sur "Demandes" : compteur des requêtes en attente
- `validerDemande()` → statut `approuvee`, rembourse false
- `refuserDemande()` → statut `refusee`, rembourse true

---

## finances.html — onglets (6)
| Onglet | Contenu |
|--------|---------|
| Bilan | Résumé mensuel, recettes, charges, net |
| Dividendes | Distribution : Gestionnaire (or) + chaque associé selon % |
| Trésorerie | Net cumulé - avances non remboursées |
| Charges | Liste charges fixes |
| +Charge | Ajouter charge ponctuelle |
| Évolution | Graphique 6 mois Chart.js |

- Export : PDF (window.print) + CSV (Blob + BOM UTF-8) + Envoyer (navigator.share / WhatsApp)
- **Pourcentage Gestionnaire = 100 - somme des % associés** (dynamique, pas hardcodé)

---

## dashboard.html — blocs clés
- Résumé hebdo : semaine en cours vs semaine précédente
- Note du gestionnaire (pour manager) : lit `config.note_manager`
- Notification navigateur si pas de rapport après 20h (une fois par jour)
- % dividendes gestionnaire calculé dynamiquement depuis table `associes`
- Bloc "Performance Managers" SUPPRIMÉ (un seul manager)

---

## produits.html
- Onglet **Commande** : liste tous les produits à/sous seuil_bas, groupés par type
- Bouton Imprimer → `window.print()`, CSS masque les autres onglets

---

## associes.html
- Owner : "Gestionnaire (vous)" en premier (or) avec son % calculé + chaque associé
- Associé : voit sa propre fiche + historique de sa part mensuelle
- `buildCard()` helper pour affichage uniforme

---

## Design
- Fond : `#0D0D0D` | Accent : `#C9A84C` (or)
- Titres : **Bebas Neue** | Corps : **DM Sans**
- Mobile-first (staff = téléphone)

---

## État actuel — ce qui est FAIT ✅
- [x] 4 rôles : owner (Gestionnaire), manager, staff individuel, associé
- [x] PIN collectif staff supprimé — sécurité
- [x] Comptes employés individuels (CRUD dans Paramètres)
- [x] Journal connexion affiche les noms
- [x] Note gestionnaire → manager (bug corrigé : select + update/insert)
- [x] Historique personnel pour staff (ses propres rapports)
- [x] Demande d'avance depuis rapport.html
- [x] Onglet Demandes dans RH (approbation/refus)
- [x] Dépense exceptionnelle dans rapport
- [x] Résumé hebdo dashboard
- [x] Export CSV + envoi WhatsApp (finances)
- [x] Trésorerie (Finances, onglet dédié)
- [x] Dividendes dynamiques (% calculé)
- [x] Onglet Commande (produits bas stock)
- [x] Associés voient les finances (dividendes, trésorerie)
- [x] sw.js version ml-v4
- [x] **Fiche employé perso** : `fiche.html` — profil, présences (mois sélectionnable), avances, solde net estimé
- [x] **Owner retiré du rapport** — nav rapport.html : `['staff','manager']` seulement
- [x] **Journal d'activité détaillé** — 50 entrées, connexions 🔑 vs actions 📋✅❌ visuellement séparées
- [x] **ML.logAction()** — helper global pour logguer actions depuis n'importe quelle page
- [x] **Rapport loggué** — `📋 Rapport N°xxx soumis — Net xxx GNF` au submit
- [x] **Avances logguées** — `✅ Approuvée` / `❌ Refusée` avec nom + montant dans rh.html
- [x] **Dashboard refonte complète** — 6 KPI cards, 4 graphiques (area 30j, bar semaines, donut stylé, bar jour/semaine), associés ont leur propre graphique

## Ce qui RESTE à faire 🔲
- [ ] **Déploiement Netlify** : copier `Downloads\medellin\` et glisser
- [ ] **Tester en local** (Python server : `python -m http.server 8080`)
- [ ] **Confirmer SQL exécuté** dans Supabase (colonnes avances + rapports + employes)
- [ ] Checklist ouverture/fermeture (configurable owner)
- [ ] Alerte stock WhatsApp (lien auto quand produit sous seuil)
- [ ] Mode hors-ligne rapport (sauvegarde locale + sync)
- [ ] Vue finances complète pour associés (charges détaillées)

- [ ] **Checklist ouverture/fermeture** : liste de tâches configurable par l'owner
- [ ] **Alerte stock WhatsApp** : lien auto vers WhatsApp quand produit sous seuil
- [ ] **Objectif mensuel** : target + barre de progression dans dashboard
- [ ] **Mode hors-ligne rapport** : sauvegarde locale si pas de réseau, envoi à la reconnexion
- [ ] **Vue finances complète pour associés** : voir charges détaillées, pas seulement dividendes
- [ ] **Déploiement Netlify** : copier Downloads\medellin\ et glisser

---

## Pour reprendre
Dis : **"Lis le CLAUDE.md et continue"**

Le worktree actif est : `C:\Users\jeune\Monprojet\.claude\worktrees\gracious-pare-d38438\`
