# Medellin Lounge — CLAUDE.md v11.0
*Référence complète de développement — 2026-06-12*

---

## STACK & DÉPLOIEMENT

```
HTML/CSS/JS vanilla · Supabase JS v2 CDN · Netlify Pro
git push = versioning seulement — JAMAIS dire "c'est en ligne" après un push
Déploiement = manuel depuis le dashboard Netlify
Serveur local : python -m http.server 5500 → http://localhost:5500
```

**Supabase**
```
URL : https://stpmokparkaybgkabbeo.supabase.co
Key : sb_publishable_3L6fyV-zEZMX-EZaNHBPPQ_Hnsmee0Z
RLS : ACTIVÉ sur les 22 tables (politique authenticated_only — Phase 2)
Edge Function : login (PIN vérifié côté serveur — Phase 1)
```

---

## ACTEURS — 3 CATÉGORIES

| Catégorie | Stocké dans | Rôle |
|-----------|-------------|------|
| Gestionnaire | `config` (pin_owner, owner_nom, owner_pct) | `owner` |
| Associés | table `associes` — co-investisseurs, **PAS des salariés** | `associe` |
| Employés | table `employes` — salariés uniquement | `manager` `caissier` `staff` `chicha` `achats` |

---

## AUTH — index.html (ordre strict)

```
1. sha256(PIN) === config.pin_owner   → role='owner',   extra={nom:config.owner_nom}
2. sha256(PIN) === config.pin_manager → role='manager',  extra={nom:'Manager'}
3. sha256(PIN) === employes.pin_hash  → role=employe.role, extra={nom, employe_id}
4. sha256(PIN) === associes.pin_hash  → role='associe',  extra={nom, associe_id, pourcentage}
5. aucune correspondance              → erreur, pas de connexion
```

**sessionStorage :** `ml_role` · `ml_extra`
**Auto-lock :** 10 min d'inactivité → `ML.lock()`

**Config keys :**
`pin_owner` · `pin_manager` · `owner_nom` · `owner_pct` · `part_lounge` (défaut 10) · `objectif_journalier` · `note_manager`
`pin_staff` existe dans config mais **n'est pas utilisé dans le flux auth** (nouveau système = PINs individuels uniquement)

---

## NAVIGATION — 18 PAGES

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

**Badges nav :**
- `nbadge-caisse`  → `remboursements_ecart` en `en_attente`
- `nbadge-avances` → `avances` en `en_attente` (manager/owner uniquement)

---

## TABLES — 22

| Table | Colonnes importantes |
|-------|---------------------|
| `config` | key, value |
| `associes` | id, nom, prenom, pourcentage, pin_hash, actif |
| `employes` | id, nom, prenom, poste, role, salaire_base, pin_hash, actif |
| `logs` | id, role, action, timestamp |
| `produits` | id, nom, type, stock_actuel, **stock_min**, **prix_defaut**, prix_achat, unite_vente, packaging_label, unite_par_packaging, actif |
| `tables_lounge` | id, label (T1…T8/Bar/Terrasse), ordre, actif |
| `sessions_caisse` | id, date UNIQUE, statut, fond_caisse, total_reel, total_om_verifie, **ecart_especes**, **ecart_om**, **ecart**, caissier_id, note_caissier, note_manager |
| `ventes_session` | id, session_id, employe_id, produit_id, produit_nom, qty, prix_unitaire, total, paiement, **table_label** |
| `verifications_staff` | id, session_id, employe_id, **recu_especes**, **recu_om** — UNIQUE(session_id, employe_id) |
| `mouvements_caisse` | id, session_id, type (entree/sortie), motif, montant, note |
| `achats_session` | id, session_id, categorie, produit_nom, montant, qty, prix_unitaire |
| `sorties_chicha` | id, session_id, employe_id, arome, qty, valide |
| `rapports` | id, date, num, session_id, total_chicha, total_boissons, total_achats, recettes, net, manager (TEXT), caissier (TEXT), part (JSONB), chicha_rows (JSONB), boissons_rows (JSONB), achats_rows (JSONB) |
| `presences` | id, employe_id, date, statut, note — UNIQUE(employe_id, date) |
| `justifications` | id, employe_id, date, type, motif, statut |
| `avances` | id, employe_id, montant, date, statut, rembourse, obs, note_demande |
| `salaires_verses` | id, employe_id, mois, salaire_brut, avances_deduites, ecarts_deduits, surplus_caisse, net_verse, nb_absences_nj, sanction_type, sanction_montant, nb_retards, sanction_retard_montant, paye_le — UNIQUE(employe_id, mois) |
| `charges` | id, **label**, montant, mois, categorie, paye, date_paiement, recurrence |
| `remboursements_ecart` | id, session_id, employe_id, montant, note, statut |
| `credits` | id, employe_id, session_id, montant, rembourse |
| `propositions` | id, titre, description, auteur_nom, statut (ouvert/ferme) |
| `votes_prop` | id, proposition_id, votant_key (associe.id::text ou 'owner'), votant_nom, poids, choix (bool) — UNIQUE(proposition_id, votant_key) |

