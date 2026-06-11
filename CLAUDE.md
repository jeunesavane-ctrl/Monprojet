# Medellin Lounge — CLAUDE.md v10.0

## Projet
Application web de gestion interne — **Medellin Lounge** (Conakry, Guinée).
Activité : chicha + boissons. HTML/CSS/JS pur, Supabase JS v2 via CDN, Netlify Pro (déploiement **manuel**).

---

## Chemins & déploiement
- **Dossier :** `C:\Users\jeune\Monprojet`
- **GitHub :** `https://github.com/jeunesavane-ctrl/Monprojet.git` (branche `main`)
- **Production :** `https://medellin-lounge.com` (domaine custom, Netlify Pro)
- **Netlify fallback :** `https://medellin-lounge.netlify.app`
- **⚠ `git push origin main`** = versioning seulement (auto-deploy DÉSACTIVÉ)
- **Déploiement** = manuel depuis le dashboard Netlify, quand le propriétaire est satisfait
- Ne jamais dire "c'est en ligne" après un push — dire "code poussé sur git"

---

## Credentials Supabase
- **URL :** `https://stpmokparkaybgkabbeo.supabase.co`
- **Anon Key :** `sb_publishable_3L6fyV-zEZMX-EZaNHBPPQ_Hnsmee0Z`
- **RLS :** DÉSACTIVÉ sur toutes les tables

---

## 7 rôles
| Rôle | Pages accessibles |
|------|-------------------|
| `owner` | Tout (18 pages) |
| `manager` | Dashboard, Chicha, Achats, Caisse, Rapport, Pointage, Historique, RH, Avances, Charges, Finances, Bilan |
| `associe` | Dashboard, Caisse (lecture), Historique, Finances (Mes Parts), Bilan, Associés |
| `caissier` | Caisse, Historique, Ma Fiche, Avance |
| `staff` | Saisie, Historique, Ma Fiche, Avance |
| `chicha` | Chicha, Historique, Ma Fiche, Avance |
| `achats` | Achats, Historique, Ma Fiche, Avance |

---

## Navigation — 18 items (shared.js)
```javascript
{ href:'dashboard.html',  roles:['manager','owner','associe'] },
{ href:'saisie.html',     roles:['staff'] },
{ href:'chicha.html',     roles:['chicha','manager','owner'] },
{ href:'achats.html',     roles:['achats','manager','owner'] },
{ href:'caisse.html',     roles:['caissier','manager','owner','associe'] },
{ href:'rapport.html',    roles:['manager','owner'] },
{ href:'pointage.html',   roles:['manager','owner'] },
{ href:'historique.html', roles:['staff','caissier','chicha','achats','manager','owner','associe'] },
{ href:'fiche.html',      roles:['staff','caissier','chicha','achats'] },
{ href:'avance.html',     roles:['staff','caissier','chicha','achats'] },
{ href:'produits.html',   roles:['manager','owner'] },
{ href:'rh.html',         roles:['manager','owner'] },
{ href:'avances.html',    roles:['manager','owner'] },
{ href:'charges.html',    roles:['manager','owner'] },
{ href:'finances.html',   roles:['owner','manager','associe'] },
{ href:'bilan.html',      roles:['owner','manager','associe'] },
{ href:'associes.html',   roles:['owner','associe'] },
{ href:'parametres.html', roles:['owner'] },
```

### Badges nav (points rouges)
- `nbadge-caisse` → remboursements_ecart `en_attente`
- `nbadge-avances` → avances `en_attente` (manager/owner seulement)
- Chargés par `loadNavBadges()` dans `shared.js` → appelé depuis `initPage()`

---

