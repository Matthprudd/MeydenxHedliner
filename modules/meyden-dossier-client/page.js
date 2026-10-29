import {db,initShell,loadRows,upsert,remove,watch,safe,notice} from '../../shared/sync.js';
const $=id=>document.getElementById(id);let user,profile={},requests=[],dossiers=[],isAdmin=false;
async function reload(){const [p,r,d]=await Promise.all([db().from('meyden_profiles').select('*').eq('user_id',user.id).maybeSingle(),db().from('meyden_booking_requests').select('*').eq('requester_id',user.id).order('updated_at',{ascending:false}).limit(100),db().from('meyden_dossiers').select('*').eq('owner_id',user.id).order('updated_at',{ascending:false}).limit(100)]);if(p.error)throw p.error;if(r.error)throw r.error;if(d.error)throw d.error;profile=p.data||{};requests=r.data||[];dossiers=d.data||[];
for(const k of ['full_name','organization','contact_email','phone','project_name','project_notes'])$('profile').elements.namedItem(k).value=profile[k]||'';
$('requests').innerHTML=requests.length?requests.map(x=>'<div class="item"><b>'+safe(x.subject)+'</b> · '+safe(x.requested_date)+'<p>Statut : '+safe(x.status)+'</p><p>'+safe(x.details)+'</p></div>').join(''):'<p>Vous n’avez pas de demande en cours.</p>';
$('dossiers').innerHTML=dossiers.length?dossiers.map(x=>'<div class="item"><b>'+safe(x.name)+'</b> <span class="pill">'+safe(x.status)+'</span><p>'+safe(x.needs)+'</p><p>'+safe(x.notes)+'</p>'+(x.owner_id===user.id?'<button class="ghost" data-delete="'+safe(x.id)+'">Supprimer</button>':'')+'</div>').join(''):'<p>Votre liste de projets est vide.</p>'}
async function reloadApprovals(){
 if(!isAdmin)return;
 const r=await db().from('meyden_access').select('user_id,email,role,approved,created_at').order('created_at',{ascending:false}).limit(200);
 if(r.error)throw r.error;
 $('pendingUsers').innerHTML=(r.data||[]).map(x=>'<div class="item"><b>'+safe(x.email||x.user_id)+'</b><p>'+safe(x.user_id)+'</p><label>Rôle <select data-role="'+safe(x.user_id)+'">'+['client','artist','staff','admin'].map(y=>'<option value="'+y+'" '+(y===x.role?'selected':'')+'>'+y+'</option>').join('')+'</select></label><button data-approve="'+safe(x.user_id)+'">'+(x.approved?'Enregistrer le rôle':'Approuver ce compte')+'</button> <span class="pill">'+(x.approved?'Autorisé':'En attente')+'</span></div>').join('')||'<p>Aucun compte trouvé.</p>';
}
initShell(async(u,access)=>{user=u;isAdmin=access.role==='admin';$('approvals').hidden=!isAdmin;const refresh=async()=>{try{await reload();await reloadApprovals()}catch(err){notice(err.message)}};await refresh();return watch(['meyden_booking_requests','meyden_dossiers','meyden_access'],refresh)});
$('pendingUsers').onclick=async e=>{const b=e.target.closest('[data-approve]');if(!b||!isAdmin)return;
 const id=b.dataset.approve,role=$('pendingUsers').querySelector('select[data-role="'+id+'"]').value;
 if(id===user.id&&role!=='admin'){notice('Vous ne pouvez pas retirer votre propre rôle administrateur depuis cet écran.');return;}
 try{const r=await db().from('meyden_access').update({role,approved:true}).eq('user_id',id);if(r.error)throw r.error;notice('Accès MEYDEN mis à jour.');await reloadApprovals()}catch(err){notice(err.message)}
};
$('profile').onsubmit=async e=>{e.preventDefault();let data=Object.fromEntries(new FormData(e.target));data.user_id=user.id;try{const r=await db().from('meyden_profiles').upsert(data,{onConflict:'user_id'});if(r.error)throw r.error;notice('Dossier personnel synchronisé.');await reload()}catch(err){notice(err.message)}};
$('newDossier').onsubmit=async e=>{e.preventDefault();let d=Object.fromEntries(new FormData(e.target));d.owner_id=user.id;try{await upsert('meyden_dossiers',d);e.target.reset();notice('Projet enregistré.');await reload()}catch(err){notice(err.message)}};
$('dossiers').onclick=async e=>{const b=e.target.closest('[data-delete]');if(!b||!confirm('Supprimer ce dossier ?'))return;try{await remove('meyden_dossiers',b.dataset.delete);notice('Dossier supprimé.');await reload()}catch(err){notice(err.message)}};