**Statuts sessions_caisse :** `ouvert` → `valide_caissier` → `valide_manager`
**Statuts avances :** `en_attente` → `approuvee` / `rejetee`
**Statuts remboursements_ecart :** `en_attente` → `valide` / `rejete`
**Statuts presences :** `present` / `absent` / `retard` / `conge`
**Statuts justifications :** `en_attente` / `approuvee` / `rejetee`
**Types produits :** `chicha` / `boisson` / `autre`

---

## FLUX OPÉRATIONNEL QUOTIDIEN

```
MATIN
  └─ manager ou caissière saisit le fond → session créée (statut: ouvert)

JOURNÉE
  ├─ saisie.html  (staff)   → plusieurs tours : table(s) → produits → paiement
  │                           INSERT ventes_session
  ├─ chicha.html  (chicha)  → sorties chicha → INSERT sorties_chicha (stock UNIQUEMENT)
  └─ achats.html  (achats)  → dépenses → INSERT achats_session

SOIR — CLÔTURE (caissière)
  └─ caisse.html
       ├─ Saisit recu_especes + recu_om pour chaque serveuse → INSERT verifications_staff
       ├─ L'app affiche l'écart par serveuse (déclaré − reçu)
       ├─ Compte le tiroir → total_reel
       ├─ Vérifie OM sur téléphone → total_om_verifie
       ├─ L'app calcule ecart_especes + ecart_om + ecart → stockés dans sessions_caisse
       └─ Clôture → statut: valide_caissier

SOIR — VALIDATION (manager)
  └─ rapport.html  (ou dashboard.html → openValidation)
       ├─ Saisit manuellement lignes chicha + boissons
       ├─ Achats préremplis depuis achats_session
       ├─ INSERT rapports
       └─ statut session: valide_manager
```

---

## MODÈLE DES ÉCARTS CAISSE

La caissière reçoit **tout** l'argent (espèces + OM du lounge).

**Écart serveuse** — calculé en JS, jamais stocké dans une colonne propre
```
décl_esp = SUM(ventes_session.total WHERE paiement='especes' AND employe_id=X AND session_id=Y)
décl_om  = SUM(ventes_session.total WHERE paiement='om'      AND employe_id=X AND session_id=Y)
recu_esp = verifications_staff.recu_especes WHERE employe_id=X AND session_id=Y
recu_om  = verifications_staff.recu_om      WHERE employe_id=X AND session_id=Y
écart    = (décl_esp + décl_om) − (recu_esp + recu_om)
→ positif = dette serveuse / négatif = excédent
```

**Écart caissière** — calculé à la clôture, stocké dans sessions_caisse
```
tot_recu_esp  = SUM(verifications_staff.recu_especes) pour la session
tot_recu_om   = SUM(verifications_staff.recu_om)      pour la session
entrées       = SUM(mouvements_caisse.montant WHERE type='entree')
sorties       = SUM(mouvements_caisse.montant WHERE type='sortie')
achats        = SUM(achats_session.montant)

théoriqueEsp  = fond_caisse + tot_recu_esp + entrées − sorties − achats
ecart_especes = théoriqueEsp − total_reel          → sessions_caisse.ecart_especes
ecart_om      = tot_recu_om  − total_om_verifie    → sessions_caisse.ecart_om
ecart         = ecart_especes + ecart_om            → sessions_caisse.ecart
```
`+` = manque (déduit du salaire) · `−` = surplus (bonus salaire)

---

## FORMULES DE CALCUL

```
recettes      = total_chicha + total_boissons
net           = recettes − total_achats
net_for_parts = Σ rapports.net − Σ charges.montant  (sur la période)
tresorerie    = net_for_parts − Σ avances(statut IN [en_attente,approuvee] AND rembourse=false)

part_lounge   = net_for_parts × part_lounge% / 100
distribPct    = (100 − part_lounge%) / 100
owner_pct     = config.owner_pct  OU  MAX(0, 100 − Σ associes.pourcentage)
part_owner    = MAX(0, net_for_parts) × distribPct × owner_pct / 100
part_assoc_X  = MAX(0, net_for_parts) × distribPct × assocX.pourcentage / 100

surplus_caiss = MAX(0, −sessions_caisse.ecart)  ce mois (excédent = bonus caissière)
écart_serv    = (décl_esp + décl_om) − (recu_esp + recu_om)  par serveuse ce mois
ecarts_ded    = Σ écarts positifs non remboursés ce mois
                  [serveuse]  → depuis verifications_staff
                  [caissière] → depuis sessions_caisse.ecart
                − Σ remboursements_ecart(statut='valide') ce mois

absNJ         = presences(statut='absent') − justifications(statut='approuvee')  ce mois
sanc_abs      = brut × (0 si absNJ=0 | 0.10 si absNJ=2 | 0.15 si absNJ≥3)
sanc_ret      = brut × 0.10  si retards ≥ 5 ce mois
avances_ded   = Σ avances(statut='approuvee' AND rembourse=false) — TOUTES DATES

net_verse = MAX(0, brut − sanc_abs − sanc_ret − avances_ded − ecarts_ded + surplus_caiss)
```

