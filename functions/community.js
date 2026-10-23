'use strict';
const {HttpsError} = require('firebase-functions/v2/https');
const {createHash, randomBytes} = require('node:crypto');
const {Timestamp, FieldPath} = require('firebase-admin/firestore');
const fail = (code, message) => { throw new HttpsError(code, message); };
const check = (ok, message = 'Bạn không có quyền thực hiện thao tác này.') => {
  if (!ok) fail('permission-denied', message);
};
const id = value => {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(value)) fail('invalid-argument', 'Mã không hợp lệ.');
  return value;
};
const str = (value, max, required = false) => {
  if (typeof value !== 'string' || value.length > max || (required && !value.trim())) fail('invalid-argument', 'Nội dung trống hoặc quá dài.');
  return value.trim();
};
const normalizeHandle = value => {
  if (typeof value !== 'string') fail('invalid-argument', 'Mã bạn bè không hợp lệ.');
  const handle = value.trim().toLowerCase().replace(/^@/, '').replace(/[\s-]/g, '');
  if (!/^[a-z0-9]{12}$/.test(handle)) fail('invalid-argument', 'Mã bạn bè phải có đúng 12 chữ hoặc số.');
  return handle;
};
const pairId = (a, b) => createHash('sha256').update(JSON.stringify([a, b].sort())).digest('hex');
const schemas = {
  bootstrap: [], profile: ['target'], saveProfile: ['name', 'bio'], search: ['handle'],
  feed: ['space', 'cursor', 'author', 'mood'], post: ['space', 'postId'],
  createPost: ['space', 'text', 'mood', 'intent', 'image'],
  deletePost: ['space', 'postId'], toggleComments: ['space', 'postId', 'enabled'],
  react: ['space', 'postId', 'enabled'], comments: ['space', 'postId', 'cursor'],
  comment: ['space', 'postId', 'text'], deleteComment: ['space', 'postId', 'commentId'],
  groups: [], createGroup: ['name', 'description'], group: ['space'],
  invite: ['space', 'target'], groupAction: ['space', 'kind', 'target'],
  connections: [], friendship: ['target', 'kind'], messages: ['target', 'cursor'],
  sendMessage: ['target', 'text', 'image'], image: ['space', 'postId', 'target', 'messageId'],
  report: ['space', 'postId', 'commentId', 'target', 'messageId', 'reason'],
  notifications: [], markNotificationsRead: [],
  reports: ['cursor'], reportImage: ['reportId'], moderate: ['reportId', 'kind'],
};
const mutations = new Set(['saveProfile','createPost','deletePost','toggleComments','react','comment',
  'deleteComment','createGroup','invite','groupAction','friendship','sendMessage','report','moderate','markNotificationsRead']);
const moods = ['', 'Vui vẻ','Bình yên','Buồn','Lo lắng','Áp lực','Tức giận','Biết ơn','Mệt mỏi'];
const intents = ['', 'Chỉ muốn được lắng nghe','Muốn nghe lời khuyên','Có ai từng trải qua không?','Chia sẻ chuyện vui'];
function validateRequest(request) {
  if (!request.auth?.uid) fail('unauthenticated', 'Hãy đăng nhập để vào cộng đồng.');
  const d = request.data;
  if (!d || Array.isArray(d) || typeof d !== 'object' || !Object.hasOwn(schemas, d.action)) fail('invalid-argument', 'Thao tác không hợp lệ.');
  const allowed = ['action', ...(mutations.has(d.action) ? ['requestId'] : []), ...schemas[d.action]];
  if (Object.keys(d).some(k => !allowed.includes(k))) fail('invalid-argument', 'Dữ liệu chứa trường không được phép.');
  if (mutations.has(d.action)) id(d.requestId);
  for (const k of ['space','postId','commentId','target','messageId','reportId','author']) if (d[k] !== undefined) id(d[k]);
  if (d.mood !== undefined && (typeof d.mood !== 'string' || !moods.includes(d.mood))) fail('invalid-argument','Cảm xúc không hợp lệ.');
  if (d.cursor !== undefined && d.cursor !== null) {
    if (typeof d.cursor !== 'object' || Object.keys(d.cursor).some(k => !['seconds','nanoseconds','id'].includes(k)) ||
      !Number.isInteger(d.cursor.seconds) || !Number.isInteger(d.cursor.nanoseconds) || d.cursor.nanoseconds < 0 || d.cursor.nanoseconds > 999999999) fail('invalid-argument', 'Trang không hợp lệ.');
    id(d.cursor.id);
  }
  return d;
}
const serialize = doc => {
  const data = doc.data();
  return {id: doc.id, ...data, createdAt: data.createdAt?.toMillis?.() ?? null};
};
async function page(tx, query, cursor) {
  query = query.orderBy('createdAt', 'desc').orderBy(FieldPath.documentId(), 'desc');
  if (cursor) query = query.startAfter(new Timestamp(cursor.seconds, cursor.nanoseconds), cursor.id);
  const result = await tx.get(query.limit(20));
  const last = result.docs.at(-1);
  return {items: result.docs.map(serialize), cursor: result.size === 20 ? {
    seconds: last.data().createdAt.seconds, nanoseconds: last.data().createdAt.nanoseconds, id: last.id,
  } : null};
}

