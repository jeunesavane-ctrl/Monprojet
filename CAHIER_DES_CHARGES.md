# Medellin Lounge — Cahier des charges v2.0
*Actualisé le 2026-06-12 — Refondation complète*

---

## 1. Présentation du projet

**Medellin Lounge** est une application web de gestion interne pour un lounge chicha et boissons basé à Conakry, Guinée.

Elle couvre :
- La saisie des ventes en temps réel par le personnel
- Le suivi de caisse journalier (espèces + Orange Money)
- La génération de rapports financiers
- La gestion des ressources humaines (présences, salaires, avances)
- Le suivi des parts et dividendes pour les associés
- La gestion des stocks (chicha, produits)

**Contraintes du contexte :**
- Personnel sur téléphone mobile (interface mobile-first)
- Pas de comptable — tout doit être simple, lisible, sans jargon
- Monnaie : Franc Guinéen (GNF), affichée avec `Intl.NumberFormat('fr-FR')`
- Connectivité variable — les écrans critiques doivent se charger vite

---

## 2. Stack technique

| Élément | Choix |
|---------|-------|
| Front | HTML5 / CSS3 / JavaScript vanilla (ES2020+) |
| Base de données | Supabase JS v2 via CDN (`supabase-js@2`) |
| Realtime | Supabase Realtime (Postgres changes) |
| Hébergement | Netlify Pro |
| Domaine | `https://medellin-lounge.com` |

**Aucun framework, aucun bundler.** Chaque page est un fichier HTML autonome qui charge `shared.css` et `shared.js`.

---

## 3. Déploiement

- **Dépôt :** `https://github.com/jeunesavane-ctrl/Monprojet.git` (branche `main`)
- **Auto-deploy : DÉSACTIVÉ** sur Netlify
- `git push origin main` = versioning uniquement, rien ne se met en ligne
- **Mise en ligne** = déploiement manuel depuis le dashboard Netlify, à la main, quand le propriétaire est satisfait
- Ne jamais dire "c'est en ligne" après un push

---

## 4. Credentials Supabase

- **URL :** `https://stpmokparkaybgkabbeo.supabase.co`
- **Anon Key :** `sb_publishable_3L6fyV-zEZMX-EZaNHBPPQ_Hnsmee0Z`
- **RLS :** DÉSACTIVÉ sur toutes les tables (sécurité à traiter en phase 2)

---

## 5. Acteurs — 3 catégories distinctes

### 5.1 Le Gestionnaire (owner)
- Une seule personne, propriétaire de l'établissement
- **N'est pas dans une table** — défini dans `config` :
  - `config.pin_owner` : hash SHA-256 de son PIN
  - `config.owner_nom` : son nom affiché
  - `config.owner_pct` : son % de distribution (ou auto si NULL)
- Accès total à toutes les pages

### 5.2 Les Associés
- Co-investisseurs du lounge, **pas des salariés**
- Pas de pointage, pas de salaire, pas d'avance sur salaire
- Stockés dans la table `associes` (voir §7)
- Chaque associé a son propre PIN personnel
- Accès en lecture aux pages financières

### 5.3 Les Employés
- Personnel salarié uniquement
- Stockés dans la table `employes` (voir §7)
- Rôles possibles : `manager`, `caissier`, `staff`, `chicha`, `achats`
- Chaque employé a son propre PIN individuel
- Soumis au pointage, aux avances, au calcul de paie

---

## 6. Rôles et accès — 7 rôles

| Rôle | Qui | Pages accessibles |
|------|-----|-------------------|
| `owner` | Gestionnaire | Toutes les pages (18) |
| `manager` | Manager salarié | Dashboard, Chicha, Achats, Caisse, Rapport, Pointage, Historique, RH, Avances, Charges, Finances, Bilan |
| `associe` | Co-investisseur | Dashboard, Caisse (lecture), Historique, Finances (Mes Parts), Bilan, Associés |
| `caissier` | Caissière | Caisse, Historique, Ma Fiche, Avance |
| `staff` | Serveuse | Saisie, Historique, Ma Fiche, Avance |
| `chicha` | Responsable chicha | Chicha, Historique, Ma Fiche, Avance |
| `achats` | Responsable achats | Achats, Historique, Ma Fiche, Avance |

