'use strict';
const {test,after}=require('node:test');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const fs=require('node:fs');
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getFirestore,Timestamp}=require('firebase-admin/firestore');
const {getStorage}=require('firebase-admin/storage');
const {initializeTestEnvironment,assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc}=require('firebase/firestore');
const {ref,getBytes,uploadBytes}=require('firebase/storage');
const {createCommunityService,pairId}=require('../community');
const project=process.env.GCLOUD_PROJECT;
if(project!=='demo-moodi-security'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8180'||
  process.env.FIREBASE_STORAGE_EMULATOR_HOST!=='127.0.0.1:9298')throw Error('Community tests require isolated demo Firestore + Storage emulators.');
const app=initializeApp({projectId:project,storageBucket:`${project}.appspot.com`},'community-tests');
const db=getFirestore(app),bucket=getStorage(app).bucket();
const service=createCommunityService(db,bucket);
const uid=prefix=>`${prefix}_${randomUUID().replaceAll('-','')}`;
const request=(user,action,data={},admin=false)=>({auth:user?{uid:user,token:{communityAdmin:admin}}:null,data:{action,...data}});
const read=(user,action,data={})=>service.handle(request(user,action,data));
const write=(user,action,data={},admin=false)=>service.handle(request(user,action,{requestId:randomUUID(),...data},admin));
const register=async(name)=>{const user=uid(name);await write(user,'saveProfile',{name,bio:''});return user;};
const denied=promise=>assert.rejects(promise,e=>['permission-denied','not-found'].includes(e.code));
after(async()=>deleteApp(app));

test('community rejects unauthenticated and injected schema fields',async()=>{
  await assert.rejects(read(null,'bootstrap'),{code:'unauthenticated'});
  const a=await register('Schema');
  for(const data of [{text:'x',author:'victim'},{text:'x',role:'admin'},{text:'x'.repeat(4001)},{text:''}]){
    await assert.rejects(write(a,'createPost',{space:'public',...data}),{code:'invalid-argument'});
  }
  await assert.rejects(read(a,'feed',{space:'../users'}),{code:'invalid-argument'});
  await denied(read(a,'reports'));
});

test('public posts, pagination, comments and idempotent reactions work without exposing private profiles',async()=>{
  const a=await register('Alice'),b=await register('Bob');
  const requestId=randomUUID();
  const created=await write(a,'createPost',{space:'public',text:'Hôm nay bình yên',mood:'Bình yên',intent:'',requestId});
  assert.equal((await write(a,'createPost',{space:'public',text:'Hôm nay bình yên',mood:'Bình yên',intent:'',requestId})).id,created.id);
  await assert.rejects(write(a,'createPost',{space:'public',text:'changed',requestId}),{code:'already-exists'});
  const scope={space:'public',postId:created.id};
  assert.equal((await read(b,'post',scope)).post.author,a);
  assert.equal((await read(b,'profile',{target:a})).profile.email,undefined);
  const handle=(await read(a,'bootstrap')).me.handle;
  assert.equal((await read(b,'search',{handle})).profile.id,a);
  await write(b,'react',{...scope,enabled:true});await write(b,'react',{...scope,enabled:true});
  assert.equal((await read(a,'post',scope)).post.likes,1);
  await write(b,'react',{...scope,enabled:false});assert.equal((await read(a,'post',scope)).post.likes,0);
  const comment=await write(b,'comment',{...scope,text:'Mình nghe bạn'});
  await denied(write(a,'deleteComment',{...scope,commentId:comment.id}));
  await write(b,'deleteComment',{...scope,commentId:comment.id});
  assert.equal((await read(a,'comments',scope)).items.length,0);
  await write(a,'toggleComments',{...scope,enabled:false});
  await denied(write(b,'comment',{...scope,text:'Không được'}));
  await denied(write(b,'deletePost',scope));
  // Identical timestamps exercise the secondary document-ID cursor.
  const stamp=Timestamp.now(),batch=db.batch();
  for(let i=0;i<25;i++)batch.set(db.doc(`community_spaces/public/posts/page_${a}_${i.toString().padStart(2,'0')}`),{
    author:a,authorName:'Alice',text:'Page',createdAt:stamp,deleted:false,ready:true,likes:0,commentsOpen:true,imagePath:'',mood:'',intent:'',
  });
  await batch.commit();
  const page1=await read(b,'feed',{space:'public',author:a});
  const page2=await read(b,'feed',{space:'public',author:a,cursor:page1.cursor});
  assert.equal(page1.items.length,20);assert.equal(page2.items.length,6);
  assert.equal(new Set([...page1.items,...page2.items].map(p=>p.id)).size,26);
  await write(a,'deletePost',scope);await denied(read(b,'post',scope));
});

