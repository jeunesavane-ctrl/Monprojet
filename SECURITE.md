# Medellin Lounge — Sécurité (plan de durcissement)

> ⚠️ **À lire avant toute mise en ligne.** Ce document décrit LA faille structurelle
> du projet et le plan pour la fermer. Le correctif vit **dans ton compte Supabase**,
> pas dans les fichiers HTML — je peux tout écrire mais **toi seul peux le déployer**
> (je n'ai pas accès à ton tableau de bord Supabase).

---

## 1. Le problème en clair

Aujourd'hui :

- **RLS (Row Level Security) est désactivé** sur toutes les tables.
- La **clé anon** (`sb_publishable_…`) est livrée en clair dans `shared.js` à
  chaque visiteur.

Conséquence : **n'importe qui connaissant l'URL du site peut lire, modifier et
supprimer toutes les données** (rapports, salaires, PIN, avances…) en appelant
directement l'API Supabase — **sans passer par l'écran de PIN**. L'authentification
par PIN est purement décorative : elle vit dans le navigateur, donc elle se contourne.

Pire : à l'ouverture d'`index.html`, le navigateur télécharge **tous les hash de PIN**
(`employes.pin_hash`, `config.pin_owner/manager`). Comme un PIN = SHA-256 non salé de
4 chiffres (**10 000 combinaisons**), il se « casse » en quelques millisecondes.

**Aucune ligne de JavaScript côté navigateur ne peut corriger ça.** La protection
doit être posée **côté serveur** (RLS + vérification du PIN dans une fonction serveur).

---

## 2. Mesures immédiates (zéro risque, à faire maintenant)

Ces actions ne cassent rien et réduisent déjà la casse :

1. **Changer tous les PIN par défaut** depuis `parametres.html` :
   - Le PIN staff par défaut est `1234` (hash public connu). À changer.
   - Mettre un PIN gestionnaire fort, différent du manager.
2. **Ne jamais publier l'URL de production** ailleurs que nécessaire (pas d'index
   par les moteurs de recherche — déjà le cas via `X-Frame-Options`, mais ajouter
   un `robots.txt` `Disallow: /` et un `<meta name="robots" content="noindex">`).
3. **Sauvegarder la base** (export Supabase) avant toute manipulation de sécurité.

