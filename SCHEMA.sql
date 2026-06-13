-- ════════════════════════════════════════════════════════════════════
-- MEDELLIN LOUNGE — SCHEMA.sql v1.1
-- Refondation complète — 2026-06-12
--
-- À coller dans Supabase → SQL Editor → Run.
-- ⚠  DÉTRUIT toutes les données existantes.
-- Idempotent : peut être relancé sans risque.
--
-- STRUCTURE DES ACTEURS
-- ──────────────────────
--   owner    → config (pin_owner, owner_nom, owner_pct) — unique, pas de table
--   associes → table associes (co-investisseurs, aucun lien avec la paie)
--   employes → table employes (salariés : manager/caissier/staff/chicha/achats)
--
-- MODÈLE FINANCIER ÉCARTS CAISSE
-- ────────────────────────────────
--   Serveuses saisissent leurs ventes (espèces + OM) dans saisie.html.
--   Caissière reçoit physiquement l'argent (tiroir espèces + compte OM lounge).
--   À la clôture, elle déclare ce qu'elle a reçu de chaque serveuse
--   → écart serveuse  = déclaré saisie − reçu caissière  (dette serveuse)
--   → écart caissière espèces = théorique tiroir − compté physiquement
--   → écart caissière OM      = théorique OM − vérifié sur compte
--   Chaque personne porte son propre écart, déduit de son salaire.
-- ════════════════════════════════════════════════════════════════════


-- ════════════════════════════════════════════════════════════════════
-- 0. NETTOYAGE — suppression dans l'ordre (feuilles avant racines)
-- ════════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS votes_prop            CASCADE;
DROP TABLE IF EXISTS propositions          CASCADE;
DROP TABLE IF EXISTS remboursements_ecart  CASCADE;
DROP TABLE IF EXISTS credits               CASCADE;
DROP TABLE IF EXISTS verifications_staff   CASCADE;
DROP TABLE IF EXISTS achats_session        CASCADE;
DROP TABLE IF EXISTS sorties_chicha        CASCADE;
DROP TABLE IF EXISTS mouvements_caisse     CASCADE;
DROP TABLE IF EXISTS ventes_session        CASCADE;
DROP TABLE IF EXISTS rapports              CASCADE;
DROP TABLE IF EXISTS salaires_verses       CASCADE;
DROP TABLE IF EXISTS avances               CASCADE;
DROP TABLE IF EXISTS justifications        CASCADE;
DROP TABLE IF EXISTS presences             CASCADE;
DROP TABLE IF EXISTS charges               CASCADE;
DROP TABLE IF EXISTS sessions_caisse       CASCADE;
DROP TABLE IF EXISTS tables_lounge         CASCADE;
DROP TABLE IF EXISTS produits              CASCADE;
DROP TABLE IF EXISTS associes              CASCADE;
DROP TABLE IF EXISTS employes              CASCADE;
DROP TABLE IF EXISTS logs                  CASCADE;
DROP TABLE IF EXISTS config                CASCADE;
-- anciennes tables périmées
DROP TABLE IF EXISTS salaires              CASCADE;
DROP TABLE IF EXISTS ventes                CASCADE;


-- ════════════════════════════════════════════════════════════════════
-- 1. CONFIG
--    Paramètres globaux du système (clé / valeur).
--    L'owner (gestionnaire) est défini ICI, pas dans une table.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE config (
  key   TEXT PRIMARY KEY,
  value TEXT
);
ALTER TABLE config DISABLE ROW LEVEL SECURITY;