test('group invitation, membership revocation, private images, transfer and close',async()=>{
  const a=await register('Owner'),b=await register('Member'),c=await register('Outsider');
  const group=await write(a,'createGroup',{name:'Nhóm riêng',description:'Gia đình'}),space=group.id;
  await denied(read(c,'feed',{space}));await denied(write(c,'groupAction',{space,kind:'accept'}));
  await write(a,'invite',{space,target:b});
  const invites=(await read(b,'groups')).invites;assert.equal(invites.length,1);assert.equal(invites[0].members,undefined);
  await denied(read(b,'feed',{space}));
  await write(b,'groupAction',{space,kind:'accept'});
  const image=(await require('sharp')({create:{width:8,height:8,channels:3,background:'#eee'}}).jpeg().toBuffer()).toString('base64');
  const post=await write(a,'createPost',{space,text:'Ảnh riêng',image});
  const scope={space,postId:post.id};
  assert.ok((await read(b,'image',scope)).image.length>0);
  await denied(read(c,'image',scope));await denied(write(b,'invite',{space,target:c}));
  await write(a,'groupAction',{space,kind:'remove',target:b});
  await denied(read(b,'image',scope));await denied(read(b,'feed',{space}));await denied(write(b,'comment',{...scope,text:'x'}));
  await write(a,'invite',{space,target:b});await write(b,'groupAction',{space,kind:'accept'});
  await denied(write(a,'groupAction',{space,kind:'leave'}));
  await write(a,'groupAction',{space,kind:'transfer',target:b});
  await denied(write(a,'groupAction',{space,kind:'remove',target:b}));
  await write(a,'groupAction',{space,kind:'leave'});await denied(read(a,'image',scope));
  await write(b,'deletePost',scope); // owner moderation
  await write(b,'groupAction',{space,kind:'close'});await denied(read(b,'feed',{space}));
});

test('friend state machine, private chat, image authorization and blocking',async()=>{
  const a=await register('FriendA'),b=await register('FriendB'),c=await register('FriendC');
  await denied(write(a,'sendMessage',{target:b,text:'Before friendship'}));
  await write(a,'friendship',{target:b,kind:'request'});
  await denied(write(a,'friendship',{target:b,kind:'accept'}));
  await denied(write(b,'friendship',{target:a,kind:'request'}));
  await write(b,'friendship',{target:a,kind:'accept'});
  const requestId=randomUUID();
  const m=await write(a,'sendMessage',{target:b,text:'Chào bạn',requestId});
  assert.equal((await write(a,'sendMessage',{target:b,text:'Chào bạn',requestId})).id,m.id);
  assert.equal((await read(b,'messages',{target:a})).items.length,1);
  await denied(read(c,'messages',{target:a}));
  const image=(await require('sharp')({create:{width:8,height:8,channels:3,background:'#abc'}}).png().toBuffer()).toString('base64');
  const photo=await write(a,'sendMessage',{target:b,text:'',image});
  assert.ok((await read(b,'image',{target:a,messageId:photo.id})).image);
  await denied(read(c,'image',{target:a,messageId:photo.id}));
  await write(b,'friendship',{target:a,kind:'unfriend'});
  await denied(write(a,'sendMessage',{target:b,text:'Blocked by unfriend'}));
  assert.equal((await read(a,'messages',{target:b})).items.length,2);
  await write(a,'friendship',{target:b,kind:'request'});await write(b,'friendship',{target:a,kind:'accept'});
  await write(b,'friendship',{target:a,kind:'block'});
  await denied(write(a,'sendMessage',{target:b,text:'Blocked'}));await denied(write(a,'friendship',{target:b,kind:'request'}));
  await write(b,'friendship',{target:a,kind:'unblock'});
  await denied(write(a,'sendMessage',{target:b,text:'Unblock does not restore friendship'}));
});