## Tables Supabase
| Table | Colonnes clés |
|-------|--------------|
| `employes` | id, nom, prenom, poste, role, salaire_base, **pourcentage** (associés), pin_hash, actif |
| `config` | key, value |
| `rapports` | id, date, num, total_chicha, total_boissons, total_achats, net, recettes, manager, caissier, session_id, chicha_rows, boissons_rows, achats_rows, part |
| `presences` | id, employe_id, date, statut (present/absent/retard/conge) — UNIQUE(employe_id, date) |
| `justifications` | id, employe_id, date, type, motif, statut (en_attente/approuvee/rejetee) |
| `avances` | id, employe_id, montant, date, statut (en_attente/approuvee/rejetee), rembourse, obs, note_demande |
| `salaires_verses` | id, employe_id, mois, salaire_brut, avances_deduites, ecarts_deduits, surplus_caisse, net_verse, nb_absences_nj, sanction_type, sanction_montant, nb_retards, sanction_retard_montant, paye_le — UNIQUE(employe_id, mois) |
| `charges` | id, label, montant, mois, categorie, paye, date_paiement, recurrence |
| `produits` | id, nom, type, stock_actuel, seuil_bas, prix, prix_achat, unite_vente, packaging_label, unite_par_packaging, actif **NOT NULL DEFAULT true** |
| `sessions_caisse` | id, date, statut, fond_caisse, total_reel, total_om_verifie, ecart, caissier_id, note_caissier, note_manager |
| `remboursements_ecart` | id, session_id, employe_id, montant, note, statut (en_attente/valide/rejete), created_at |
| `logs` | id, role, action, timestamp |
| `credits` | id, employe_id, session_id, montant, rembourse |
| `mouvements_caisse` | id, session_id, type (entree/sortie), motif, montant, note, created_at |
| `achats_session` | id, session_id, categorie, produit_nom, montant, qty, prix_unitaire, created_at |
| `sorties_chicha` | id, session_id, employe_id, arome, qty, valide, created_at |
| `propositions` | id, titre, description, auteur_nom, statut (ouvert/ferme), created_at |
| `votes_prop` | id, proposition_id, votant_key, votant_nom, poids, choix (bool), created_at — UNIQUE(proposition_id, votant_key) |

> ⚠ La table `associes` N'EXISTE PLUS — tout est dans `employes` (colonne `pourcentage`)
> ⚠ `salaires.html` EXISTE mais est **exclu de la nav** (logique périmée, conflit avec rh.html)
> ⚠ Filtre produits actifs : toujours `.not('actif','is',false)` — jamais `.eq('actif',true)` ni `.neq('actif',false)` (excluraient les NULL)

### Config keys
| Clé | Description | Défaut |
|-----|-------------|--------|
| `pin_owner` | Hash SHA-256 du PIN gestionnaire | — |
| `pin_manager` | Hash SHA-256 du PIN manager | `b8dc2c1...` |
| `pin_staff` | Hash SHA-256 du PIN staff | `03ac674...` |
| `owner_nom` | Nom affiché pour le gestionnaire | — |
| `note_manager` | Message visible par les managers | — |
| `objectif_journalier` | Objectif de net par jour (GNF) | — |
| `part_lounge` | % du net réservé au lounge avant distribution | `10` |
| `owner_pct` | % fixe du gestionnaire (si absent : 100 - assocs%) | auto |

---

## Authentification — index.html
1. Hash SHA-256 du PIN saisi
2. Compare `hOwner` (config) → `owner`
3. Compare `hManager` (config) → `manager`
4. Cherche dans `employes` par pin_hash
   - `role='associe'` → extra = `{ nom, pourcentage, id }`
   - Sinon → extra = `{ nom, employe_id }`

**sessionStorage :** `ml_role`, `ml_hashes` `{hOwner,hStaff,hManager}`, `ml_extra`
**Auto-lock :** 10 min d'inactivité → `ML.lock()`

---

## Formules de calcul — INVARIANTES

### Distribution
```
part_lounge_pct = config.part_lounge (défaut 10)
distribPct      = MAX(0, 100 - part_lounge_pct) / 100

owner_pct       = config.owner_pct si défini, sinon MAX(0, 100 - sum(assocs%))
part_owner      = MAX(0, net_for_parts) × distribPct × owner_pct / 100
part_assoc_X    = MAX(0, net_for_parts) × distribPct × assocX_pct / 100

net_for_parts (finances/associes/bilan) = sum(rapports.net) - sum(charges_fixes)
```

