-- ════════════════════════════════════════════════════════════════════
-- MEDELLIN LOUNGE — MIGRATION 2026-06-11
-- « Les données existantes suivent le nouveau système »
--
-- À coller TEL QUEL dans Supabase → SQL Editor → Run.
-- Idempotent : peut être exécuté plusieurs fois sans danger.
--
-- Ce que fait ce script :
--  1. Ajoute la colonne sessions_caisse.ecart_especes
--  2. RECALCULE l'écart ESPÈCES de toutes les sessions déjà clôturées,
--     à partir des données brutes encore en base
--     (ventes_session + mouvements_caisse + achats_session + fond)
--     → l'écart OM est retiré rétroactivement de la paie caissière,
--       pour les mois passés comme pour les futurs.
--  3. Uniformise rapports.recettes (NULL → chicha + boissons) pour que
--     dashboard / bilan / finances lisent la même base partout.
-- ════════════════════════════════════════════════════════════════════


-- ── 1. Colonne écart espèces ─────────────────────────────────────────
ALTER TABLE sessions_caisse ADD COLUMN IF NOT EXISTS ecart_especes INTEGER;


-- ── 2. Recalcul rétroactif de l'écart espèces ────────────────────────
-- Formule (identique à caisse.html) :
--   theoriqueEsp  = fond + ventes_espèces + entrées − sorties − achats
--   ecart_especes = theoriqueEsp − total_reel (espèces comptées)
--
-- Garde-fous :
--   • total_reel IS NOT NULL  → la caissière a bien compté les espèces
--   • EXISTS ventes_session   → on exclut les sessions « rapport jour
--     passé » (pas de ventes tracées → recalcul impossible, on n'invente
--     rien pour elles : leur ecart_especes reste NULL et le code retombe
--     sur l'écart total comme avant)
--   • ecart_especes IS NULL   → idempotent (ne réécrit pas l'existant)

WITH agg AS (
  SELECT
    s.id,
    COALESCE(s.fond_caisse, 0)                                          AS fond,
    s.total_reel,
    COALESCE((SELECT SUM(v.total)   FROM ventes_session  v
              WHERE v.session_id = s.id), 0)                            AS tot_ventes,
    COALESCE((SELECT SUM(v.total)   FROM ventes_session  v
              WHERE v.session_id = s.id AND v.paiement = 'om'), 0)      AS tot_om,
    COALESCE((SELECT SUM(m.montant) FROM mouvements_caisse m
              WHERE m.session_id = s.id AND m.type = 'entree'), 0)      AS entrees,
    COALESCE((SELECT SUM(m.montant) FROM mouvements_caisse m
              WHERE m.session_id = s.id AND m.type = 'sortie'), 0)      AS sorties,
    COALESCE((SELECT SUM(a.montant) FROM achats_session  a
              WHERE a.session_id = s.id), 0)                            AS achats
  FROM sessions_caisse s
  WHERE s.total_reel    IS NOT NULL
    AND s.ecart_especes IS NULL
    AND EXISTS (SELECT 1 FROM ventes_session v WHERE v.session_id = s.id)
)
UPDATE sessions_caisse s
SET ecart_especes =
  (agg.fond + (agg.tot_ventes - agg.tot_om) + agg.entrees - agg.sorties - agg.achats)
  - agg.total_reel
FROM agg
WHERE s.id = agg.id;


-- ── 3. Uniformiser rapports.recettes ─────────────────────────────────
-- Les rapports créés via rapport.html n'avaient pas la colonne recettes
-- renseignée (NULL) ; ceux du dashboard l'avaient. On aligne tout sur la
-- formule officielle : recettes = chicha + boissons.
-- (On ne touche PAS aux valeurs déjà renseignées.)

UPDATE rapports
SET recettes = COALESCE(total_chicha, 0) + COALESCE(total_boissons, 0)
WHERE recettes IS NULL;


-- ════════════════════════════════════════════════════════════════════
-- VÉRIFICATION (lecture seule — colle ce bloc séparément après le Run)
-- ════════════════════════════════════════════════════════════════════
-- a) Sessions migrées : écart total vs écart espèces (la différence = OM)
-- SELECT date, ecart, ecart_especes, (ecart - ecart_especes) AS part_om
-- FROM sessions_caisse
-- WHERE ecart_especes IS NOT NULL
-- ORDER BY date DESC
-- LIMIT 20;
--
-- b) Sessions NON migrées (normal : jours passés saisis à la main,
--    ou espèces jamais comptées) :
-- SELECT date, statut, total_reel, ecart
-- FROM sessions_caisse
-- WHERE ecart_especes IS NULL
-- ORDER BY date DESC;
--
-- c) Rapports : plus aucun recettes NULL
-- SELECT COUNT(*) AS rapports_sans_recettes FROM rapports WHERE recettes IS NULL;
