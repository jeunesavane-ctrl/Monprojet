-- ════════════════════════════════════════════════════════════════
-- MEDELLIN LOUNGE — MIGRATION CDC v6.0
-- Nouvelles tables séparées + colonnes ventes_session
-- À coller dans Supabase → SQL Editor → Run
-- Idempotent : peut être exécuté plusieurs fois sans danger.
-- ════════════════════════════════════════════════════════════════


-- ── 1. Table associes (distincte d'employes) ─────────────────
-- Les associés ont leur propre table : pas de poste/role/salaire_base.
CREATE TABLE IF NOT EXISTS associes (
  id          UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  nom         TEXT    NOT NULL,
  prenom      TEXT,
  pourcentage NUMERIC NOT NULL DEFAULT 0,
  pin_hash    TEXT,
  actif       BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE associes DISABLE ROW LEVEL SECURITY;

-- Migration des associés depuis employes.role='associe' (idempotent).
-- ⚠ Ne supprime PAS les lignes dans employes (rétrocompatibilité).
INSERT INTO associes (id, nom, prenom, pourcentage, pin_hash, actif, created_at)
SELECT
  id,
  nom,
  prenom,
  COALESCE(pourcentage, 0),
  pin_hash,
  COALESCE(actif, true),
  COALESCE(created_at, now())
FROM employes
WHERE role = 'associe'
ON CONFLICT (id) DO NOTHING;


-- ── 2. Table tables_lounge ────────────────────────────────────
-- Tables physiques du lounge, gérées depuis parametres.html.
CREATE TABLE IF NOT EXISTS tables_lounge (
  id          UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  label       TEXT    NOT NULL UNIQUE,
  ordre       INTEGER NOT NULL DEFAULT 0,
  actif       BOOLEAN NOT NULL DEFAULT true,
  ouverte_par UUID    REFERENCES employes(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE tables_lounge DISABLE ROW LEVEL SECURITY;


-- ── 3. Table verifications_staff ──────────────────────────────
-- Vérification espèces/OM déclarée par chaque employé dans une session.
CREATE TABLE IF NOT EXISTS verifications_staff (
  id           UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id   UUID    NOT NULL REFERENCES sessions_caisse(id) ON DELETE CASCADE,
  employe_id   UUID    NOT NULL REFERENCES employes(id)        ON DELETE CASCADE,
  recu_especes INTEGER NOT NULL DEFAULT 0,
  recu_om      INTEGER NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE(session_id, employe_id)
);
ALTER TABLE verifications_staff DISABLE ROW LEVEL SECURITY;


-- ── 4. ventes_session — colonnes CDC v6 ──────────────────────
-- Les nouvelles colonnes sont ajoutées si absentes.
-- Les anciennes (type, label, valide_staff) restent pour l'historique.
ALTER TABLE ventes_session
  ADD COLUMN IF NOT EXISTS produit_id    UUID    REFERENCES produits(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS produit_nom   TEXT,
  ADD COLUMN IF NOT EXISTS qty           NUMERIC NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS prix_unitaire INTEGER,
  ADD COLUMN IF NOT EXISTS total         INTEGER,
  ADD COLUMN IF NOT EXISTS paiement      TEXT,
  ADD COLUMN IF NOT EXISTS table_label   TEXT;


-- ════════════════════════════════════════════════════════════════
-- VÉRIFICATION (lecture seule — à exécuter séparément après Run)
-- ════════════════════════════════════════════════════════════════
-- a) Associés migrés depuis employes
-- SELECT nom, prenom, pourcentage FROM associes ORDER BY nom;
--
-- b) Nouvelles tables présentes
-- SELECT table_name FROM information_schema.tables
--   WHERE table_schema = 'public'
--   AND table_name IN ('associes','tables_lounge','verifications_staff');
--
-- c) Colonnes ventes_session
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'ventes_session' ORDER BY ordinal_position;