### P&L
```
recettes    = sum(total_chicha + total_boissons)
net_ventes  = recettes - sum(total_achats)          ← rapports.net
net_final   = net_ventes - sum(charges_fixes)       ← finances.html / bilan.html
tresorerie  = net_final - avances(statut IN [en_attente,approuvee] AND rembourse=false)
```

### Salaire (rh.html / fiche.html)
```
brut             = salaire_base
absNJ            = absences - justifications_approuvees (ce mois)
sanctions_abs    = brut × (0 si absNJ=0, 0.10 si absNJ=2, 0.15 si absNJ≥3)
sanctions_ret    = brut × 0.10 si retards ≥ 5 ce mois
avances_ded      = SUM(avances WHERE statut='approuvee' AND rembourse=false) — TOUTES dates
ecarts_ded       = SUM(ecart_especes > 0) - SUM(remboursements_valides) — ce mois
                   (ecart_especes ?? ecart : repli sur l'écart total avant migration ;
                    l'écart OM N'EST PLUS déduit du salaire caissier)
surplus_bonus    = SUM(|ecart_especes < 0|) — ce mois
net_verse        = MAX(0, brut - sanctions_abs - sanctions_ret - avances_ded - ecarts_ded + surplus_bonus)

PAYER  → INSERT salaires_verses + UPDATE avances SET rembourse=true
ANNULER → DELETE salaires_verses (avances gardent rembourse=true)
```

### Écart caisse — FORMULE CORRECTE
```
TOTAL = espèces + OM  (les deux sont de l'argent reçu)

théorique     = fond + totVentes(esp+OM) + entrées - sorties - achats
theoriqueEsp  = fond + totEsp           + entrées - sorties - achats

écart espèces = theoriqueEsp - réel_espèces_comptées   ← stocké dans sessions_caisse.ecart_especes
écart OM      = totOM_déclaré_staff - totOM_reçu_caissière
écart total   = écart espèces + écart OM               ← stocké dans sessions_caisse.ecart (affichage)

(+ = manque, − = excédent/surplus)

⚠ PAIE : seul `ecart_especes` impacte le salaire caissier. L'écart OM (déclaratif
   staff vs reçu téléphone) N'EST PAS un manquant caissier → jamais déduit.
   rh.html / fiche.html lisent `ecart_especes ?? ecart` (repli pour sessions
   d'avant la migration `ecart_especes`).
```

### Session caisse
- `caisse.html` **auto-crée** une session pour aujourd'hui si elle n'existe pas (rôle caissier/manager/owner)
- `saisie.html` **aussi** crée la session si elle n'existe pas (rôle staff)
- Flux : session ouverte → staff saisissent (plusieurs tours possibles) → caissier clôture → manager valide → rapport créé

### Flow de données par source
```
saisie.html  (staff)   → ventes_session   → caisse.html lit tout (inclus dans totaux)
achats.html  (achats)  → achats_session   → caisse.html lit + rapport.html préremplit
chicha.html  (chicha)  → sorties_chicha   → STOCK UNIQUEMENT (pas dans caisse.html)
rapport.html (manager) → chicha/boissons saisis MANUELLEMENT + achats préremplis → rapports
```
⚠ `sorties_chicha` = suivi inventaire chicha, PAS utilisé pour les calculs financiers du rapport.
⚠ Le manager saisit manuellement les lignes chicha et boissons dans rapport.html.

### Validation gestionnaire (dashboard.html openValidation)
- ⚠ **NE PAS recalculer l'écart** dans `openValidation()` — utiliser `sessInfo.ecart` (valeur stockée à la clôture)
- Le SELECT sessions_caisse doit inclure `ecart` : `...note_caissier,ecart`
- `storedEcart = sessInfo.ecart ?? null` → passer à `finalizeSession` comme 11e argument
- Si `reelOM = null` → afficher "Non vérifié — aucun écart OM compté" (pas "Reçu caissière: —")
- `finalizeSession` reçoit `(sessId, sessDate, totVentes, nextNum, totC, totB, fond, totEntrees, totSorties, reelEsp, storedEcart)`

---