---

## 7. Authentification — index.html

**Mécanisme :** PIN numérique, hashé en SHA-256 côté client avant comparaison.

**Flux de vérification (dans l'ordre) :**
1. Hash du PIN saisi
2. Comparaison avec `config.pin_owner` → rôle `owner`, extra = `{nom: config.owner_nom}`
3. Comparaison avec `config.pin_manager` → rôle `manager`, extra = `{nom: 'Manager'}`
4. Recherche dans `employes.pin_hash` → rôle = `employe.role`, extra = `{nom, employe_id}`
5. Recherche dans `associes.pin_hash` → rôle `associe`, extra = `{nom, associe_id, pourcentage}`
6. Si aucune correspondance → message d'erreur, pas de connexion

**Session (sessionStorage) :**
- `ml_role` : rôle de l'utilisateur connecté
- `ml_hashes` : `{hOwner, hManager, hStaff}` (pour vérifications internes)
- `ml_extra` : données spécifiques à l'utilisateur (nom, id, pourcentage…)

**Auto-verrouillage :** 10 minutes d'inactivité → retour à `index.html`

---

## 8. Navigation — 18 pages

```javascript
{ href:'dashboard.html',  roles:['manager','owner','associe'] }
{ href:'saisie.html',     roles:['staff'] }
{ href:'chicha.html',     roles:['chicha','manager','owner'] }
{ href:'achats.html',     roles:['achats','manager','owner'] }
{ href:'caisse.html',     roles:['caissier','manager','owner','associe'] }
{ href:'rapport.html',    roles:['manager','owner'] }
{ href:'pointage.html',   roles:['manager','owner'] }
{ href:'historique.html', roles:['staff','caissier','chicha','achats','manager','owner','associe'] }
{ href:'fiche.html',      roles:['staff','caissier','chicha','achats'] }
{ href:'avance.html',     roles:['staff','caissier','chicha','achats'] }
{ href:'produits.html',   roles:['manager','owner'] }
{ href:'rh.html',         roles:['manager','owner'] }
{ href:'avances.html',    roles:['manager','owner'] }
{ href:'charges.html',    roles:['manager','owner'] }
{ href:'finances.html',   roles:['owner','manager','associe'] }
{ href:'bilan.html',      roles:['owner','manager','associe'] }
{ href:'associes.html',   roles:['owner','associe'] }
{ href:'parametres.html', roles:['owner'] }
```

**Badges de notification (points rouges sur la nav) :**
- `nbadge-caisse` → `remboursements_ecart` en statut `en_attente`
- `nbadge-avances` → `avances` en statut `en_attente` (manager/owner uniquement)

---

## 9. Base de données — 22 tables

Le fichier `SCHEMA.sql` contient toutes les instructions SQL complètes.

### Vue d'ensemble

| # | Table | Description |
|---|-------|-------------|
| 1 | `config` | Paramètres globaux (PINs owner/manager/staff, part_lounge, objectif…) |
| 2 | `associes` | Co-investisseurs (nom, pourcentage, pin_hash) |
| 3 | `employes` | Salariés (manager/caissier/staff/chicha/achats) |
| 4 | `logs` | Audit trail connexions et actions |
| 5 | `produits` | Catalogue produits (chicha, boissons, autres) |
| 6 | `tables_lounge` | Tables physiques du lounge (T1–T8, Bar, Terrasse) |
| 7 | `sessions_caisse` | Session journalière (une par jour) |
| 8 | `ventes_session` | Ventes saisies par les serveuses |
| 9 | `verifications_staff` | Ce que la caissière déclare avoir reçu par serveuse |
| 10 | `mouvements_caisse` | Entrées/sorties manuelles dans la session |
| 11 | `achats_session` | Achats/dépenses du jour |
| 12 | `sorties_chicha` | Sorties stock chicha (inventaire uniquement) |
| 13 | `rapports` | Rapports journaliers créés par le manager |
| 14 | `presences` | Pointage journalier des employés |
| 15 | `justifications` | Justificatifs d'absence/retard |
| 16 | `avances` | Avances sur salaire |
| 17 | `salaires_verses` | Paiements de salaires mensuels |
| 18 | `charges` | Charges fixes mensuelles |
| 19 | `remboursements_ecart` | Remboursements d'écarts caisse |
| 20 | `credits` | Consommations à crédit d'employés |
| 21 | `propositions` | Propositions soumises au vote des associés |
| 22 | `votes_prop` | Votes sur les propositions |

### Colonnes importantes à retenir

| Table | Colonne | Remarque |
|-------|---------|----------|
| `produits` | `prix_defaut` | Pas `prix` |
| `produits` | `stock_min` | Pas `seuil_bas` |
| `produits` | `actif` | Filtre : `.not('actif','is',false)` — jamais `.eq('actif',true)` |
| `charges` | `label` | Pas `libelle` |
| `sessions_caisse` | `ecart_especes` | Écart espèces caissière seul |
| `sessions_caisse` | `ecart_om` | Écart OM caissière seul |
| `sessions_caisse` | `ecart` | Total = ecart_especes + ecart_om |
| `ventes_session` | `table_label` | TEXT libre : 'T1', 'T3+T4', 'Bar', null |

---

## 10. Flux opérationnel quotidien

```
MATIN
  └─ Manager/Caissière saisit le fond de caisse → session créée (statut: ouvert)

JOURNÉE
  ├─ Serveuses → saisie.html  (plusieurs tours possibles)
  │    └─ Sélection table(s) → saisie des ventes (produit, qty, paiement)
  │         → INSERT ventes_session
  │
  ├─ Chicha → chicha.html
  │    └─ Sorties chicha (inventaire) → INSERT sorties_chicha
  │
  └─ Achats → achats.html
       └─ Dépenses du jour → INSERT achats_session

SOIR — CLÔTURE (caissière)
  └─ caisse.html
       ├─ Pour chaque serveuse :
       │    → saisit recu_especes + recu_om → INSERT verifications_staff
       │    → l'app affiche l'écart serveuse (déclaré − reçu)
       ├─ Compte le tiroir → total_reel
       ├─ Vérifie le compte OM → total_om_verifie
       ├─ L'app calcule et stocke ecart_especes + ecart_om + ecart
       └─ Clôture → statut: valide_caissier

SOIR — VALIDATION (manager)
  └─ dashboard.html ou rapport.html
       ├─ Vérifie les chiffres
       ├─ Saisit manuellement chicha_rows + boissons_rows
       │    (achats_rows préremplis depuis achats_session)
       ├─ Génère le rapport → INSERT rapports
       └─ Statut session: valide_manager
```

---

## 11. Modèle des écarts caisse

### Qui reçoit l'argent ?
La **caissière** reçoit physiquement tout l'argent :
- Les **espèces** : chaque serveuse lui remet son cash en fin de service
- L'**Orange Money** : les clients paient sur le compte OM du lounge, qu'elle contrôle

### Écart par serveuse
Calculé en JS à partir de `ventes_session` et `verifications_staff` :

```
déclaré_esp = SUM(ventes_session.total WHERE paiement='especes' AND employe_id=X)
déclaré_om  = SUM(ventes_session.total WHERE paiement='om'      AND employe_id=X)
recu_esp    = verifications_staff.recu_especes (saisi par la caissière)
recu_om     = verifications_staff.recu_om      (saisi par la caissière)

écart_serveuse = (déclaré_esp + déclaré_om) − (recu_esp + recu_om)
```
- **Positif** → la serveuse doit rembourser (dette déduite de son salaire)
- **Négatif** → excédent (rare)

### Écart caissière espèces
```
théoriqueEsp  = fond_caisse + SUM(recu_especes) + entrées − sorties − achats
ecart_especes = théoriqueEsp − total_reel
```

### Écart caissière OM
```
théoriqueOM = SUM(recu_om) — total qu'elle déclare avoir reçu
ecart_om    = théoriqueOM − total_om_verifie
```

### Écart total caissière
```
ecart = ecart_especes + ecart_om
```
- **Positif** → manque d'argent (déduit de son salaire)
- **Négatif** → excédent/surplus (bonus sur salaire)

### Règle fondamentale
Chaque personne porte **uniquement son propre écart** :
- Serveuse X : si elle a déclaré plus qu'elle n'a remis → **c'est son problème**
- Caissière : si son tiroir ne correspond pas à ce qu'elle a déclaré recevoir → **c'est son problème**
- Les deux niveaux sont **indépendants**

---

## 12. Tables physiques — saisie.html

- La serveuse sélectionne sa/ses table(s) en **début de chaque tour** de saisie
- La sélection est affichée sous forme de grille (depuis `tables_lounge`)
- Elle peut sélectionner **plusieurs tables** d'un coup (tables groupées)
- Le `table_label` est construit côté client : numéros triés + concaténés
  - Exemple : sélection T4 + T3 → label stocké = `"T3+T4"` (toujours trié)
- C'est une **information opérationnelle** — aide les serveuses à retrouver leurs ventes en cas de mélange de rapports
- **Ne change pas** la logique de caisse ou de paiement

---

## 13. Formules de calcul

### Rapport journalier
```
recettes = total_chicha + total_boissons
net      = recettes − total_achats
```

### Distribution des parts
```
net_for_parts = SUM(rapports.net) − SUM(charges.montant) sur la période
distribPct    = MAX(0, 100 − part_lounge) / 100
owner_pct     = config.owner_pct  OU  MAX(0, 100 − SUM(associes.pourcentage))

part_lounge  = net_for_parts × (part_lounge / 100)
part_owner   = MAX(0, net_for_parts) × distribPct × owner_pct / 100
part_assoc_X = MAX(0, net_for_parts) × distribPct × assocX.pourcentage / 100
```

### Trésorerie
```
tresorerie = net_for_parts − SUM(avances WHERE statut IN ('en_attente','approuvee') AND rembourse=false)
```

### Calcul de salaire net
```
absNJ       = absences − justifications_approuvees (ce mois)
sanc_abs    = salaire_base × (0 si 0 absNJ | 0.10 si 2 | 0.15 si ≥3)
sanc_ret    = salaire_base × 0.10  si retards ≥ 5 ce mois

avances_ded = SUM(avances.montant WHERE statut='approuvee' AND rembourse=false)

ecarts_ded  = [pour serveuse]   SUM(écart verifications_staff ce mois) non remboursé
              [pour caissière]  SUM(ecart sessions_caisse ce mois)      non remboursé
              − SUM(remboursements_ecart.montant WHERE statut='valide' ce mois)

surplus     = MAX(0, SUM(−ecart sessions_caisse)) — excédents caissière ce mois

net_verse   = MAX(0, salaire_base − sanc_abs − sanc_ret − avances_ded − ecarts_ded + surplus)
```

---

## 14. Description des pages

### Pages opérationnelles (quotidien)

**`saisie.html`** — rôle `staff`
- Sélection de la/des tables au début de chaque tour
- Catalogue de produits filtré (type boisson, ou tous selon config)
- Saisie qty + mode de paiement (espèces / OM)
- Multi-tour : plusieurs saisies possibles dans la même journée
- Verrouillage automatique si la session passe en `valide_caissier`
- Realtime : écoute `sessions_caisse` — verrouillage instantané si la caissière clôture

**`chicha.html`** — rôles `chicha`, `manager`, `owner`
- Saisie des sorties chicha (arôme, quantité)
- Suivi stock uniquement — pas utilisé dans les calculs financiers

**`achats.html`** — rôles `achats`, `manager`, `owner`
- Saisie des achats/dépenses de la journée
- Catégorie + produit + montant + quantité
- Prérempli dans rapport.html

**`caisse.html`** — rôles `caissier`, `manager`, `owner`, `associe`
- Vue en temps réel des ventes de la session par serveuse
- Pour chaque serveuse : saisie de `recu_especes` + `recu_om` → affichage de son écart
- Mouvements manuels (entrées/sorties)
- Fond de caisse, total théorique, comptage physique
- Vérification OM sur compte téléphone
- Calcul et stockage des 3 colonnes d'écart
- Clôture → statut `valide_caissier`
- Remboursements d'écart (serveuses + caissière)

**`rapport.html`** — rôles `manager`, `owner`
- Saisie manuelle des lignes chicha + boissons (totaux par produit)
- Achats préremplis depuis `achats_session`
- Calcul automatique recettes / net
- Numéro séquentiel auto (MAX + 1)
- Blocage si un rapport existe déjà pour la date

### Pages de gestion

**`dashboard.html`** — rôles `manager`, `owner`, `associe`
- KPIs du mois en cours : recettes, net, objectif
- Graphique d'évolution 30 jours
- Alertes sessions en attente de validation
- Validation manager : ouvre la session → vérifie écarts → génère rapport

**`pointage.html`** — rôles `manager`, `owner`
- Sélecteur de date
- Statut par employé : présent / absent / retard / congé
- Bouton "Tous présents"

**`rh.html`** — rôles `manager`, `owner`
- 5 onglets : Équipe / Présences / Demandes / Avances / Paie
- Paie : calcul automatique de toutes les déductions, VERSER par employé
- VERSER → INSERT `salaires_verses` + UPDATE `avances.rembourse=true`
- ANNULER → DELETE `salaires_verses`

**`avances.html`** — rôles `manager`, `owner`
- Vue globale des avances en attente + approuvées

**`charges.html`** — rôles `manager`, `owner`
- Charges fixes mensuelles (loyer, électricité, abonnements…)
- Ajout, marquage payé/non payé

**`produits.html`** — rôles `manager`, `owner`
- Catalogue produits : chicha / boissons / autres
- Ajout, modification, désactivation
- Alertes stock bas (stock_actuel < stock_min)

**`parametres.html`** — rôle `owner`
- Gestion des PINs (owner, manager, staff)
- Ajout/modification d'employés et d'associés
- Part lounge (%) et part gestionnaire (%)
- Objectif journalier

### Pages personnelles

**`fiche.html`** — rôles `staff`, `caissier`, `chicha`, `achats`
- Solde salaire estimé du mois en cours
- Détail des déductions (absences, retards, écarts, avances)
- Historique des salaires versés
- Historique des écarts caisse (serveuse ou caissière selon rôle)

**`avance.html`** — rôles `staff`, `caissier`, `chicha`, `achats`
- Demande d'avance sur salaire
- Blocage si une demande est déjà en attente

**`historique.html`** — tous les rôles
- Liste des rapports avec filtres (date, mois)
- Détail par rapport
- Suppression rapport (owner uniquement) avec réouverture de session

### Pages financières

**`finances.html`** — rôles `owner`, `manager`, `associe`
- Owner/Manager : 5 onglets (Bilan, Dividendes, Trésorerie, Charges, Évolution)
- Associé : onglet "Mes Parts" uniquement (parts personnelles sur 6 mois)

**`bilan.html`** — rôles `owner`, `manager`, `associe`
- KPIs : Recettes / Achats / Marge / Charges / Résultat net
- Répartition : Lounge + Gestionnaire + Associés
- Sélecteur de période (mois)

**`associes.html`** — rôles `owner`, `associe`
- Parts par associé sur 3/6/12 mois
- Propositions : soumettre, voter
- Votes pondérés par pourcentage

---

## 15. Règles techniques transversales

### Sécurité XSS
- Toute donnée saisie par un utilisateur injectée via `innerHTML` → `escHtml(valeur)`
- Toute donnée dans un attribut `onclick="fn('…')"` → `jsStr(valeur)`
- Les deux fonctions sont dans `shared.js`

### Création de session
- `saisie.html` et `caisse.html` créent la session du jour si elle n'existe pas
- Création atomique : si l'INSERT échoue (doublon), re-SELECT de la session existante
- Évite les erreurs de clé dupliquée quand deux rôles ouvrent en même temps

### Numérotation des rapports
- `num` = MAX(num) de la table `rapports` + 1 (calcul numérique, pas tri alphabétique)
- Évite les doublons et les numéros incorrects

### Suppression de rapport (owner)
- Rapport du jour → session rouverte (`statut='ouvert'`) : tout le cycle reprend
- Rapport d'un jour passé → session passe en `valide_caissier` (revalidation depuis dashboard)

### Realtime Supabase
- `saisie.html` écoute `sessions_caisse` → verrouillage si session clôturée
- `caisse.html` écoute `ventes_session` → mise à jour en temps réel des cartes serveuses
- `dashboard.html` écoute `sessions_caisse` → badge si nouvelle session à valider

---

## 16. shared.js — fonctions disponibles

| Fonction | Usage |
|----------|-------|
| `ML.getRole()` | Rôle de l'utilisateur connecté |
| `ML.getExtra()` | Données utilisateur (nom, id, pourcentage…) |
| `ML.guard(roles[])` | Redirige si rôle non autorisé |
| `ML.lock()` | Déconnexion + retour index.html |
| `ML.logAction(desc)` | Ajoute une ligne dans `logs` |
| `initPage(roles[])` | Guard + nav + auto-lock + badges |
| `renderNav()` | Génère la navigation filtrée par rôle |
| `loadNavBadges()` | Charge les points rouges de notification |
| `gnf(n)` | Formate un nombre en GNF |
| `frDate(d)` | Date longue en français |
| `frDateShort(d)` | Date courte |
| `frMonth(d)` | Mois + année |
| `todayISO()` | Date du jour `YYYY-MM-DD` |
| `sha256(str)` | Hash SHA-256 (async) |
| `escHtml(s)` | Échappe HTML (anti-XSS innerHTML) |
| `jsStr(s)` | Échappe JS-attribut (anti-XSS onclick) |
| `toast(msg, type)` | Notification toast (ok / ko) |
| `$(id)` | Raccourci `document.getElementById` |
| `HEADER_HTML` | HTML du header + nav (à injecter dans chaque page) |

---

## 17. Design

| Élément | Valeur |
|---------|--------|
| Fond | `#0D0D0D` (noir profond) |
| Accent | `#C9A84C` (or) |
| Titre | **Bebas Neue** |
| Corps | **DM Sans** |
| Approche | Mobile-first (staff = téléphone) |
| Fichiers base | `shared.css` + `shared.js` (inclus dans toutes les pages) |

---

## 18. Ce qui N'existe pas / N'est plus

- `salaires.html` → supprimé (logique intégrée dans `rh.html`)
- Table `associes` dans l'ancien système → remplacée par table `employes` avec role='associe' → **abandon de cette approche** : table `associes` propre depuis la v2
- `prix` sur produits → renommé `prix_defaut`
- `seuil_bas` sur produits → renommé `stock_min`
- `libelle` sur charges → s'appelle `label`
- Zone "reset en masse" de parametres.html → supprimée
- Suppression de rapports en masse → rapport par rapport depuis historique.html

---

## 19. Ordre de développement recommandé

1. `SCHEMA.sql` → exécuter dans Supabase ✅
2. `shared.js` + `shared.css` → fondations communes
3. `index.html` → authentification complète (owner + manager + employes + associes)
4. `saisie.html` → première page opérationnelle
5. `caisse.html` → clôture + vérifications staff
6. `rapport.html` → génération rapport
7. `dashboard.html` → KPIs + validation manager
8. `parametres.html` → configuration (pour créer les comptes)
9. `rh.html` → équipe + paie
10. `produits.html` → catalogue
11. `pointage.html` → présences
12. `avances.html` → gestion avances
13. `charges.html` → charges fixes
14. `finances.html` → bilan financier
15. `bilan.html` → bilan mensuel
16. `associes.html` → parts + votes
17. `historique.html` → rapports archivés
18. `fiche.html` + `avance.html` + `chicha.html` + `achats.html` → pages personnelles

---

*Ce document remplace le CLAUDE.md v10 comme référence fonctionnelle principale.*
*Le SCHEMA.sql est la référence technique de la base de données.*