test('concurrent requests and repeated send do not duplicate relationships or messages',async()=>{
  const a=await register('RaceA'),b=await register('RaceB');
  const results=await Promise.allSettled([write(a,'friendship',{target:b,kind:'request'}),write(b,'friendship',{target:a,kind:'request'})]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const r=(await db.doc(`community_connections/${pairId(a,b)}`).get()).data();
  const receiver=r.requestedBy===a?b:a;
  await write(receiver,'friendship',{target:r.requestedBy,kind:'accept'});
  const payload={target:b,text:'Only once',requestId:randomUUID()};
  const sent=await Promise.all([write(a,'sendMessage',payload),write(a,'sendMessage',payload)]);
  assert.equal(sent[0].id,sent[1].id);assert.equal((await read(b,'messages',{target:a})).items.length,1);
});

test('reports are admin-only, moderation removes content and records audit; suspended user cannot post',async()=>{
  const a=await register('Reported'),b=await register('Reporter'),admin=await register('Moderator');
  const post=await write(a,'createPost',{space:'public',text:'Reported text'});
  await write(b,'report',{space:'public',postId:post.id,reason:'Test report'});
  await denied(read(b,'reports'));
  const reports=await service.handle(request(admin,'reports',{},true));
  const report=reports.items.find(r=>r.target===a);assert.ok(report);
  await denied(write(b,'moderate',{reportId:report.id,kind:'remove'}));
  await write(admin,'moderate',{reportId:report.id,kind:'remove'},true);
  await denied(read(b,'post',{space:'public',postId:post.id}));
  await write(admin,'moderate',{reportId:report.id,kind:'suspend'},true);
  await denied(write(a,'createPost',{space:'public',text:'After suspend'}));
  assert.ok((await db.collection('community_audit').where('reportId','==',report.id).get()).size>=2);
  await write(admin,'moderate',{reportId:report.id,kind:'restore'},true);
  await write(a,'createPost',{space:'public',text:'Restored'});
});

test('server-side rate limit is enforced',async()=>{
  const a=await register('Limited');
  await db.doc(`community_limits/${a}_write`).set({start:Date.now(),count:40});
  await assert.rejects(write(a,'createPost',{space:'public',text:'Too fast'}),{code:'resource-exhausted'});
});

test('direct Firestore and Storage clients cannot bypass the gateway',async()=>{
  const env=await initializeTestEnvironment({projectId:project,
    firestore:{host:'127.0.0.1',port:8180,rules:fs.readFileSync('../firestore.rules','utf8')},
    storage:{host:'127.0.0.1',port:9298,rules:fs.readFileSync('../storage.rules','utf8')}});
  try{
    const user=env.authenticatedContext('intruder');
    for(const path of ['community_profiles/alice','community_groups/group','community_spaces/public/posts/post','community_connections/pair/messages/message','community_reports/report']){
      await assertFails(getDoc(doc(user.firestore(),path)));await assertFails(setDoc(doc(user.firestore(),path),{owner:'intruder'}));
    }
    const storage=user.storage(`gs://${project}.appspot.com`);
    await assertFails(uploadBytes(ref(storage,'community-media/fake.jpg'),new Uint8Array([1,2])));
    await assertFails(getBytes(ref(storage,'community-media/fake.jpg')));
  }finally{await env.cleanup();}
});

test('real callable HTTP authenticates, registers a profile and serves the public feed',async()=>{
  const signup=await fetch('http://127.0.0.1:9199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({returnSecureToken:true})});
  const token=(await signup.json()).idToken;
  const call=async(data,auth=true)=>{
    const response=await fetch(`http://127.0.0.1:5101/${project}/asia-southeast1/community`,{method:'POST',headers:{'Content-Type':'application/json',...(auth?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify({data})});
    return {status:response.status,body:await response.json()};
  };
  assert.equal((await call({action:'bootstrap'},false)).status,401);
  const saved=await call({action:'saveProfile',name:'HTTP user',bio:'',requestId:randomUUID()});
  assert.equal(saved.status,200,JSON.stringify(saved.body));
  assert.equal((await call({action:'bootstrap'})).body.result.me.name,'HTTP user');
  assert.equal((await call({action:'feed',space:'public'})).status,200);
});

test('mood filter validates enum, paginates matching posts and supports author filter',async()=>{
  const a=await register('MoodFilter'),b=await register('FilterReader');
  const batch=db.batch(),stamp=Timestamp.now();
  for(let i=0;i<26;i++)batch.set(db.doc(`community_spaces/public/posts/filter_${a}_${i.toString().padStart(2,'0')}`),{
    author:a,authorName:'Filter',text:'Test',createdAt:stamp,deleted:false,ready:true,likes:0,commentsOpen:true,imagePath:'',mood:i===25?'Buồn':'Vui vẻ',intent:'',
  });
  await batch.commit();
  const p1=await read(b,'feed',{space:'public',author:a,mood:'Vui vẻ'});
  const p2=await read(b,'feed',{space:'public',author:a,mood:'Vui vẻ',cursor:p1.cursor});
  assert.equal(p1.items.length,20);assert.equal(p2.items.length,5);
  assert.equal(new Set([...p1.items,...p2.items].map(p=>p.id)).size,25);
  assert.ok([...p1.items,...p2.items].every(p=>p.mood==='Vui vẻ'));
  await assert.rejects(read(b,'feed',{space:'public',mood:'unknown'}),{code:'invalid-argument'});
});

test('inbox preview and unread clear after reading and respect moderation',async()=>{
  const a=await register('InboxA'),b=await register('InboxB'),admin=await register('InboxAdmin');
  await write(a,'friendship',{target:b,kind:'request'});await write(b,'friendship',{target:a,kind:'accept'});
  const message=await write(a,'sendMessage',{target:b,text:'Tin mới'});
  let connection=(await read(b,'connections')).items.find(r=>r.profile.id===a);
  assert.equal(connection.preview,'Tin mới');assert.equal(connection.unread,true);assert.equal(typeof connection.lastMessageAt,'number');
  await read(b,'messages',{target:a});connection=(await read(b,'connections')).items.find(r=>r.profile.id===a);assert.equal(connection.unread,false);
  await write(b,'report',{target:a,messageId:message.id,reason:'Test moderation'});
  const report=(await service.handle(request(admin,'reports',{},true))).items.find(r=>r.target===a);
  await write(admin,'moderate',{reportId:report.id,kind:'remove'},true);
  connection=(await read(b,'connections')).items.find(r=>r.profile.id===a);assert.equal(connection.preview,'Tin nhắn đã được gỡ');
});