INSERT INTO config (key, value) VALUES
  -- Authentification
  ('pin_owner',          NULL),      -- hash SHA-256 du PIN gestionnaire
  ('pin_manager',        NULL),      -- hash SHA-256 du PIN manager (partagé)
  ('pin_staff',          NULL),      -- hash SHA-256 du PIN staff  (partagé)
  -- Identité gestionnaire
  ('owner_nom',          'Gestionnaire'),
  -- Messages
  ('note_manager',       ''),        -- message visible sur dashboard manager
  -- Paramètres financiers
  ('objectif_journalier','0'),       -- objectif net journalier (GNF)
  ('part_lounge',        '10'),      -- % du net réservé au lounge avant distribution
  ('owner_pct',          NULL);      -- % fixe du gestionnaire (NULL = auto : 100 − Σ assocs%)


-- ════════════════════════════════════════════════════════════════════
-- 2. ASSOCIES
--    Co-investisseurs du lounge.
--    ≠ employés : pas de salaire, pas de pointage, pas d'avance.
--    Accès : Dashboard, Caisse (lecture), Historique, Finances,
--            Bilan, Associés.
--    Chaque associé a son propre PIN pour se connecter.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE associes (
  id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  nom         TEXT        NOT NULL,
  prenom      TEXT,
  pourcentage NUMERIC     NOT NULL DEFAULT 0,   -- % de distribution du net
  pin_hash    TEXT,                             -- SHA-256 du PIN personnel
  actif       BOOLEAN     NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ          DEFAULT now()
);
ALTER TABLE associes DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 3. EMPLOYES
--    Salariés uniquement : manager, caissier, staff, chicha, achats.
--    Chaque employé a son propre PIN (pin_hash) pour être identifié
--    individuellement (pointage, fiche, avance, paie, écarts…).
--    Le manager peut aussi utiliser le PIN partagé de config (s'il
--    n'a pas de PIN individuel), mais sera identifié comme "Manager"
--    sans nom propre.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE employes (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  nom          TEXT        NOT NULL,
  prenom       TEXT,
  poste        TEXT,                              -- titre libre (ex. "Responsable chicha")
  role         TEXT        NOT NULL
               CHECK (role IN ('manager','caissier','staff','chicha','achats')),
  salaire_base INTEGER     NOT NULL DEFAULT 0,   -- salaire brut mensuel (GNF)
  pin_hash     TEXT,                             -- SHA-256 du PIN individuel
  actif        BOOLEAN     NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ          DEFAULT now()
);
ALTER TABLE employes DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 4. LOGS
--    Audit trail : connexions et actions importantes.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE logs (
  id        UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  role      TEXT,
  action    TEXT,
  timestamp TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE logs DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 5. PRODUITS
--    Catalogue commun : chicha, boissons, autres.
--    ⚠  prix_defaut  (pas "prix")
--    ⚠  stock_min    (pas "seuil_bas")
--    ⚠  Filtre actifs : toujours .not('actif','is',false)
--       (couvre false ET null) — jamais .eq('actif',true)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE produits (
  id                  UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  nom                 TEXT        NOT NULL,
  type                TEXT        NOT NULL
                      CHECK (type IN ('chicha','boisson','autre')),
  stock_actuel        NUMERIC     NOT NULL DEFAULT 0,
  stock_min           NUMERIC     NOT NULL DEFAULT 0,   -- seuil d'alerte stock bas
  prix_defaut         INTEGER     NOT NULL DEFAULT 0,   -- prix de vente unitaire (GNF)
  prix_achat          INTEGER              DEFAULT 0,   -- coût d'achat (pour marge)
  unite_vente         TEXT                 DEFAULT 'unité',
  packaging_label     TEXT,                             -- ex. "Carton de 24"
  unite_par_packaging NUMERIC              DEFAULT 1,
  actif               BOOLEAN     NOT NULL DEFAULT true,
  created_at          TIMESTAMPTZ          DEFAULT now()
);
ALTER TABLE produits DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 6. TABLES LOUNGE
--    Référentiel des tables physiques de la salle.
--    Affiché en grille dans saisie.html pour la sélection.
--    Groupes (ex. T3+T4) : construits côté client en triant
--    et concaténant les labels — toujours "T3+T4", jamais "T4+T3".
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE tables_lounge (
  id     UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  label  TEXT    NOT NULL UNIQUE,   -- 'T1' … 'T8', 'Bar', 'Terrasse'
  ordre  INTEGER NOT NULL DEFAULT 0,
  actif  BOOLEAN NOT NULL DEFAULT true
);
ALTER TABLE tables_lounge DISABLE ROW LEVEL SECURITY;

INSERT INTO tables_lounge (label, ordre) VALUES
  ('T1', 1), ('T2', 2), ('T3', 3), ('T4', 4),
  ('T5', 5), ('T6', 6), ('T7', 7), ('T8', 8),
  ('Bar', 9), ('Terrasse', 10);


-- ════════════════════════════════════════════════════════════════════
-- 7. SESSIONS CAISSE
--    Une session = une journée d'exploitation.
--    Créée automatiquement par saisie.html ou caisse.html
--    si elle n'existe pas encore pour la date du jour.
--    Statuts : ouvert → valide_caissier → valide_manager
--
--    COLONNES ÉCART CAISSIÈRE (calculées et stockées à la clôture) :
--      ecart_especes = théoriqueEsp − total_reel
--      ecart_om      = théoriqueOM  − total_om_verifie
--      ecart         = ecart_especes + ecart_om  (affiché, déduit salaire)
--      + = manque d'argent  /  − = excédent (bonus)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE sessions_caisse (
  id               UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  date             DATE        NOT NULL UNIQUE,
  statut           TEXT        NOT NULL DEFAULT 'ouvert'
                   CHECK (statut IN ('ouvert','valide_caissier','valide_manager')),
  fond_caisse      INTEGER     NOT NULL DEFAULT 0,    -- fond de caisse du matin (GNF)

  -- Saisies de la caissière à la clôture
  total_reel       INTEGER,          -- espèces comptées physiquement dans le tiroir
  total_om_verifie INTEGER,          -- OM total vérifié sur le compte téléphone

  -- Écarts caissière (calculés et stockés lors de la clôture)
  ecart_especes    INTEGER,          -- écart espèces caissière
  ecart_om         INTEGER,          -- écart OM caissière
  ecart            INTEGER,          -- écart total = ecart_especes + ecart_om

  -- Métadonnées
  caissier_id      UUID        REFERENCES employes(id),
  note_caissier    TEXT,
  note_manager     TEXT,
  created_at       TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE sessions_caisse DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 8. VENTES SESSION
--    Une ligne = un article vendu par une serveuse dans la session.
--    Saisies dans saisie.html — plusieurs tours possibles par jour.
--
--    table_label : label libre ou groupé ('T1', 'T3+T4', 'Bar', null)
--      → sélectionné en début de chaque tour
--      → groupe trié côté client avant stockage (T3 < T4 → "T3+T4")
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE ventes_session (
  id            UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id    UUID        NOT NULL REFERENCES sessions_caisse(id) ON DELETE CASCADE,
  employe_id    UUID        REFERENCES employes(id) ON DELETE SET NULL,
  produit_id    UUID        REFERENCES produits(id) ON DELETE SET NULL,
  produit_nom   TEXT        NOT NULL,   -- snapshot du nom au moment de la vente
  qty           NUMERIC     NOT NULL DEFAULT 1,
  prix_unitaire INTEGER     NOT NULL,
  total         INTEGER     NOT NULL,   -- qty × prix_unitaire (stocké)
  paiement      TEXT        NOT NULL DEFAULT 'especes'
                CHECK (paiement IN ('especes','om')),
  table_label   TEXT,                   -- null si aucune table sélectionnée
  created_at    TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE ventes_session DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 9. VÉRIFICATIONS STAFF  ← TABLE CLÉ DU NOUVEAU MODÈLE
--    Ce que la caissière déclare avoir reçu de chaque serveuse
--    au moment de la clôture de session.
--
--    ÉCART SERVEUSE (calculé en JS à partir de cette table) :
--      decl_esp = SUM(ventes_session.total WHERE paiement='especes' AND employe_id=X)
--      decl_om  = SUM(ventes_session.total WHERE paiement='om'      AND employe_id=X)
--      ecart    = (decl_esp + decl_om) − (recu_especes + recu_om)
--      → positif = dette serveuse (déduite de son salaire)
--      → négatif = excédent (rare)
--
--    ÉCART CAISSIÈRE ESPÈCES (dans sessions_caisse) :
--      théoriqueEsp = fond + SUM(recu_especes) + entrées − sorties − achats
--      ecart_especes = théoriqueEsp − total_reel
--
--    ÉCART CAISSIÈRE OM (dans sessions_caisse) :
--      théoriqueOM = SUM(recu_om)
--      ecart_om    = théoriqueOM − total_om_verifie
--
--    UNIQUE(session_id, employe_id) : une seule vérification par
--    serveuse par session.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE verifications_staff (
  id            UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id    UUID        NOT NULL REFERENCES sessions_caisse(id) ON DELETE CASCADE,
  employe_id    UUID        NOT NULL REFERENCES employes(id)        ON DELETE CASCADE,
  recu_especes  INTEGER     NOT NULL DEFAULT 0,   -- espèces reçues de cette serveuse
  recu_om       INTEGER     NOT NULL DEFAULT 0,   -- OM reçu pour cette serveuse
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE(session_id, employe_id)
);
ALTER TABLE verifications_staff DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 10. MOUVEMENTS CAISSE
--     Entrées et sorties manuelles pendant la session
--     (appoint, dépense urgente, rendu monnaie en gros…).
--     Entrées ajoutées au théorique espèces / sorties déduites.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE mouvements_caisse (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID        NOT NULL REFERENCES sessions_caisse(id) ON DELETE CASCADE,
  type       TEXT        NOT NULL CHECK (type IN ('entree','sortie')),
  motif      TEXT,
  montant    INTEGER     NOT NULL CHECK (montant > 0),
  note       TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE mouvements_caisse DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 11. ACHATS SESSION
--     Dépenses / achats enregistrés pendant la session (rôle achats).
--     Déduits du théorique espèces caissière.
--     Préremplissent le champ total_achats dans rapport.html.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE achats_session (
  id            UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id    UUID        NOT NULL REFERENCES sessions_caisse(id) ON DELETE CASCADE,
  categorie     TEXT,
  produit_nom   TEXT,
  montant       INTEGER     NOT NULL CHECK (montant > 0),
  qty           NUMERIC              DEFAULT 1,
  prix_unitaire INTEGER,
  created_at    TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE achats_session DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 12. SORTIES CHICHA
--     Suivi inventaire chicha uniquement (rôle chicha).
--     ⚠  PAS utilisé dans les calculs financiers du rapport.
--        Le manager saisit manuellement les totaux dans rapport.html.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE sorties_chicha (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID        REFERENCES sessions_caisse(id) ON DELETE SET NULL,
  employe_id UUID        NOT NULL REFERENCES employes(id) ON DELETE CASCADE,
  arome      TEXT        NOT NULL,
  qty        INTEGER     NOT NULL DEFAULT 1,
  valide     BOOLEAN              DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE sorties_chicha DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 13. RAPPORTS
--     Rapport journalier créé par le manager après validation session.
--     Les lignes chicha / boissons sont saisies MANUELLEMENT par le
--     manager dans rapport.html. Les achats sont préremplis depuis
--     achats_session.
--
--     FORMULES :
--       recettes = total_chicha + total_boissons
--       net      = recettes − total_achats
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE rapports (
  id             UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  date           DATE        NOT NULL,
  num            INTEGER     NOT NULL,             -- N° séquentiel : MAX(num) + 1
  session_id     UUID        REFERENCES sessions_caisse(id) ON DELETE SET NULL,
  total_chicha   INTEGER     NOT NULL DEFAULT 0,
  total_boissons INTEGER     NOT NULL DEFAULT 0,
  total_achats   INTEGER     NOT NULL DEFAULT 0,
  recettes       INTEGER     NOT NULL DEFAULT 0,   -- chicha + boissons
  net            INTEGER     NOT NULL DEFAULT 0,   -- recettes − achats
  manager        TEXT,                             -- nom du manager (snapshot)
  caissier       TEXT,                             -- nom de la caissière (snapshot)
  part           JSONB,       -- snapshot répartition : {lounge, owner, assocs:[{nom,pct,part}]}
  chicha_rows    JSONB,       -- [{arome, qty, prix, total}, …]
  boissons_rows  JSONB,       -- [{nom, qty, prix, total}, …]
  achats_rows    JSONB,       -- [{categorie, nom, montant}, …]
  created_at     TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE rapports DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 14. PRÉSENCES
--     Pointage journalier par employé salarié.
--     UNIQUE(employe_id, date) : un seul statut par jour.
--     Les absences non justifiées (absNJ) entrent dans le calcul de paie.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE presences (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id UUID        NOT NULL REFERENCES employes(id) ON DELETE CASCADE,
  date       DATE        NOT NULL,
  statut     TEXT        NOT NULL DEFAULT 'present'
             CHECK (statut IN ('present','absent','retard','conge')),
  note       TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(employe_id, date)
);
ALTER TABLE presences DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 15. JUSTIFICATIONS
--     Justificatifs d'absence/retard soumis et approuvés/rejetés
--     dans rh.html. Une absence avec justification approuvée n'est
--     pas comptée comme absNJ dans le calcul de paie.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE justifications (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id UUID        NOT NULL REFERENCES employes(id) ON DELETE CASCADE,
  date       DATE        NOT NULL,
  type       TEXT,                   -- 'maladie', 'famille', 'conge', …
  motif      TEXT,
  statut     TEXT        NOT NULL DEFAULT 'en_attente'
             CHECK (statut IN ('en_attente','approuvee','rejetee')),
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE justifications DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 16. AVANCES
--     Avances sur salaire demandées par l'employé (avance.html)
--     ou accordées directement par le manager (rh.html onglet Avances).
--     Déduites du net_verse lors du calcul de paie.
--     rembourse=true après paiement du salaire (validerPaie dans rh.html).
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE avances (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id   UUID        NOT NULL REFERENCES employes(id) ON DELETE CASCADE,
  montant      INTEGER     NOT NULL CHECK (montant > 0),
  date         DATE        NOT NULL DEFAULT CURRENT_DATE,
  statut       TEXT        NOT NULL DEFAULT 'en_attente'
               CHECK (statut IN ('en_attente','approuvee','rejetee')),
  rembourse    BOOLEAN     NOT NULL DEFAULT false,
  obs          TEXT,                     -- note du manager
  note_demande TEXT,                     -- message de l'employé
  created_at   TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE avances DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 17. SALAIRES VERSÉS
--     Enregistrement du paiement mensuel (rh.html → VERSER).
--     UNIQUE(employe_id, mois) : un seul versement par mois.
--     ANNULER → DELETE (les avances gardent rembourse=true).
--
--     ecarts_deduits couvre les deux cas :
--       - serveuse  : SUM(écart verifications_staff) non remboursé ce mois
--       - caissière : SUM(ecart sessions_caisse)     non remboursé ce mois
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE salaires_verses (
  id                      UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id              UUID        NOT NULL REFERENCES employes(id) ON DELETE CASCADE,
  mois                    TEXT        NOT NULL,   -- 'YYYY-MM'
  salaire_brut            INTEGER     NOT NULL DEFAULT 0,
  avances_deduites        INTEGER     NOT NULL DEFAULT 0,
  ecarts_deduits          INTEGER     NOT NULL DEFAULT 0,
  surplus_caisse          INTEGER     NOT NULL DEFAULT 0,   -- bonus excédent
  net_verse               INTEGER     NOT NULL DEFAULT 0,
  nb_absences_nj          INTEGER     NOT NULL DEFAULT 0,
  sanction_type           TEXT        NOT NULL DEFAULT 'aucune',
  sanction_montant        INTEGER     NOT NULL DEFAULT 0,
  nb_retards              INTEGER     NOT NULL DEFAULT 0,
  sanction_retard_montant INTEGER     NOT NULL DEFAULT 0,
  paye_le                 DATE                 DEFAULT CURRENT_DATE,
  created_at              TIMESTAMPTZ DEFAULT now(),
  UNIQUE(employe_id, mois)
);
ALTER TABLE salaires_verses DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 18. CHARGES
--     Charges fixes mensuelles (loyer, électricité, abonnements…).
--     ⚠  Colonne s'appelle label (pas libelle).
--     mois = 'YYYY-MM'.
--     Déduites du net dans finances.html et bilan.html.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE charges (
  id            UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  label         TEXT        NOT NULL,
  montant       INTEGER     NOT NULL CHECK (montant > 0),
  mois          TEXT        NOT NULL,   -- 'YYYY-MM'
  categorie     TEXT                 DEFAULT 'autre',
  paye          BOOLEAN     NOT NULL DEFAULT false,
  date_paiement DATE,
  recurrence    TEXT                 DEFAULT 'mensuelle',
  created_at    TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE charges DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 19. REMBOURSEMENTS ÉCART
--     Remboursements d'écart caisse — couvre les deux cas :
--       - serveuse  : rembourse son écart (déclaré saisie − reçu caissière)
--       - caissière : rembourse son écart tiroir ou OM
--     Validés par manager → pris en compte dans ecarts_deduits (paie).
--     Badge rouge sur nav "Caisse" tant que statut='en_attente'.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE remboursements_ecart (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID        REFERENCES sessions_caisse(id) ON DELETE CASCADE,
  employe_id UUID        NOT NULL REFERENCES employes(id) ON DELETE CASCADE,
  montant    INTEGER     NOT NULL CHECK (montant > 0),
  note       TEXT,
  statut     TEXT        NOT NULL DEFAULT 'en_attente'
             CHECK (statut IN ('en_attente','valide','rejete')),
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE remboursements_ecart DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 20. CRÉDITS
--     Consommations à crédit d'un employé (boisson, chicha…).
--     Suivis séparément des avances.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE credits (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  employe_id UUID        NOT NULL REFERENCES employes(id) ON DELETE CASCADE,
  session_id UUID        REFERENCES sessions_caisse(id) ON DELETE SET NULL,
  montant    INTEGER     NOT NULL CHECK (montant > 0),
  rembourse  BOOLEAN     NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE credits DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 21. PROPOSITIONS
--     Soumises et votées entre associés dans associes.html.
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE propositions (
  id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  titre       TEXT        NOT NULL,
  description TEXT,
  auteur_nom  TEXT        NOT NULL,
  statut      TEXT        NOT NULL DEFAULT 'ouvert'
              CHECK (statut IN ('ouvert','ferme')),
  created_at  TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE propositions DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- 22. VOTES PROPOSITIONS
--     Un vote par associé par proposition (UNIQUE).
--     votant_key  = associe.id (UUID sous forme text) ou 'owner'
--     poids       = snapshot du pourcentage au moment du vote
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE votes_prop (
  id             UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  proposition_id UUID        NOT NULL REFERENCES propositions(id) ON DELETE CASCADE,
  votant_key     TEXT        NOT NULL,   -- associe.id::text ou 'owner'
  votant_nom     TEXT,
  poids          NUMERIC,               -- % snapshot au moment du vote
  choix          BOOLEAN     NOT NULL,  -- true = pour / false = contre
  created_at     TIMESTAMPTZ DEFAULT now(),
  UNIQUE(proposition_id, votant_key)
);
ALTER TABLE votes_prop DISABLE ROW LEVEL SECURITY;


-- ════════════════════════════════════════════════════════════════════
-- RÉCAPITULATIF DES FORMULES DE CALCUL
-- ════════════════════════════════════════════════════════════════════
--
-- ── ÉCART SERVEUSE (caisse.html / fiche.html / rh.html) ──────────────
--   decl_esp = SUM(ventes_session.total WHERE paiement='especes' AND employe_id=X AND session_id=Y)
--   decl_om  = SUM(ventes_session.total WHERE paiement='om'      AND employe_id=X AND session_id=Y)
--   recu_esp = verifications_staff.recu_especes WHERE employe_id=X AND session_id=Y
--   recu_om  = verifications_staff.recu_om      WHERE employe_id=X AND session_id=Y
--   ecart_serveuse = (decl_esp + decl_om) − (recu_esp + recu_om)
--   → positif = dette serveuse  /  négatif = excédent
--
-- ── ÉCART CAISSIÈRE (calculé et stocké dans sessions_caisse) ─────────
--   tot_recu_esp = SUM(verifications_staff.recu_especes) pour la session
--   tot_recu_om  = SUM(verifications_staff.recu_om)      pour la session
--   entrees      = SUM(mouvements_caisse.montant WHERE type='entree')
--   sorties      = SUM(mouvements_caisse.montant WHERE type='sortie')
--   achats       = SUM(achats_session.montant)
--
--   theoriqueEsp  = fond_caisse + tot_recu_esp + entrees − sorties − achats
--   ecart_especes = theoriqueEsp − total_reel            (stocké sessions_caisse)
--
--   theoriqueOM   = tot_recu_om
--   ecart_om      = theoriqueOM − total_om_verifie       (stocké sessions_caisse)
--
--   ecart         = ecart_especes + ecart_om             (stocké sessions_caisse)
--   surplus       = MAX(0, −ecart)   si écart < 0 → bonus caissière
--
-- ── RAPPORT ──────────────────────────────────────────────────────────
--   recettes = total_chicha + total_boissons
--   net      = recettes − total_achats
--
-- ── DISTRIBUTION (finances / bilan / associes) ───────────────────────
--   net_for_parts = SUM(rapports.net) − SUM(charges.montant)
--   distribPct    = MAX(0, 100 − part_lounge) / 100
--   owner_pct     = config.owner_pct  OU  MAX(0, 100 − SUM(associes.pourcentage))
--   part_lounge   = net_for_parts × (part_lounge / 100)
--   part_owner    = MAX(0, net_for_parts) × distribPct × owner_pct / 100
--   part_assoc_X  = MAX(0, net_for_parts) × distribPct × assocX.pourcentage / 100
--
-- ── SALAIRE NET (rh.html / fiche.html) ───────────────────────────────
--   absNJ        = absences − justifications_approuvees (ce mois)
--   sanc_abs     = brut × (0 si 0 absNJ, 0.10 si 2, 0.15 si ≥3)
--   sanc_ret     = brut × 0.10 si retards ≥ 5 ce mois
--   avances_ded  = SUM(avances.montant WHERE statut='approuvee' AND rembourse=false)
--   ecarts_ded   = Σ écarts non remboursés ce mois
--                  (verifications_staff pour serveuses,
--                   sessions_caisse.ecart pour caissière)
--                  − SUM(remboursements_ecart.montant WHERE statut='valide' ce mois)
--   surplus_bon  = Σ excédents ce mois (écarts négatifs caissière)
--   net_verse    = MAX(0, brut − sanc_abs − sanc_ret − avances_ded − ecarts_ded + surplus_bon)
-- ════════════════════════════════════════════════════════════════════
