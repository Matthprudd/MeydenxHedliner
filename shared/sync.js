import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.118.0';
import { MEYDEN_CONFIG } from './config.js';

let client = null;
export function configured() {
  return /^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(MEYDEN_CONFIG.url) &&
    (MEYDEN_CONFIG.publishableKey.startsWith('sb_publishable_') || MEYDEN_CONFIG.publishableKey.startsWith('eyJ'));
}
export function db() {
  if (!configured()) throw Error('La base de données privée MEYDEN n’est pas encore raccordée.');
  if (!client) client = createClient(MEYDEN_CONFIG.url, MEYDEN_CONFIG.publishableKey, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });
  return client;
}
export async function sessionContext() {
  const { data: { user }, error } = await db().auth.getUser();
  if (error || !user) return { user: null, access: null };
  const q = await db().from('meyden_access').select('role,approved').eq('user_id', user.id).maybeSingle();
  if (q.error) throw q.error;
  return { user, access: q.data?.approved ? q.data : null };
}
export async function loadRows(table, select='*') {
  const rows=[];
  for(let start=0;start<5000;start+=1000){
    const r = await db().from(table).select(select).order('updated_at', { ascending: false }).range(start,start+999);
    if(r.error)throw r.error;
    rows.push(...(r.data||[]));
    if((r.data||[]).length<1000)break;
  }
  return rows;
}
export async function upsert(table, payload, id) {
  const query = id ? db().from(table).update(payload).eq('id', id) : db().from(table).insert(payload);
  const r=await query.select().single();
  if (r.error) throw r.error;
  return r.data;
}
export async function remove(table,id) {
  const r=await db().from(table).delete().eq('id',id);
  if(r.error)throw r.error;
}
export function watch(tables, reload) {
  const client=db();
  const channel=client.channel('meyden-sync-'+tables.join('-'));
  for(const table of tables){
    for(const event of ['INSERT','UPDATE'])channel.on('postgres_changes',{event,schema:'public',table},()=>reload());
  }
  channel.subscribe();
  // Rafraîchissement aussi au retour sur l'onglet; les événements DELETE ne sont pas diffusés aux clients.
  const onVisible=()=>{if(document.visibilityState==='visible')reload()};
  document.addEventListener('visibilitychange',onVisible);
  const poll=setInterval(()=>{if(document.visibilityState==='visible')reload()},60000);
  return ()=>{clearInterval(poll);document.removeEventListener('visibilitychange',onVisible);client.removeChannel(channel)};
}
export const safe = (value) => String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function notice(text){const x=document.getElementById('notice');if(x)x.textContent=text||'';}
export function initShell(onReady){
  const entry=document.getElementById('entry'),working=document.getElementById('working');
  if(!configured()){
    entry.innerHTML='<div class="card"><h2>Synchronisation MEYDEN en préparation</h2><p>Ce module attend la connexion à la base privée MEYDEN. Aucune donnée n’est stockée sur Hedliner.</p><p>Le quartier public actuellement en ligne reste inchangé.</p></div>';
    return;
  }
  let stop=()=>{};
  const refresh=async()=>{
    try{
      const {user,access}=await sessionContext();
      if(!user){
        working.hidden=true;
        entry.innerHTML='<div class="card"><h2>Accès MEYDEN</h2><p>Entrez votre adresse courriel pour demander ou retrouver votre accès. Un lien de connexion vous sera envoyé. Les nouveaux comptes doivent être approuvés par MEYDEN.</p><form id="signin"><label>Courriel<input name="email" type="email" required autocomplete="email" /></label><button>Recevoir mon lien d’accès</button></form></div>';
        document.getElementById('signin').onsubmit=async e=>{
          e.preventDefault();const email=String(new FormData(e.target).get('email')||'').trim();
          const result=await db().auth.signInWithOtp({email,options:{shouldCreateUser:true,emailRedirectTo:location.href.split('#')[0]}});
          notice(result.error?result.error.message:'Si cette adresse possède un accès MEYDEN, un lien a été envoyé.');
        };
        return;
      }
      if(!access){
        working.hidden=true;
        entry.innerHTML=`<div class="card"><h2>Accès en attente</h2><p>Ce compte est en attente d'approbation par MEYDEN. Copiez l'identifiant du compte et transmettez-le à l'équipe pour validation.</p><p class="tiny">Identifiant : ${safe(user.id)}</p><button id="retryAccess" class="ghost">Vérifier mon accès</button> <button id="signout">Se déconnecter</button></div>`;
        document.getElementById('retryAccess').onclick=refresh;document.getElementById('signout').onclick=async()=>{await db().auth.signOut();location.reload()};return;
      }
      entry.innerHTML='<div class="auth"><span>Session MEYDEN — '+safe(access.role)+'</span><button id="signout">Déconnexion</button></div>';
      document.getElementById('signout').onclick=async()=>{stop();await db().auth.signOut();location.reload()};
      working.hidden=false;
      stop();stop=await onReady(user,access) || (()=>{});
    }catch(e){notice('Connexion : '+e.message)}
  };
  db().auth.onAuthStateChange(()=>setTimeout(refresh,10));
  window.addEventListener('focus',()=>refresh());
  refresh();
}