## saisie.html — comportement multi-saisies (v10)
- Staff peut saisir plusieurs **tours de ventes** dans la même journée
- Après clôture → écran "Saisie envoyée ✓" + bouton **"+ AJOUTER DES VENTES"**
- `sessionStatut` est lu depuis `sessions_caisse` au chargement et suivi en temps réel
- Si session = `valide_caissier` ou `valide_manager` → écran **🔒 Session clôturée** (lecture seule)
- `confirmAdd()` et `nouvellesSaisies()` bloquent toute modification si session locked
- Listener Postgres sur `sessions_caisse` : si la caissière valide pendant que le staff a l'écran ouvert → verrouillage automatique

---

## Bugs corrigés (historique à ne pas réintroduire)
| Fichier | Bug | Fix |
|---------|-----|-----|
| `bilan.html` | SELECT incluait `statut` (n'existe pas dans `rapports`) → données vides | Retiré `statut` du SELECT |
| `rh.html` | `validerPaie()` cherchait `.ilike('libelle','Salaires%')` → jamais trouvé → doublons | Changé en `.ilike('label','Salaires%')` |
| `charges` table | Colonne documentée `libelle` mais s'appelle **`label`** | Corrigé dans CLAUDE.md |
| `rapport.html` | `fetchNextNum` triait par `date` → N° en double si un rapport jour passé existait | Calcul `max(num)` numérique (+ idem `dashboard.html` × 2) |
| `rapport.html` | `checkDejaEnvoye` cosmétique (opacity) → 2e rapport possible le même jour | `disabled=true` + flag `dejaEnvoye` bloque `openConfirm`/`doSubmit` |
| `caisse.html` | Note de clôture passée dans un `onclick` → apostrophe/guillemet cassait la validation | Note passée via `_clotureCtx` + garde anti double-clôture `_finalizing` |
| `caisse/avances/fiche` | Montants négatifs acceptés (`if(!montant)`) → totaux corrompus | Validation `if(!(montant>0))` partout |
| `saisie/caisse/chicha/achats` | Création session non atomique → erreur clé dupliquée si 2 rôles ouvrent en même temps | Re-`select` de la session existante si l'`insert` échoue |
| `fiche.html` | `soumettreAvance` ne vérifiait pas les demandes en attente → spam (incohérent avec `avance.html`) | Anti-doublon `en_attente` ajouté |
| **TOUTES pages** | XSS stocké : données saisies injectées en `innerHTML` sans échappement | Helper `escHtml()` dans `shared.js` appliqué à tous les noms/notes/produits/libellés/titres |
| `parametres/rh/charges` | Noms/libellés à apostrophe (N'Diaye, « l'eau ») dans des `onclick` → handler cassé | Helper `jsStr()` dans `shared.js` pour échapper le contexte JS-attribut |
| `achats.html` | `function escHtml` locale en collision avec le `const escHtml` global de `shared.js` → page cassée | Définition locale supprimée (utilise celle de `shared.js`) |
| `bilan.html` | Salaires comptés **2 fois** (charge « Salaires » créée par `validerPaie` + `salaires_verses`) → résultat net faux | Salaires comptés **une fois au brut** : `chargesHorsSalaires` séparé ; parts inchangées (cohérent finances.html) |
| `caisse/rh/fiche/rapport` | Écart **OM** mélangé à l'écart espèces dans `ecart` → déduit à tort du salaire caissier | Nouvelle colonne `ecart_especes` (écart espèces seul) ; paie déduit `ecart_especes ?? ecart` (repli historique) |
| `dashboard.html` | `finalizeSession` pouvait créer un 2e rapport pour une date déjà couverte | Garde `_finalizingSess` + vérif `rapports` existant pour la date avant insert |

> ⚙ **Convention** : toute donnée utilisateur injectée via `innerHTML` doit passer par `escHtml(...)`. Toute donnée passée dans `onclick="fn('…')"` doit passer par `jsStr(...)`. Les deux sont dans `shared.js`.

> 🔐 **Sécurité structurelle (base ouverte)** : voir **`SECURITE.md`** — RLS désactivé + clé anon publique = base accessible à tous. **Non corrigeable côté HTML** : nécessite RLS + login côté serveur (Edge Function) à déployer dans Supabase. Plan de bascule par phases dans `SECURITE.md`.

---

## Pages — descriptions

| Page | Rôles | Description |
|------|-------|-------------|
| `index.html` | tous | Login PIN |
| `dashboard.html` | manager/owner/associe | KPIs, graphiques, alertes sessions en attente |
| `saisie.html` | staff | Formulaire de saisie ventes du jour |
| `chicha.html` | chicha/manager/owner | Saisie chicha avec catalogue |
| `achats.html` | achats/manager/owner | Saisie achats/dépenses |
| `caisse.html` | caissier/manager/owner/associe | Session caisse, mouvements, clôture, remboursements écart |
| `rapport.html` | manager/owner | Génère le rapport journalier depuis session caisse |
| `pointage.html` | manager/owner | Présences/absences/retards/congés par date |
| `historique.html` | tous | Liste rapports avec filtres + 🗑 suppression par rapport (owner) |
| `fiche.html` | staff/caissier/chicha/achats | Solde salaire estimé, avances, écarts caissier |
| `avance.html` | staff/caissier/chicha/achats | Demande d'avance sur salaire |
| `produits.html` | manager/owner | Catalogue produits + stock |
| `rh.html` | manager/owner | 5 onglets : Équipe / Présences / Demandes / Avances / Paie |
| `avances.html` | manager/owner | Vue globale avances en attente + approuvées |
| `charges.html` | manager/owner | Charges fixes mensuelles (loyer, salaires fixes…) |
| `finances.html` | owner/manager/associe | Bilan / Dividendes / Trésorerie / Charges / Évolution |
| `bilan.html` | owner/manager/associe | Bilan mensuel complet + répartition des parts |
| `associes.html` | owner/associe | Parts par associé sur 3/6/12 mois + Propositions & Votes |
| `parametres.html` | owner | PINs, comptes, config, part lounge, part gestionnaire |

---

## rh.html — 5 onglets
| Onglet | Fonctionnalité |
|--------|---------------|
| Équipe | Liste staff actif |
| Présences | Sélecteur date, 4 statuts (présent/absent/retard/congé), "Tous présents" |
| Demandes | Avances + justifications `en_attente`, Approuver/Rejeter |
| Avances | Manager ajoute avance → `statut=approuvee` immédiatement |
| Paie | Mois sélectionnable, VERSER par employé, toutes déductions calculées auto |

---

## finances.html — 6 onglets
| Onglet | Accès | Base de calcul |
|--------|-------|----------------|
| Bilan | owner + manager | `net_final = rapports.net - charges` |
| Dividendes | owner seulement | même base, répartition complète |
| Trésorerie | owner + manager | `net_final - avances_non_remb` |
| Charges | owner + manager | liste charges par mois |
| + Charge | owner + manager | formulaire ajout charge |
| Évolution | owner + manager | 6–18 mois, graphique |

Associé voit UNIQUEMENT un onglet "Mes Parts" (injected) — part perso 6 mois.

---

## bilan.html
- KPIs : Recettes / Achats / Marge brute / Charges fixes / Salaires (info) / Résultat net
- `resultatNet` (KPI) = marge − charges − salaires  ← vue comptable
- Parts calculées sur `marge − charges` uniquement (cohérent avec finances.html)
- Répartition : 🏠 Lounge + Associés + Gestionnaire = 100% du distribuable

---

## parametres.html
- **Part lounge** : % réservé au lounge avant distribution (config `part_lounge`, défaut 10)
- **Part gestionnaire** : % fixe (config `owner_pct`) ou auto (100% − assocs%)
- ⚠ **PAS de reset en masse** — la zone dangereuse a été supprimée
- Suppression des rapports : se fait rapport par rapport depuis `historique.html`

## historique.html — Suppression de rapport (owner)
- Bouton 🗑 visible uniquement pour le rôle `owner` dans chaque rapport ouvert
- `openDeleteRapport(id, sessionId, num, dateDisplay, rawDate)` → modal de confirmation
  (le bandeau `del-session-info` explique le devenir de la session)
- `confirmDeleteRapport()` → DELETE rapports WHERE id, puis :
  - rapport du **JOUR** → session **ROUVERTE** (`statut='ouvert'`) : le staff peut
    ressaisir (saisie.html se déverrouille en temps réel), la caissière reclôturer
    (caisse.html écoute aussi sessions_caisse et libère `_finalizing`), le manager
    revalider → nouveau rapport
  - rapport **passé** → `statut='valide_caissier'` (revalidation depuis Dashboard ;
    saisie.html ne charge que la session du jour, donc réouverture inutile)
- Pas de cascade suppression ; `_delRapport` stocke l'entrée en cours

---

## Design
- Fond : `#0D0D0D` | Accent or : `#C9A84C`
- Titres : **Bebas Neue** | Corps : **DM Sans**
- Mobile-first (staff = téléphone)
- `shared.css` + `shared.js` inclus dans chaque page

---

## SQL migrations — à exécuter si tables manquantes

```sql
-- Presences
CREATE TABLE IF NOT EXISTS presences (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id UUID REFERENCES employes(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  statut TEXT NOT NULL DEFAULT 'present',
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(employe_id, date)
);
ALTER TABLE presences DISABLE ROW LEVEL SECURITY;

-- Justifications
CREATE TABLE IF NOT EXISTS justifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id UUID REFERENCES employes(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  type TEXT,
  motif TEXT,
  statut TEXT DEFAULT 'en_attente',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE justifications DISABLE ROW LEVEL SECURITY;

-- Remboursements écart caisse
CREATE TABLE IF NOT EXISTS remboursements_ecart (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES sessions_caisse(id) ON DELETE CASCADE,
  employe_id UUID REFERENCES employes(id) ON DELETE CASCADE,
  montant INTEGER NOT NULL,
  note TEXT,
  statut TEXT DEFAULT 'en_attente',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE remboursements_ecart DISABLE ROW LEVEL SECURITY;

-- Salaires versés (colonnes récentes)
ALTER TABLE salaires_verses
  ADD COLUMN IF NOT EXISTS surplus_caisse          INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS nb_absences_nj          INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS sanction_type           TEXT    NOT NULL DEFAULT 'aucune',
  ADD COLUMN IF NOT EXISTS sanction_montant        INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS nb_retards              INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS sanction_retard_montant INTEGER NOT NULL DEFAULT 0;

-- Sessions caisse (colonnes récentes)
ALTER TABLE sessions_caisse
  ADD COLUMN IF NOT EXISTS ecart              INTEGER,
  ADD COLUMN IF NOT EXISTS caissier_id        UUID REFERENCES employes(id),
  ADD COLUMN IF NOT EXISTS surplus_caisse     INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_om_verifie   INTEGER,
  -- ⚠ NOUVEAU (à exécuter) : écart ESPÈCES seul, séparé de l'écart total.
  -- Seul cet écart est déduit du salaire caissier (l'écart OM ne l'est plus).
  -- Repli automatique sur `ecart` pour les sessions clôturées avant migration.
  ADD COLUMN IF NOT EXISTS ecart_especes      INTEGER;

-- Produits : actif NOT NULL (à exécuter une fois)
UPDATE produits SET actif = true WHERE actif IS NULL;
ALTER TABLE produits ALTER COLUMN actif SET DEFAULT true;
ALTER TABLE produits ALTER COLUMN actif SET NOT NULL;

-- Mouvements caisse (entrées/sorties manuelles dans session)
CREATE TABLE IF NOT EXISTS mouvements_caisse (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES sessions_caisse(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('entree','sortie')),
  motif TEXT,
  montant INTEGER NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE mouvements_caisse DISABLE ROW LEVEL SECURITY;

-- Achats tracké dans session (achats.html)
CREATE TABLE IF NOT EXISTS achats_session (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES sessions_caisse(id) ON DELETE CASCADE,
  categorie TEXT,
  produit_nom TEXT,
  montant INTEGER NOT NULL,
  qty NUMERIC DEFAULT 1,
  prix_unitaire INTEGER,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE achats_session DISABLE ROW LEVEL SECURITY;

-- Sorties chicha (chicha.html)
CREATE TABLE IF NOT EXISTS sorties_chicha (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES sessions_caisse(id) ON DELETE SET NULL,
  employe_id UUID REFERENCES employes(id) ON DELETE CASCADE,
  arome TEXT,
  qty INTEGER NOT NULL DEFAULT 1,
  valide BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE sorties_chicha DISABLE ROW LEVEL SECURITY;

-- Propositions (associes.html — votes entre associés)
CREATE TABLE IF NOT EXISTS propositions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  titre TEXT NOT NULL,
  description TEXT,
  auteur_nom TEXT NOT NULL,
  statut TEXT DEFAULT 'ouvert',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE propositions DISABLE ROW LEVEL SECURITY;

-- Votes sur propositions
CREATE TABLE IF NOT EXISTS votes_prop (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  proposition_id UUID REFERENCES propositions(id) ON DELETE CASCADE,
  votant_key TEXT NOT NULL,
  votant_nom TEXT,
  poids NUMERIC,
  choix BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(proposition_id, votant_key)
);
ALTER TABLE votes_prop DISABLE ROW LEVEL SECURITY;
```

---

## Pour reprendre
Dis : **"Lis le CLAUDE.md et continue"**

## État du projet au 2026-06-11
- **18 pages** toutes fonctionnelles et dans la nav
- **Audit complet 2026-06-11** : bugs de correction + calculs + cas limites corrigés (voir table « Bugs corrigés »)
- **associes.html** : partie financière OK ; votes (`propositions`/`votes_prop`) OK si tables créées en Supabase (SQL dans ce fichier)
- **Serveur local** : `python -m http.server 5500` depuis `C:\Users\jeune\Monprojet` → http://localhost:5500
- ⚠ **Migration à exécuter** : **`MIGRATION_2026-06-11.sql`** (colonne `ecart_especes` + **recalcul rétroactif** des sessions passées + uniformisation `rapports.recettes`). Sans elle : repli auto sur `ecart`, comportement inchangé. Les sessions « rapport jour passé » (sans ventes tracées) ne sont volontairement pas recalculées.
- 🔐 **Sécurité** : voir `SECURITE.md` (base ouverte — à traiter côté Supabase, phase par phase)
- **Prochaines pistes** : déploiement sécurité (`SECURITE.md`), export PDF rapport, congés longue durée

### ✅ Résolu lors de l'audit 2026-06-11
- **Double-comptage salaires (bilan)** → comptés une fois au brut ; parts inchangées.
- **Écart OM déduit du salaire caissier** → seul l'écart espèces (`ecart_especes`) est déduit.
- **XSS stocké** → `escHtml()` partagé appliqué aux sinks d'escalade (caisse, dashboard, historique, associés, paramètres, rh…) ; `jsStr()` pour les `onclick` (noms à apostrophe).
- **N° de rapport en double / double soumission / valeurs négatives / course création session** → corrigés (table « Bugs corrigés »).

### ⚠ À traiter — décisions / déploiement requis
1. **SÉCURITÉ — base ouverte (`SECURITE.md`)** : RLS désactivé + clé anon publique. **Non corrigeable côté HTML** : RLS + login serveur (Edge Function) à déployer dans Supabase. Plan de bascule par phases prêt dans `SECURITE.md`. **Mesure immédiate : changer les PIN par défaut** (`1234` staff).
2. **Hash d'intégrité rapports** : décoratif (non-HMAC, jamais vérifié). À supprimer ou remplacer par un HMAC serveur une fois la sécurité de base en place.
3. **Blocage rapport si veille sans rapport** : un jour de fermeture légitime bloque le lendemain (contournement = « rapport jour passé »). Politique à décider (autoriser les trous ?).
4. **XSS résiduel (faible)** : quelques sinks en pages owner/manager only (finances, avances, salaires) non échappés — risque d'escalade faible (données saisies par managers). À finir pour l'exhaustivité.