---

## SHARED.JS — FONCTIONS DISPONIBLES

```javascript
ML.getRole()           // rôle connecté (string)
ML.getExtra()          // {nom, employe_id|associe_id, pourcentage}
ML.guard(roles[])      // redirige vers index.html si rôle non autorisé
ML.lock()              // déconnecte + index.html
ML.logAction(desc)     // INSERT dans logs
ML.initAutoLock()      // démarre le timer 10 min
initPage(roles[])      // guard + renderNav + initAutoLock + loadNavBadges
renderNav()            // génère la nav filtrée par rôle
loadNavBadges()        // charge les points rouges
gnf(n)                 // "1 234 567 GNF"
frDate(d)              // "lundi 12 juin 2026"
frDateShort(d)         // "12 juin"
frMonth(d)             // "juin 2026"
todayISO()             // "2026-06-12"
sha256(str)            // async → hash hex
escHtml(s)             // échappe HTML (anti-XSS innerHTML)
jsStr(s)               // échappe JS-attribut (anti-XSS onclick)
toast(msg, type)       // type = '' | 'ok' | 'ko'
$(id)                  // document.getElementById(id)
HEADER_HTML            // <header> + <nav> à injecter dans chaque page
db                     // instance Supabase (supabase.createClient)
```

---

## STRUCTURE STANDARD D'UNE PAGE

```html
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NomPage — Medellin Lounge</title>
  <link rel="stylesheet" href="shared.css">
</head>
<body>
  <div id="toast"></div>

  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
  <script src="shared.js"></script>
  <script>
    // 1. Injecter le header
    document.body.insertAdjacentHTML('afterbegin', HEADER_HTML);

    // 2. Guard + nav + badges
    if (!initPage(['role1','role2'])) throw new Error();

    // 3. Logique de la page
    async function init() { ... }
    init();
  </script>
</body>
</html>
```

---

## PATTERNS SUPABASE COURANTS

**SELECT simple**
```javascript
const { data, error } = await db.from('table').select('*').eq('col', val);
```

**SELECT avec filtre actifs produits** ← toujours cette forme
```javascript
.not('actif', 'is', false)   // ✓ couvre false ET null
.eq('actif', true)           // ✗ exclut les NULL → NE PAS UTILISER
```

**INSERT avec gestion doublon (création session)**
```javascript
let { data, error } = await db.from('sessions_caisse').insert({date: todayISO()}).select().single();
if (error?.code === '23505') {                          // clé dupliquée
  ({ data } = await db.from('sessions_caisse').select().eq('date', todayISO()).single());
}
```

**UPSERT verifications_staff**
```javascript
await db.from('verifications_staff').upsert(
  { session_id, employe_id, recu_especes, recu_om },
  { onConflict: 'session_id,employe_id' }
);
```

**Numéro de rapport (MAX+1)**
```javascript
const { data } = await db.from('rapports').select('num').order('num', {ascending:false}).limit(1);
const nextNum = (data?.[0]?.num ?? 0) + 1;
```

**Realtime — écouter une table**
```javascript
const sub = db.channel('nom').on('postgres_changes',
  { event: '*', schema: 'public', table: 'sessions_caisse' },
  payload => { /* handler */ }
).subscribe();
// Nettoyer : db.removeChannel(sub)
```

---

## DIRECTIVES DE CODE — À RESPECTER ABSOLUMENT

### Sécurité
```
✓ Toute donnée → innerHTML  : escHtml(valeur)
✓ Toute donnée → onclick="fn('...')" : jsStr(valeur)
✗ Ne JAMAIS injecter une variable directement dans innerHTML ou onclick
```

### Base de données
```
✓ charges → colonne 'label'         (pas 'libelle')
✓ produits → 'prix_defaut'          (pas 'prix')
✓ produits → 'stock_min'            (pas 'seuil_bas')
✓ filtre actifs → .not('actif','is',false)
✓ numéro rapport → MAX(num)+1 numérique
✓ création session → saisie.html ET caisse.html ; INSERT puis re-SELECT si doublon (code 23505)
✗ Ne JAMAIS utiliser .eq('actif', true) pour filtrer les produits
```