// All community documents are server-only. Authorization AND writes share a
// transaction, including membership changes, blocks and message sends.
function createCommunityService(db, bucket) {
  const profileRef = uid => db.doc(`community_profiles/${uid}`);
  const relationRef = (a,b) => db.doc(`community_connections/${pairId(a,b)}`);
  async function handle(request) {
    const d = validateRequest(request), uid = request.auth.uid;
    const write = mutations.has(d.action);
    const fingerprint = write ? createHash('sha256').update(JSON.stringify(d)).digest('hex') : '';
    // Charge every authenticated operation before image decoding or document reads.
    // Retries count too; authorization failures cannot bypass the per-user budget.
    await db.runTransaction(async tx => {
      const ref = db.doc(`community_limits/${uid}_${write ? 'write' : 'read'}`);
      const rate = (await tx.get(ref)).data();
      const now = Date.now(), count = rate && now-rate.start<60000 ? rate.count : 0;
      if(count >= (write ? 40 : 240)) fail('resource-exhausted','Bạn thao tác hơi nhanh. Hãy thử lại sau một phút.');
      tx.set(ref,{start:count===0?now:rate.start,count:count+1});
    });
    let photo = null;
    if (d.image !== undefined && d.image !== null && d.image !== '') {
      str(d.image, 1400000, true);
      if (!/^[A-Za-z0-9+/]+={0,2}$/.test(d.image)) fail('invalid-argument', 'Ảnh không hợp lệ.');
      const bytes = Buffer.from(d.image, 'base64');
      const jpeg = bytes[0]===0xff && bytes[1]===0xd8 && bytes[2]===0xff;
      const png = bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
      if(!jpeg && !png) fail('invalid-argument','Chỉ hỗ trợ ảnh JPEG hoặc PNG.');
      try {
        photo = await require('sharp')(bytes, {limitInputPixels: 16000000})
          .rotate().resize(1280,1280,{fit:'inside',withoutEnlargement:true}).jpeg({quality:75}).toBuffer();
      } catch (_) { fail('invalid-argument', 'Không đọc được ảnh. Hãy chọn ảnh JPEG hoặc PNG khác.'); }
      if (photo.length > 900000) fail('invalid-argument', 'Ảnh quá lớn. Hãy chọn ảnh nhỏ hơn.');
    }
    const result = await db.runTransaction(async tx => {
      const me = (await tx.get(profileRef(uid))).data();
      const isAdmin = request.auth.token?.communityAdmin === true;
      if (me?.suspended && !isAdmin) fail('permission-denied', 'Tài khoản cộng đồng đang bị tạm khóa.');
      const receipt = write ? db.doc(`community_operations/${uid}/items/${d.requestId}`) : null;
      if (receipt) {
        const previous = (await tx.get(receipt)).data();
        if (previous) {
          if (previous.fingerprint !== fingerprint) fail('already-exists', 'Yêu cầu đã được sử dụng cho nội dung khác.');
          return previous.result;
        }
      }
      const writes = [];
      const set = (ref, data, options) => writes.push(() => tx.set(ref, data, options || {}));
      const update = (ref, data) => writes.push(() => tx.update(ref, data));
      const remove = ref => writes.push(() => tx.delete(ref));
      const stamp = Timestamp.now();
      const profile = async target => {
        const p = (await tx.get(profileRef(target))).data();
        if (!p) fail('not-found', 'Người này chưa tạo hồ sơ cộng đồng.');
        return {id: target, name:p.name, bio:p.bio, handle:p.handle};
      };
      const relation = async target => {
        id(target); check(target !== uid, 'Không thể thực hiện với chính mình.');
        return (await tx.get(relationRef(uid,target))).data() || {
          members:[uid,target].sort(), requestedBy:'', status:'none', blockedBy:[], hasMessages:false,
        };
      };
      const unblocked = rel => check(rel.blockedBy.length === 0, 'Không thể tương tác khi một trong hai người đã chặn.');
      const spaceAccess = async space => {
        id(space);
        if (space === 'public') return null;
        const group = (await tx.get(db.doc(`community_groups/${space}`))).data();
        check(group && !group.closed && group.members.includes(uid), 'Bạn không còn là thành viên của nhóm này.');
        return group;
      };
      const postAccess = async () => {
        const group = await spaceAccess(d.space);
        const ref = db.doc(`community_spaces/${d.space}/posts/${id(d.postId)}`);
        const post = (await tx.get(ref)).data();
        if (!post || post.deleted || post.ready === false) fail('not-found', 'Bài viết đã được gỡ.');
        if (post.author !== uid) {
          const rel = await relation(post.author);
          check(!rel.blockedBy.includes(uid), 'Bạn đã chặn tác giả này.');
        }
        return {group,ref,post};
      };
      const content = () => {
        const text = str(d.text ?? '',4000);
        if (!text && !photo) fail('invalid-argument','Hãy viết vài dòng hoặc thêm một ảnh.');
        return text;
      };
      const ownId = () => createHash('sha256').update(`${uid}:${d.requestId}`).digest('hex');
      let out = {};
      if (d.action === 'bootstrap') {
        let pending = 0, unread = 0, invites = 0, notifications = 0;
        if (me) {
          const connections = await tx.get(db.collection('community_connections').where('members','array-contains',uid).limit(200));
          for (const doc of connections.docs) {
            const r=doc.data();
            if(r.status==='pending' && r.requestedBy!==uid && !r.blockedBy.length) pending++;
            if(r.lastSender && r.lastSender!==uid && !r.blockedBy.length) {
              const mark=(await tx.get(doc.ref.collection('reads').doc(uid))).data();
              if(!mark || r.lastMessageAt.toMillis()>mark.at.toMillis()) unread++;
            }
          }
          invites=(await tx.get(db.collection('community_groups').where('invited','array-contains',uid).limit(100))).size;
          notifications=(await tx.get(db.collection('community_notifications').where('recipient','==',uid).where('read','==',false).limit(100))).size;
        }
        out = {me: me ? await profile(uid) : null, admin:isAdmin,pending,unread,invites,notifications};
      } else if (d.action === 'saveProfile') {
        const name = str(d.name,40,true), bio = str(d.bio ?? '',160);
        const handle = me?.handle || randomBytes(6).toString('hex');
        const handleRef = db.doc(`community_handles/${handle}`);
        if (!me) check(!(await tx.get(handleRef)).exists, 'Hãy thử tạo hồ sơ lại.');
        set(profileRef(uid), {name,bio,handle,createdAt:me?.createdAt || stamp,suspended:me?.suspended || false});
        if (!me) set(handleRef,{uid});
      } else {
        check(!!me,'Hãy tạo biệt danh cộng đồng trước.');
        switch (d.action) {
          case 'profile': {
            const p = await profile(id(d.target));
            out = {profile:p, relation:d.target === uid ? null : await relation(d.target)};
            break;
          }
          case 'search': {
            const handle = normalizeHandle(d.handle);
            const found = (await tx.get(db.doc(`community_handles/${id(handle)}`))).data();
            out = {profile:found ? await profile(found.uid) : null}; break;
          }
          case 'feed': {
            const group = await spaceAccess(d.space);
            let query = db.collection(`community_spaces/${d.space}/posts`);
            if (d.author) query = query.where('author','==',d.author);
            if (d.mood) query = query.where('mood','==',d.mood);
            out = await page(tx,query,d.cursor);
            const blocked = await tx.get(db.collection('community_connections').where('blockedBy','array-contains',uid));
            const hidden = new Set(blocked.docs.flatMap(doc => doc.data().members.filter(x=>x!==uid)));
            out.items = out.items.filter(p=>!p.deleted && p.ready !== false && !hidden.has(p.author));
            for (const p of out.items) { p.liked = (await tx.get(db.doc(`community_spaces/${d.space}/posts/${p.id}/reactions/${uid}`))).exists; p.canDelete = p.author === uid || group?.owner === uid || isAdmin; }
            break;
          }
          case 'post': {
            const {group,ref,post} = await postAccess();
            out = {post:{...post,canDelete:post.author===uid||group?.owner===uid||isAdmin,id:ref.id,createdAt:post.createdAt.toMillis(),liked:(await tx.get(ref.collection('reactions').doc(uid))).exists}}; break;
          }
          case 'createPost': {
            await spaceAccess(d.space);
            const text = content(), mood = str(d.mood ?? '',30), intent = str(d.intent ?? '',60);
            if (!moods.includes(mood) || !intents.includes(intent)) fail('invalid-argument','Cảm xúc hoặc lựa chọn phản hồi không hợp lệ.');
            const postId = ownId();
            const imagePath = photo ? `community-media/posts/${d.space}/${postId}.jpg` : '';
            set(db.doc(`community_spaces/${d.space}/posts/${postId}`),{author:uid,authorName:me.name,text,mood,intent,imagePath,createdAt:stamp,deleted:false,ready:!photo,commentsOpen:true,likes:0});
            out = {id:postId,...(photo ? {_upload:imagePath} : {})}; break;
          }
          case 'deletePost': case 'toggleComments': case 'react': case 'comment': case 'comments': case 'deleteComment': {
            const {group,ref,post} = await postAccess();
            if (d.action === 'deletePost') {
              check(post.author===uid || group?.owner===uid || isAdmin);
              update(ref,{deleted:true,text:'',imagePath:''}); out = {_cleanup:post.imagePath};
            } else if (d.action === 'toggleComments') {
              check(post.author===uid); if (typeof d.enabled!=='boolean') fail('invalid-argument','Lựa chọn không hợp lệ.');
              update(ref,{commentsOpen:d.enabled});
            } else if (d.action === 'react') {
              if (post.author!==uid) unblocked(await relation(post.author));
              if (typeof d.enabled!=='boolean') fail('invalid-argument','Lựa chọn không hợp lệ.');
              const r = ref.collection('reactions').doc(uid), exists=(await tx.get(r)).exists;
              out = {liked:d.enabled, likes:post.likes+(exists===d.enabled?0:(d.enabled?1:-1))};
              if (exists!==d.enabled) {
                update(ref,{likes:post.likes+(d.enabled?1:-1)});
                if (d.enabled) set(r,{createdAt:stamp}); else remove(r);
              }
            } else if (d.action === 'comment') {
              check(post.commentsOpen,'Tác giả đã tắt bình luận.');
              if (post.author!==uid) unblocked(await relation(post.author));
              const commentId=ownId();
              set(ref.collection('comments').doc(commentId),{author:uid,authorName:me.name,text:str(d.text,2000,true),createdAt:stamp,deleted:false}); out={id:commentId};
            } else if (d.action === 'deleteComment') {
              const c = ref.collection('comments').doc(id(d.commentId)), data=(await tx.get(c)).data();
              check(data && (data.author===uid || group?.owner===uid || isAdmin));
              update(c,{deleted:true,text:''});
            } else {
              out=await page(tx,ref.collection('comments'),d.cursor);
              const blocked = await tx.get(db.collection('community_connections').where('blockedBy','array-contains',uid));
              const hidden=new Set(blocked.docs.flatMap(doc=>doc.data().members.filter(x=>x!==uid)));
              out.items=out.items.filter(c=>!c.deleted&&!hidden.has(c.author)).map(c=>({...c,canDelete:c.author===uid||group?.owner===uid||isAdmin}));
            }
            break;
          }
          case 'groups': {
            const member = await tx.get(db.collection('community_groups').where('members','array-contains',uid).limit(100));
            const invites = await tx.get(db.collection('community_groups').where('invited','array-contains',uid).limit(100));
            out={items:member.docs.map(serialize).filter(g=>!g.closed),invites:invites.docs.map(doc=>({id:doc.id,name:doc.data().name,description:doc.data().description,closed:doc.data().closed})).filter(g=>!g.closed)}; break;
          }
          case 'createGroup': {
            const count=await tx.get(db.collection('community_groups').where('members','array-contains',uid).limit(100));
            check(count.size<100,'Bạn đã đạt giới hạn 100 nhóm.');
            const groupId=ownId();
            set(db.doc(`community_groups/${groupId}`),{name:str(d.name,60,true),description:str(d.description??'',240),owner:uid,members:[uid],invited:[],closed:false,createdAt:stamp}); out={id:groupId}; break;
          }
          case 'group': {
            const g=await spaceAccess(d.space); check(!!g);
            const members=[]; for (const target of g.members) members.push(await profile(target));
            const invited=[]; if(g.owner===uid) for(const target of g.invited) invited.push(await profile(target));
            out={group:{...g,id:d.space,createdAt:g.createdAt.toMillis()},members,invited}; break;
          }
          case 'invite': {
            const g=await spaceAccess(d.space); check(g?.owner===uid);
            await profile(id(d.target)); unblocked(await relation(d.target));
            check(!g.members.includes(d.target),'Người này đã ở trong nhóm.');
            check(g.invited.length<50,'Nhóm đã có đủ 50 lời mời.');
            update(db.doc(`community_groups/${d.space}`),{invited:[...new Set([...g.invited,d.target])]}); break;
          }
          case 'groupAction': {
            const ref=db.doc(`community_groups/${id(d.space)}`),g=(await tx.get(ref)).data();
            check(g&&!g.closed); const kind=str(d.kind,20,true), target=d.target;
            if (kind==='accept'||kind==='decline') {
              check(g.invited.includes(uid));
              if(kind==='accept') {
                unblocked(await relation(g.owner)); check(g.members.length<50,'Nhóm đã đủ 50 thành viên.');
                const count=await tx.get(db.collection('community_groups').where('members','array-contains',uid).limit(100));
                check(count.size<100,'Bạn đã đạt giới hạn 100 nhóm.');
              }
              update(ref,{invited:g.invited.filter(x=>x!==uid),members:kind==='accept'?[...new Set([...g.members,uid])]:g.members});
            } else if(kind==='leave') {
              check(g.members.includes(uid)&&g.owner!==uid,'Chủ nhóm cần chuyển quyền hoặc đóng nhóm trước.');
              update(ref,{members:g.members.filter(x=>x!==uid)});
            } else {
              check(g.owner===uid);
              if(kind==='remove') {check(target!==uid);update(ref,{members:g.members.filter(x=>x!==target),invited:g.invited.filter(x=>x!==target)});}
              else if(kind==='transfer') {check(g.members.includes(target)&&target!==uid);update(ref,{owner:target});}
              else if(kind==='close') update(ref,{closed:true,members:[],invited:[]});
              else fail('invalid-argument','Thao tác nhóm không hợp lệ.');
            } break;
          }
          case 'connections': {
            const query=await tx.get(db.collection('community_connections').where('members','array-contains',uid).limit(200));
            const items=[];
            for(const doc of query.docs) {
              const r=doc.data(),target=r.members.find(x=>x!==uid);
              const latest = await tx.get(doc.ref.collection('messages').orderBy('createdAt','desc').limit(20));
              const message = latest.docs.map(doc=>doc.data()).find(m=>m.ready!==false);
              const mark = (await tx.get(doc.ref.collection('reads').doc(uid))).data();
              const lastMessageAt = message?.createdAt?.toMillis() || 0;
              const preview = !message ? '' : message.deleted ? 'Tin nhắn đã được gỡ' : message.text || 'Ảnh đính kèm';
              const unread = !!message && message.author!==uid && !r.blockedBy.length && (!mark || lastMessageAt>mark.at.toMillis());
              items.push({id:doc.id,...r,lastMessageAt,preview,unread,profile:await profile(target)});
            }
            items.sort((a,b)=>b.lastMessageAt-a.lastMessageAt || a.id.localeCompare(b.id));
            out={items}; break;
          }
          case 'friendship': {
            await profile(id(d.target)); const r=await relation(d.target),kind=str(d.kind,20,true);
            if(kind==='block') {r.blockedBy=[...new Set([...r.blockedBy,uid])];r.status='none';r.requestedBy='';}
            else if(kind==='unblock') r.blockedBy=r.blockedBy.filter(x=>x!==uid);
            else {
              unblocked(r);
              if(kind==='request') {
                check(r.status==='none','Đã có lời mời hoặc đã là bạn bè.');
                for (const person of [uid,d.target]) {
                  const all=await tx.get(db.collection('community_connections').where('members','array-contains',person).limit(200));
                  check(all.size<200,'Danh sách kết nối đã đầy.');
                }
                r.status='pending';r.requestedBy=uid;
              } else if(kind==='accept') {check(r.status==='pending'&&r.requestedBy===d.target);r.status='accepted';}
              else if(kind==='decline') {check(r.status==='pending'&&r.requestedBy===d.target);r.status='none';r.requestedBy='';}
              else if(kind==='cancel') {check(r.status==='pending'&&r.requestedBy===uid);r.status='none';r.requestedBy='';}
              else if(kind==='unfriend') {check(r.status==='accepted');r.status='none';r.requestedBy='';}
              else fail('invalid-argument','Thao tác kết bạn không hợp lệ.');
            }
            set(relationRef(uid,d.target),r); break;
          }
          case 'messages': case 'sendMessage': {
            const r=await relation(d.target),ref=relationRef(uid,d.target);
            check(r.status==='accepted'||r.hasMessages,'Hãy kết bạn trước khi nhắn tin.');
            if(d.action==='messages') {out=await page(tx,ref.collection('messages'),d.cursor);out.items=out.items.filter(m=>m.ready!==false);out.relation=r;if(!d.cursor)set(ref.collection('reads').doc(uid),{at:stamp});}
            else {
              unblocked(r);check(r.status==='accepted','Hai bạn cần kết bạn lại để gửi tin.');
              const messageId=ownId(),imagePath=photo?`community-media/messages/${ref.id}/${messageId}.jpg`:'';
              set(ref.collection('messages').doc(messageId),{author:uid,text:content(),imagePath,createdAt:stamp,deleted:false,ready:!photo});
              set(ref,{...r,hasMessages:true,...(!photo?{lastSender:uid,lastMessageAt:stamp}:{})});out={id:messageId,...(photo?{_upload:imagePath}:{})};
            }break;
          }
          case 'image': {
            let data;
            if(d.messageId) {
              const r=await relation(d.target);check(r.hasMessages);
              data=(await tx.get(relationRef(uid,d.target).collection('messages').doc(id(d.messageId)))).data();
            } else data=(await postAccess()).post;
            check(data&&!data.deleted&&data.ready!==false&&data.imagePath);out={_download:data.imagePath};break;
          }
          case 'report': {
            const reason=str(d.reason,500,true); let target,path,evidence,imagePath='';
            if(d.messageId) {
              const r=await relation(d.target);check(r.hasMessages);
              const ref=relationRef(uid,d.target).collection('messages').doc(id(d.messageId));
              const m=(await tx.get(ref)).data();check(!!m);target=m.author;path=ref.path;evidence=m.text;imagePath=m.imagePath||'';
            } else if(d.postId) {
              const {ref,post}=await postAccess();target=post.author;path=ref.path;evidence=post.text;imagePath=post.imagePath||'';
              if(d.commentId) {const c=ref.collection('comments').doc(id(d.commentId)),v=(await tx.get(c)).data();check(!!v);target=v.author;path=c.path;evidence=v.text;imagePath='';}
            } else {target=id(d.target);await profile(target);path=profileRef(target).path;evidence='';}
            check(target!==uid,'Không thể báo cáo nội dung của chính mình.');
            set(db.doc(`community_reports/${ownId()}`),{reporter:uid,target,path,evidence,imagePath,reason,status:'open',createdAt:stamp});break;
          }
          case 'notifications': {
            const snap=await tx.get(db.collection('community_notifications').where('recipient','==',uid).orderBy('createdAt','desc').limit(50));
            out={items:snap.docs.map(doc=>({id:doc.id,...doc.data(),createdAt:doc.data().createdAt.toMillis(),isRead:doc.data().read===true}))};break;
          }
          case 'markNotificationsRead': {
            const snap=await tx.get(db.collection('community_notifications').where('recipient','==',uid).where('read','==',false).limit(100));
            for(const doc of snap.docs) update(doc.ref,{read:true});break;
          }
          case 'reports':
            check(isAdmin);out=await page(tx,db.collection('community_reports'),d.cursor);
            set(db.collection('community_audit').doc(),{moderator:uid,kind:'reviewReports',createdAt:stamp});break;
          case 'reportImage': {
            check(isAdmin);const r=(await tx.get(db.doc(`community_reports/${id(d.reportId)}`))).data();
            check(r && r.imagePath);out={_download:r.imagePath};
            set(db.collection('community_audit').doc(),{moderator:uid,kind:'reviewImage',reportId:d.reportId,createdAt:stamp});break;
          }
          case 'moderate': {
            check(isAdmin);const ref=db.doc(`community_reports/${id(d.reportId)}`),r=(await tx.get(ref)).data();check(!!r);
            const kind=str(d.kind,20,true);if(!['dismiss','remove','suspend','restore'].includes(kind)) fail('invalid-argument','Thao tác xử lý không hợp lệ.');
            if(kind==='remove') {
              check(!r.path.startsWith('community_profiles/'));
              const target=db.doc(r.path),data=(await tx.get(target)).data();
              if(data) {update(target,{deleted:true,text:'',imagePath:''});out={_cleanup:data.imagePath||''};}
            } else if(kind==='suspend'||kind==='restore') update(profileRef(r.target),{suspended:kind==='suspend'});
            update(ref,{status:'resolved',resolution:kind,moderator:uid,resolvedAt:stamp});
            set(db.doc(`community_audit/${ownId()}`),{moderator:uid,reportId:d.reportId,kind,createdAt:stamp});break;
          }
          default: fail('invalid-argument','Thao tác chưa hỗ trợ.');
        }
      }
      // Queue writes until every authorization read has completed.
      for(const commit of writes) commit();
      if(receipt) tx.set(receipt,{fingerprint,result:out,createdAt:stamp});
      return out;
    });
    if(result._upload && photo) {
      const contentRef = d.action === 'createPost'
        ? db.doc(`community_spaces/${d.space}/posts/${result.id}`)
        : relationRef(uid,d.target).collection('messages').doc(result.id);
      const existing = (await contentRef.get()).data();
      check(existing && !existing.deleted && existing.imagePath === result._upload,
        'Nội dung này đã được gỡ.');
      try {
        await bucket.file(result._upload).save(photo,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{contentType:'image/jpeg',cacheControl:'private, no-store'}});
      } catch(error) {
        if(Number(error.code)!==412) fail('unavailable','Ảnh chưa tải xong. Hãy bấm thử lại để hoàn tất bài gửi.');
      }
      // Publish only after the blob exists, rechecking mutable permissions.
      await db.runTransaction(async tx => {
        const current = (await tx.get(contentRef)).data();
        check(current && !current.deleted && current.imagePath === result._upload);
        const owner = (await tx.get(profileRef(uid))).data();
        check(owner && !owner.suspended);
        if (d.action === 'createPost' && d.space !== 'public') {
          const group = (await tx.get(db.doc(`community_groups/${d.space}`))).data();
          check(group && !group.closed && group.members.includes(uid));
        } else if (d.action === 'sendMessage') {
          const r = (await tx.get(relationRef(uid,d.target))).data();
          check(r && r.status === 'accepted' && r.blockedBy.length === 0);
        }
        tx.update(contentRef,{ready:true});
        if (d.action === 'sendMessage' && current.ready === false) tx.update(relationRef(uid,d.target),{lastSender:uid,lastMessageAt:Timestamp.now()});
      });
    }
    if(result._cleanup) await bucket.file(result._cleanup).delete({ignoreNotFound:true});
    if(result._download) {
      try {const [bytes]=await bucket.file(result._download).download();return {image:bytes.toString('base64')};}
      catch(_){fail('unavailable','Ảnh chưa tải được. Hãy thử lại.');}
    }
    const {_upload,_cleanup,_download,...safe}=result;
    return safe;
  }
  return {handle};
}
module.exports={createCommunityService,validateRequest,pairId};
