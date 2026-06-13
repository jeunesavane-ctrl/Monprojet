import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL              = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type':                 'application/json',
};

async function sha256(s: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, '0')).join('');
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: CORS_HEADERS });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== 'POST')   return json({ error: 'Méthode non autorisée' }, 405);

  let pin: unknown;
  try { ({ pin } = await req.json()); }
  catch { return json({ error: 'Corps JSON invalide' }, 400); }

  if (typeof pin !== 'string' || !/^\d{4,8}$/.test(pin))
    return json({ error: 'PIN invalide' }, 400);

  const h  = await sha256(pin);
  const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  /* 1. Owner / Manager via config */
  const { data: cfg } = await sb.from('config').select('key,value')
    .in('key', ['pin_owner', 'pin_manager', 'owner_nom']);
  const map: Record<string, string> = Object.fromEntries(
    (cfg ?? []).map((r: { key: string; value: string }) => [r.key, r.value])
  );

  if (map.pin_owner && h === map.pin_owner)
    return json({ role: 'owner', extra: { nom: map.owner_nom || 'Gestionnaire' } });

  if (map.pin_manager && h === map.pin_manager)
    return json({ role: 'manager', extra: { nom: 'Manager' } });

  /* 2. Employé (caissier / staff / chicha / achats) */
  const { data: emp } = await sb.from('employes')
    .select('id,nom,prenom,role,actif').eq('pin_hash', h).maybeSingle();
  if (emp && emp.actif !== false) {
    const nom = [emp.prenom, emp.nom].filter(Boolean).join(' ') || emp.nom;
    return json({ role: emp.role, extra: { nom, employe_id: emp.id } });
  }

  /* 3. Associé */
  const { data: assoc } = await sb.from('associes')
    .select('id,nom,prenom,pourcentage,actif').eq('pin_hash', h).maybeSingle();
  if (assoc && assoc.actif !== false) {
    const nom = [assoc.prenom, assoc.nom].filter(Boolean).join(' ') || assoc.nom;
    return json({ role: 'associe', extra: { nom, associe_id: assoc.id, pourcentage: assoc.pourcentage ?? 0 } });
  }

  return json({ error: 'Code incorrect' }, 401);
});