### Logique métier
```
✓ avances_ded = statut='approuvee' AND rembourse=false — TOUTES DATES (pas ce mois)
✓ ecart caissière → NE PAS recalculer dans openValidation → utiliser sessInfo.ecart
✓ rapport.html → bloquer si un rapport existe déjà pour cette date
✓ avance.html  → bloquer si une demande en_attente existe déjà
✓ saisie.html  → multi-tour (plusieurs saisies/jour) ; verrouiller si session ≥ valide_caissier
✓ table_label  → trier les numéros avant concaténation : ["T4","T3"] → "T3+T4"
✓ rh.html VERSER   → INSERT salaires_verses + UPDATE avances SET rembourse=true
✓ rh.html ANNULER  → DELETE salaires_verses (avances conservent rembourse=true)
✓ associe caisse.html → lecture seule, pas de clôture possible
✓ finances.html associe → onglet "Mes Parts" uniquement
✓ sorties_chicha → stock uniquement, jamais dans les calculs financiers
```

### Suppression de rapport (owner, historique.html)
```
rapport du jour  → UPDATE sessions_caisse SET statut='ouvert'
rapport passé    → UPDATE sessions_caisse SET statut='valide_caissier'
```

### Pages à onglets — structure obligatoire

**rh.html** — 5 onglets :
```
Équipe     → liste du staff actif
Présences  → sélecteur date, 4 statuts, bouton "Tous présents"
Demandes   → avances + justifications en_attente → Approuver / Rejeter
Avances    → manager ajoute avance → statut=approuvee directement
Paie       → mois sélectionnable, VERSER par employé (toutes déductions auto)
```

**finances.html** — owner/manager voient 5 onglets, associé voit 1 seul :
```
Bilan       → net_final = rapports.net − charges  (owner + manager)
Dividendes  → répartition complète                (owner uniquement)
Trésorerie  → net_final − avances non remboursées (owner + manager)
Charges     → liste par mois                      (owner + manager)
Évolution   → graphique 6–18 mois                 (owner + manager)
Mes Parts   → part perso 6 mois                   (associe UNIQUEMENT)
```

**bilan.html** — distinction formules :
```
resultatNet (KPI)  = marge − charges − salaires   ← vue comptable affichée
parts calculées sur (marge − charges) uniquement  ← cohérent avec finances.html
```

### Realtime
```
saisie.html    → écoute sessions_caisse → verrouiller si valide_caissier|valide_manager
caisse.html    → écoute ventes_session  → rafraîchir cartes serveuses
dashboard.html → écoute sessions_caisse → alerter si nouvelle session à valider
```

---

## DESIGN

```
Fond    : #0D0D0D
Accent  : #C9A84C (or)
Titres  : Bebas Neue
Corps   : DM Sans
Approche: mobile-first (staff = téléphone)
Fichiers: shared.css + shared.js dans toutes les pages
```

---

## ORDRE DE DÉVELOPPEMENT

| Étape | Fichier(s) | Statut |
|-------|-----------|--------|
| 1 | `SCHEMA.sql` → exécuté dans Supabase | ✅ |
| 2 | `shared.js` + `shared.css` | ✅ |
| 3 | `index.html` | ✅ Sécurité Phase 1+2 (Edge Function + sessions anonymes) |
| 4 | `saisie.html` | ✅ tables_lounge · produit_id · paiement · multi-tour |
| 5 | `caisse.html` | ✅ verifications_staff · ecart_especes/om · clôture |
| 6 | `rapport.html` | ✅ table associes · recettes |
| 7 | `dashboard.html` | ✅ table associes · écarts stockés · openValidation |
| 8 | `parametres.html` | ✅ table associes · tables_lounge CRUD |
| 9 | `rh.html` | ✅ ecart_especes ?? ecart · label (pas libelle) |
| 10 | `produits.html` · `pointage.html` · `avances.html` · `charges.html` | ✅ |
| 11 | `finances.html` · `bilan.html` · `associes.html` | ✅ table associes |
| 12 | `historique.html` · `fiche.html` · `avance.html` · `chicha.html` · `achats.html` | ✅ |

## SÉCURITÉ — ÉTAT AU 2026-06-13

| Phase | Statut | Description |
|-------|--------|-------------|
| Phase 1 | ✅ Déployée | Edge Function `login` — PIN vérifié server-side, hash jamais envoyé au client |
| Phase 2 | ✅ Déployée | RLS activé sur 22 tables · `signInAnonymously()` au login · `signOut()` au lock |
| Phase 3 | ⬜ Optionnel | Politiques RLS par rôle (staff ne lit que ses ventes, etc.) |
