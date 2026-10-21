// Luồng kiểm duyệt Community: cấp quyền admin trực tiếp trong DB (container
// moodi_postgres của docker-compose), rồi xem báo cáo, gỡ nội dung, khoá tài khoản,
// và kiểm tra audit log.
import { execSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
const BASE=process.env.BASE||'http://localhost:3100/api'; const R=randomBytes(3).toString('hex'); const rid=()=>randomBytes(10).toString('hex');
const req=async(m,p,t,b)=>{const r=await fetch(BASE+p,{method:m,headers:{'Content-Type':'application/json',...(t?{Authorization:'Bearer '+t}:{})},body:b&&JSON.stringify(b)});return {status:r.status,json:await r.json().catch(()=>null)}};
const reg=async n=>{const r=await req('POST','/auth/register',null,{email:`${n}${R}@t.vn`,username:`${n}${R}`,password:'Passw0rd!x'});return {t:r.json.accessToken,id:r.json.user.id}};
const c=(u,action,d={},w)=>req('POST','/community',u.t,{action,...d,...(w?{requestId:rid()}:{})});
const M=await reg('mod'), U=await reg('usr'), V=await reg('vic');
execSync(`docker exec moodi_postgres psql -U postgres -d moodi_db -c "UPDATE users SET \\"communityAdmin\\"=true WHERE id='${M.id}'"`);
for (const [u,n] of [[M,'Mod'],[U,'Usr'],[V,'Vic']]) await c(u,'saveProfile',{name:n,bio:''},true);
const p=await c(U,'createPost',{space:'public',text:'nội dung xấu',mood:'',intent:''},true);
const r=await c(V,'report',{space:'public',postId:p.json.id,reason:'xúc phạm'},true);
const list=await c(M,'reports');
const rep=list.json.items.find(x=>x.reason==='xúc phạm');
console.log('admin xem báo cáo:', list.status, !!rep);
const rm=await c(M,'moderate',{reportId:rep.id,kind:'remove'},true);
const gone=await c(V,'post',{space:'public',postId:p.json.id});
console.log('gỡ nội dung:', rm.status, '→ bài:', gone.status);
const sus=await c(M,'moderate',{reportId:rep.id,kind:'suspend'},true);
const blocked=await c(U,'feed',{space:'public'});
console.log('khoá tài khoản:', sus.status, '→ người bị khoá:', blocked.status, blocked.json?.message);
const audit=execSync(`docker exec moodi_postgres psql -U postgres -d moodi_db -tAc "SELECT kind FROM community_audit WHERE moderator='${M.id}' ORDER BY \\"createdAt\\""`).toString().trim().split('\n');
console.log('audit log:', audit.join(','));
const okAll = list.status === 200 && !!rep && rm.status === 200 && gone.status === 404 &&
  sus.status === 200 && blocked.status === 403 && audit.join(',') === 'reviewReports,remove,suspend';
console.log(okAll ? 'moderation: pass' : 'moderation: FAIL');
process.exit(okAll ? 0 : 1);
