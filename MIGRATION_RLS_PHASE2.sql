-- ════════════════════════════════════════════════════════════════
-- MEDELLIN LOUNGE — MIGRATION RLS PHASE 2
-- Active Row Level Security sur toutes les tables.
-- Politique : seuls les utilisateurs authentifiés (y compris
-- les sessions anonymes créées par signInAnonymously) peuvent lire/écrire.
-- Clé anon non authentifiée = accès refusé.
--
-- ⚠ AVANT d'exécuter :
--   1. Activer "Allow anonymous sign-ins" dans Supabase
--      → Authentication → Configuration → Anonymous sign-ins
--   2. Vérifier que le login fonctionne toujours (Edge Function)
--   3. Exécuter ce script → Run
-- ════════════════════════════════════════════════════════════════

-- ── Helper : macro pour chaque table ─────────────────────────
-- Pour chaque table :
--   ENABLE RLS + CREATE POLICY "authenticated_only" FOR ALL TO authenticated

ALTER TABLE employes             ENABLE ROW LEVEL SECURITY;
ALTER TABLE config               ENABLE ROW LEVEL SECURITY;
ALTER TABLE rapports             ENABLE ROW LEVEL SECURITY;
ALTER TABLE presences            ENABLE ROW LEVEL SECURITY;
ALTER TABLE justifications       ENABLE ROW LEVEL SECURITY;
ALTER TABLE avances              ENABLE ROW LEVEL SECURITY;
ALTER TABLE salaires_verses      ENABLE ROW LEVEL SECURITY;
ALTER TABLE charges              ENABLE ROW LEVEL SECURITY;
ALTER TABLE produits             ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions_caisse      ENABLE ROW LEVEL SECURITY;
ALTER TABLE remboursements_ecart ENABLE ROW LEVEL SECURITY;
ALTER TABLE logs                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE credits              ENABLE ROW LEVEL SECURITY;
ALTER TABLE mouvements_caisse    ENABLE ROW LEVEL SECURITY;
ALTER TABLE achats_session       ENABLE ROW LEVEL SECURITY;
ALTER TABLE sorties_chicha       ENABLE ROW LEVEL SECURITY;
ALTER TABLE propositions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes_prop           ENABLE ROW LEVEL SECURITY;
ALTER TABLE associes             ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventes_session       ENABLE ROW LEVEL SECURITY;

-- tables_lounge et verifications_staff créées dans MIGRATION_CDC_v6.sql
-- avec DISABLE RLS — on les active ici
ALTER TABLE tables_lounge        ENABLE ROW LEVEL SECURITY;
ALTER TABLE verifications_staff  ENABLE ROW LEVEL SECURITY;


-- ── Policies : accès total aux utilisateurs authentifiés ─────
-- "authenticated" couvre les sessions anonymes (signInAnonymously)
-- ET les sessions classiques. La clé anon seule (non connectée) est bloquée.

CREATE POLICY "authenticated_only" ON employes             FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON config               FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON rapports             FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON presences            FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON justifications       FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON avances              FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON salaires_verses      FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON charges              FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON produits             FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON sessions_caisse      FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON remboursements_ecart FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON logs                 FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON credits              FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON mouvements_caisse    FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON achats_session       FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON sorties_chicha       FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON propositions         FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON votes_prop           FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON associes             FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON ventes_session       FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON tables_lounge        FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_only" ON verifications_staff  FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ════════════════════════════════════════════════════════════════
-- VÉRIFICATION (à exécuter séparément après Run)
-- ════════════════════════════════════════════════════════════════
-- SELECT tablename, rowsecurity
--   FROM pg_tables
--   WHERE schemaname = 'public'
--   ORDER BY tablename;
-- → Toutes les tables doivent avoir rowsecurity = true