> Ces mesures **ne ferment pas** la faille (la base reste ouverte via l'API), elles
> limitent seulement l'exposition pendant la bascule.

---

## 3. Architecture cible (recommandée)

On **garde l'UX du pavé PIN** (le propriétaire y tient), mais on déplace la
**vérification** côté serveur et on **verrouille les tables** avec RLS.

```
┌──────────────┐   PIN saisi   ┌────────────────────────┐   vérifie hash   ┌──────────┐
│  index.html  │ ────────────► │  Edge Function `login` │ ───────────────► │ employes │
│ (pavé PIN)   │ ◄──────────── │  (service_role, privé) │ ◄─────────────── │  config  │
└──────────────┘  JWT + rôle   └────────────────────────┘   rôle trouvé    └──────────┘
        │ supabase.auth.setSession(jwt)
        ▼
   Toutes les pages appellent db.from(...) AVEC le JWT
        ▼
   RLS autorise selon auth.jwt()->>'role'
```

Points clés :
- Les **hash de PIN ne quittent plus jamais le navigateur** : la comparaison se fait
  dans l'Edge Function (qui utilise la clé `service_role`, jamais exposée au client).
- Chaque session reçoit un **JWT signé** contenant le rôle → RLS peut décider.
- Le code des 18 pages **change très peu** : les `db.from(...)` deviennent simplement
  authentifiés.

---

## 4. SQL — Activation RLS + politiques (à exécuter dans Supabase)

> ⚠️ **N'exécute PAS ce bloc tant que l'Edge Function `login` (section 5) n'est pas
> déployée et testée** : activer RLS sans authentification couperait l'app.

```sql
-- Exemple pour quelques tables — à répliquer sur TOUTES les tables.
-- 'role' est lu depuis le JWT émis par la fonction login.

ALTER TABLE rapports ENABLE ROW LEVEL SECURITY;

-- Lecture : manager/owner/associe
CREATE POLICY rapports_select ON rapports FOR SELECT
  USING ( (auth.jwt() ->> 'role') IN ('manager','owner','associe') );

-- Écriture : manager/owner uniquement
CREATE POLICY rapports_write ON rapports FOR INSERT
  WITH CHECK ( (auth.jwt() ->> 'role') IN ('manager','owner') );
CREATE POLICY rapports_update ON rapports FOR UPDATE
  USING ( (auth.jwt() ->> 'role') IN ('manager','owner') );
-- Suppression : owner uniquement (cohérent avec historique.html)
CREATE POLICY rapports_delete ON rapports FOR DELETE
  USING ( (auth.jwt() ->> 'role') = 'owner' );

-- employes : lecture des données sensibles INTERDITE au client.
-- pin_hash ne doit JAMAIS être SELECT-able côté navigateur.
ALTER TABLE employes ENABLE ROW LEVEL SECURITY;
CREATE POLICY employes_select ON employes FOR SELECT
  USING ( (auth.jwt() ->> 'role') IN ('manager','owner') );  -- + colonne pin_hash exclue via une VUE
-- → créer une VUE `employes_public` SANS pin_hash pour les besoins d'affichage,
--   et ne donner accès qu'à cette vue aux rôles non-admin.

-- config : pin_owner / pin_manager NE DOIVENT PLUS être lisibles au client.
ALTER TABLE config ENABLE ROW LEVEL SECURITY;
CREATE POLICY config_select ON config FOR SELECT
  USING ( (auth.jwt() ->> 'role') = 'owner' AND key NOT LIKE 'pin_%' );
```

La matrice rôles → pages du `CLAUDE.md` sert de base pour écrire les `USING(...)`
de chaque table.

---

## 5. Edge Function `login` (squelette à déployer)

`supabase/functions/login/index.ts` — vérifie le PIN côté serveur, renvoie le rôle.

```ts
import { createClient } from 'jsr:@supabase/supabase-js@2';

const sb = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!  // clé privée — jamais exposée au client
);

async function sha256(s: string) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2,'0')).join('');
}

Deno.serve(async (req) => {
  const { pin } = await req.json();
  if (!/^\d{4,}$/.test(pin ?? '')) return new Response('PIN invalide', { status: 400 });
  const h = await sha256(pin);

  // 1) owner / manager via config
  const { data: cfg } = await sb.from('config').select('key,value')
    .in('key', ['pin_owner','pin_manager']);
  const map = Object.fromEntries((cfg||[]).map(r => [r.key, r.value]));
  let role: string | null = null, profile: any = null;
  if (h === map.pin_owner)   role = 'owner';
  else if (h === map.pin_manager) role = 'manager';
  else {
    // 2) employés
    const { data: emp } = await sb.from('employes')
      .select('id,nom,prenom,role,pourcentage,actif').eq('pin_hash', h).maybeSingle();
    if (emp && emp.actif !== false) { role = emp.role || 'staff'; profile = emp; }
  }
  if (!role) return new Response('Code incorrect', { status: 401 });

  // 3) émettre une session Supabase avec le rôle en claim
  //    (via createUser/anonymous + app_metadata.role, ou un JWT signé maison —
  //     voir doc Supabase "Custom Access Token Hook").
  return Response.json({ role, profile });  // ← à remplacer par { access_token, refresh_token }
});
```

> Le passage `{ role, profile }` → `{ access_token }` se fait via le **Custom Access
> Token Hook** de Supabase (pour injecter `role` dans le JWT) **ou** une table
> d'utilisateurs Supabase Auth liée à `employes`. C'est l'étape à finaliser ensemble.

Côté client (`index.html`), après réception : `await db.auth.setSession({...})` puis
redirection — le reste de l'app fonctionne tel quel, mais authentifié.

---

## 6. Plan de bascule (sans jamais couper l'app)

1. **Phase 0** — mesures immédiates (section 2) + sauvegarde.
2. **Phase 1** — déployer l'Edge Function `login`, brancher `index.html` dessus.
   Les hash de PIN cessent d'être envoyés au navigateur. **RLS encore désactivé.**
3. **Phase 2** — activer RLS **table par table**, en testant chaque page après
   chaque table (commencer par les moins critiques). Rollback = `DISABLE RLS`.
4. **Phase 3** — créer la vue `employes_public` sans `pin_hash`, retirer l'accès
   direct à `employes`/`config` aux rôles non-owner.
5. **Phase 4** — (optionnel) PIN à 6 chiffres + sel, ou passage à un vrai mot de passe.

À chaque phase, l'app reste fonctionnelle ; on n'avance que si la précédente est
validée.

---

## 7. Hash d'intégrité des rapports (`rapports.hash`)

Le hash actuel (`sha256(num|date|…|net)`) **n'est pas une preuve** : il est
recalculable par quiconque (pas de secret) et **jamais vérifié à la lecture**. Il
n'est généré que par `rapport.html`, pas par les deux autres voies de création.

→ Soit on le **supprime** (il est décoratif), soit on le remplace par un **HMAC**
calculé côté serveur (Edge Function, avec un secret) et **vérifié** à l'affichage.
À décider une fois la sécurité de base en place.

---

## 8. Ce que je peux construire ensuite

Sur ta demande, je peux écrire :
- l'Edge Function `login` complète + le Custom Access Token Hook ;
- le jeu **complet** de politiques RLS pour les 22 tables (matrice rôles) ;
- la vue `employes_public` et la migration d'accès ;
- la modif d'`index.html` / `shared.js` pour l'auth Supabase.

On le fait **phase par phase**, testé à chaque étape, pour ne jamais bloquer le lounge.
