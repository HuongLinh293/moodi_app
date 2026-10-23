// Ma trận kiểm soát truy cập cho backend NestJS (thay cho phòng lab Firestore).
// Mỗi kịch bản thử lại một lỗ hổng đã vá hoặc một quy tắc phân quyền.
// Chạy: xem security-lab/README.md. Chỉ dùng với server dev và dữ liệu giả.
import { randomBytes } from 'node:crypto';

const BASE = process.env.BASE || 'http://localhost:3100/api';
const R = randomBytes(3).toString('hex');
// PNG 4x4 có EXIF giả ("secret-gps") để kiểm tra ảnh được mã hoá lại.
const PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAABP2lDQ1BpY2MAAHicfZC/SwJxGMY/11WWWA05NBQcJU0FUUtTgYZOEfgj1Kbz/FGgdt33QprLoaloiEZrCaLZxhz6A4KgIQqirdWghpKLrw5aUM/yfnh4Xt6XB5TnvFEQ3RoUirYVDvm1eCKpuV5Q8dLPIGO6IczlSDAKIPSSMGwrzw+936PIeTe9rhfTO6/Xq8kFpbo7UY4FP1Yu+F/udEYYwBfgM0zLBkUDxku2KXkJ8BrrehqUODBlxRNJUPakn2vxieRUiy8lW9FwAJQaoOU6ONXBhfy2vCslv/dkirEI0AeMIggTwv9HpreZCRBgBmRfv3sQ2bnZ1pZnEXqeHOdtElyH0DhynM9Tx2mcgfoIta32/mYF5uugHrS91DFc7cPIQ9vzVWCoDNUbU7f0pqUCXdkNqJ/DQAKGb8G99g3j4l+xfPB+eQAAAAlwSFlzAAAD6AAAA+gBtXtSawAAAMxlWElmSUkqAAgAAAAHABIBAwABAAAAAQAAABoBBQABAAAAYgAAABsBBQABAAAAagAAACgBAwABAAAAAgAAABMCAwABAAAAAQAAAJiCAgALAAAAcgAAAGmHBAABAAAAfgAAAAAAAAA4YwAA6AMAADhjAADoAwAAc2VjcmV0LWdwcwAABgAAkAcABAAAADAyMTABkQcABAAAAAECAwAAoAcABAAAADAxMDABoAMAAQAAAP//AAACoAQAAQAAAAQAAAADoAQAAQAAAAQAAAAAAAAAsXilZAAAABFJREFUeJxj6Fh1Bo4YiOMAADjhH+FcI5vXAAAAAElFTkSuQmCC';
let pass = 0, failN = 0;
const ok = (cond, name, extra = '') => {
  if (cond) { pass++; console.log(`  ✓ ${name}`); }
  else { failN++; console.log(`  ✗ ${name} ${extra}`); }
};
async function req(method, path, { token, body, headers = {} } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json; try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, json };
}
const reg = async (name) => {
  const r = await req('POST', '/auth/register', { body: { email: `${name}${R}@T.vn`, username: `${name}${R}`, password: 'Passw0rd!x', displayName: name } });
  if (r.status !== 201) throw new Error(`register ${name}: ${r.status} ${JSON.stringify(r.json)}`);
  return { token: r.json.accessToken, id: r.json.user.id, refresh: r.json.refreshToken, email: `${name}${R}@t.vn` };
};
const community = (u, action, data = {}, requestId) =>
  req('POST', '/community', { token: u.token, body: { action, ...data, ...(requestId ? { requestId } : {}) } });
const rid = () => randomBytes(10).toString('hex');

const A = await reg('alice'), B = await reg('bob'), C = await reg('carol');

console.log('Auth');
{
  const r = await req('POST', '/auth/login', { body: { email: A.email.toUpperCase(), password: 'Passw0rd!x' } });
  ok(r.status === 200, 'login chuẩn hoá email hoa/thường', r.status);
  const bad = await req('POST', '/auth/register', { body: { email: `x${R}@t.vn`, username: 'bad name!', password: 'Passw0rd!x' } });
  ok(bad.status === 400, 'username ký tự lạ bị từ chối');
  const long = await req('POST', '/auth/register', { body: { email: `y${R}@t.vn`, username: `y${R}`, password: 'ư'.repeat(40) } });
  ok(long.status === 400, 'mật khẩu > 72 byte bị từ chối', long.status);
  const prov = await req('GET', '/auth/providers');
  ok(prov.status === 200 && prov.json.google === false && prov.json.apple === false, 'providers: chưa cấu hình → false');
  const g = await req('POST', '/auth/google', { body: { idToken: 'x.y.z' } });
  ok(g.status === 503, 'Google chưa cấu hình → 503', g.status);
  // Phiên của C để test logout
  const before = await req('GET', '/users/me', { token: C.token });
  await req('POST', '/auth/logout', { token: C.token });
  const after = await req('GET', '/users/me', { token: C.token });
  ok(before.status === 200 && after.status === 401, 'logout vô hiệu access token ngay', `${before.status}/${after.status}`);
  const ref = await req('POST', '/auth/refresh-token', { body: { refreshToken: C.refresh } });
  ok(ref.status === 401, 'refresh token bị thu hồi sau logout');
}

console.log('Users');
{
  const anon = await req('GET', `/users/${A.id}`);
  ok(anon.status === 401, 'xem hồ sơ cần đăng nhập', anon.status);
  const other = await req('GET', `/users/${A.id}`, { token: B.token });
  ok(other.status === 200 && other.json.email === undefined, 'người khác không thấy email');
  const self = await req('GET', '/users/me', { token: A.token });
  ok(self.json.email === A.email, 'chính chủ thấy email');
  const s1 = await req('GET', `/users/search/${encodeURIComponent('T.vn')}`, { token: B.token });
  ok(s1.status === 200 && s1.json.length === 0, 'không tìm được theo email');
  const s2 = await req('GET', `/users/search/${encodeURIComponent('%%')}`, { token: B.token });
  ok(s2.status === 200 && s2.json.length === 0, "ký tự '%' không quét toàn bảng", JSON.stringify(s2.json).slice(0, 80));
  const patch = await req('PATCH', `/users/${A.id}`, { token: B.token, body: { bio: 'hacked' } });
  ok(patch.status === 403, 'sửa hồ sơ người khác → 403 (trước: 500)', patch.status);
  const avatar = await req('PATCH', `/users/${A.id}/avatar`, { token: A.token, body: { avatar: 'javascript:alert(1)' } });
  ok(avatar.status === 400, 'avatar URL tuỳ ý bị từ chối');
  const badId = await req('GET', '/users/not-a-uuid', { token: A.token });
  ok(badId.status === 400, 'id sai định dạng → 400 (không phải 500)', badId.status);
}

console.log('Storage');
{
  const png = PNG;
  const trav = await req('POST', '/storage/upload', { token: A.token, body: { filename: '/../../../../tmp/pwned.png', fileContent: png, mimeType: 'image/png', accessType: 'private' } });
  ok(trav.status === 201 && !trav.json.data.filename.includes('/'), 'path traversal trong filename bị vô hiệu', JSON.stringify(trav.json).slice(0, 120));
  const fake = await req('POST', '/storage/upload', { token: A.token, body: { filename: 'x.png', fileContent: Buffer.from('<script>').toString('base64'), mimeType: 'image/png' } });
  ok(fake.status === 400, 'nội dung không khớp mimeType bị từ chối');
  const fid = trav.json.data.id;
  const own = await req('GET', `/storage/${fid}/content`, { token: A.token });
  ok(own.status === 200, 'chủ file đọc được file private (trước: luôn 403)', own.status);
  const other = await req('GET', `/storage/${fid}/content`, { token: B.token });
  const anon = await req('GET', `/storage/${fid}/content`);
  ok(other.status === 404 && anon.status === 404, 'người khác/khách không đọc được file private');
  const pub = await req('POST', '/storage/upload', { token: A.token, body: { filename: 'a.png', fileContent: png, mimeType: 'image/png', accessType: 'public' } });
  const av = await req('PATCH', `/users/${A.id}/avatar`, { token: A.token, body: { avatar: pub.json.data.id } });
  ok(av.status === 200 && av.json.avatar.startsWith('/api/storage/'), 'avatar từ file public của mình');
  const steal = await req('PATCH', `/users/${B.id}/avatar`, { token: B.token, body: { avatar: fid } });
  ok(steal.status === 400, 'không dùng file của người khác làm avatar');
}

console.log('Groups / Posts / Chat / Friends');
{
  const g = await req('POST', '/groups', { token: A.token, body: { name: 'Nhóm A', image: 'javascript:x' } });
  ok(g.status === 400, 'ảnh nhóm javascript: bị từ chối');
  const g2 = await req('POST', '/groups', { token: A.token, body: { name: 'Nhóm A' } });
  const gid = g2.json.data.id;
  const anon = await req('GET', `/groups/${gid}/members`);
  const outsider = await req('GET', `/groups/${gid}/members`, { token: B.token });
  ok(anon.status === 401 && outsider.status === 403, 'danh sách thành viên chỉ cho thành viên', `${anon.status}/${outsider.status}`);
  const huge = await req('GET', '/groups?limit=100000&page=abc', { token: A.token });
  ok(huge.status === 200 && huge.json.pagination.limit === 50, 'phân trang bị chặn biên', JSON.stringify(huge.json.pagination));
  const feedAnon = await req('GET', '/posts');
  ok(feedAnon.status === 401, 'bảng tin cần đăng nhập');
  const p = await req('POST', '/posts', { token: A.token, body: { content: 'hi' } });
  const likes = await Promise.all([1, 2, 3, 4, 5].map(() => req('POST', `/posts/${p.json.id}/like`, { token: B.token })));
  const after = await req('GET', `/posts/${p.json.id}`, { token: A.token });
  ok(likes.every((l) => l.status === 201) && after.json.likesCount === 1, 'like song song chỉ tính 1', `${likes.map((l) => l.status)} count=${after.json.likesCount}`);
  const conv = await req('POST', '/chat/conversations', { token: A.token, body: { type: 'direct', participantIds: [B.id] } });
  ok(conv.status === 403, 'không kéo người lạ vào trò chuyện', conv.status);
  const fr = await req('POST', '/friends/requests', { token: A.token, body: { friendId: B.id } });
  const cancel = await req('DELETE', `/friends/requests/${fr.json.data.id}`, { token: A.token });
  ok(cancel.status === 204, 'người gửi tự huỷ được lời mời', cancel.status);
  const fr2 = await req('POST', '/friends/requests', { token: A.token, body: { friendId: B.id } });
  await req('POST', `/friends/requests/${fr2.json.data.id}/accept`, { token: B.token });
  const conv2 = await req('POST', '/chat/conversations', { token: A.token, body: { type: 'direct', participantIds: [B.id] } });
  ok(conv2.status === 201, 'trò chuyện với bạn bè OK', conv2.status);
}

console.log('Reflections');
{
  const r = await req('POST', '/reflections/generate', { token: A.token, body: { emotionKey: 'stressed', intensity: 4, situation: 'Deadline', thought: '' } });
  ok(r.status === 200 && r.json.id && ['grounding', 'thought_reframing', 'self_compassion', 'response_pause'].includes(r.json.recommendedExercise), 'generate trả mã bài tập app hiểu', `${r.status} ${r.json.recommendedExercise}`);
  ok(r.json.possibleTrigger === 'Deadline' && r.json.source === 'template', 'không có key → template');
  const crisis = await req('POST', '/reflections/generate', { token: A.token, body: { emotionKey: 'sad', intensity: 5, situation: 'Tôi muốn chết', thought: '' } });
  ok(crisis.json.safetyFlag === true && crisis.json.source === 'safety', 'tín hiệu khủng hoảng → luồng an toàn');
  const bad = await req('POST', '/reflections/generate', { token: A.token, body: { emotionKey: 'evil', intensity: 9 } });
  ok(bad.status === 400, 'emotion/intensity sai → 400');
  const hist = await req('GET', '/reflections/history?limit=5', { token: A.token });
  const histB = await req('GET', '/reflections/history', { token: B.token });
  ok(hist.json.length === 2 && histB.json.length === 0, 'lịch sử tách theo người dùng');
  const fbB = await req('POST', `/reflections/${r.json.id}/feedback`, { token: B.token, body: { feedback: 'x', helpful: false } });
  const fbA = await req('POST', `/reflections/${r.json.id}/feedback`, { token: A.token, body: { feedback: 'hay', helpful: true } });
  ok(fbB.status === 404 && fbA.status === 204, 'chỉ chủ phản tư gửi được feedback');
  const safe = await req('POST', '/reflections/safety-check', { token: A.token, body: { situation: 'ổn', thought: 'self harm' } });
  ok(safe.json.isSafe === false, 'safety-check');
  const ins = await req('GET', '/reflections/insights', { token: A.token });
  ok(ins.status === 200 && typeof ins.json.totalEntries === 'number', 'insights');
}

console.log('Community');
{
  const notProfile = await community(A, 'feed', { space: 'public' });
  ok(notProfile.status === 403, 'chưa có hồ sơ → 403');
  for (const [u, n] of [[A, 'Alice'], [B, 'Bob'], [C, 'Carol']]) {
    if (u === C) { const re = await req('POST', '/auth/login', { body: { email: C.email, password: 'Passw0rd!x' } }); C.token = re.json.accessToken; }
    const s = await community(u, 'saveProfile', { name: n, bio: '' }, rid());
    if (s.status !== 200) console.log(s);
  }
  const boot = await community(A, 'bootstrap');
  ok(boot.status === 200 && boot.json.me.name === 'Alice' && boot.json.admin === false, 'bootstrap');
  const extra = await community(A, 'feed', { space: 'public', evil: 1 });
  ok(extra.status === 400, 'trường lạ bị từ chối');
  const req1 = rid();
  const png = PNG;
  const p1 = await community(A, 'createPost', { space: 'public', text: 'Xin chào', mood: 'Bình yên', intent: '', image: png }, req1);
  const p1again = await community(A, 'createPost', { space: 'public', text: 'Xin chào', mood: 'Bình yên', intent: '', image: png }, req1);
  const p1diff = await community(A, 'createPost', { space: 'public', text: 'Khác', mood: '', intent: '' }, req1);
  ok(p1.status === 200 && p1again.json.id === p1.json.id && p1diff.status === 409, 'idempotency theo requestId', `${p1.status} ${p1diff.status}`);
  const img = await community(B, 'image', { space: 'public', postId: p1.json.id });
  ok(img.status === 200 && Buffer.from(img.json.image, 'base64')[0] === 0xff, 'ảnh được mã hoá lại thành JPEG (bỏ EXIF)');
  const feed = await community(B, 'feed', { space: 'public' });
  ok(feed.json.items.some((p) => p.id === p1.json.id && p.liked === false), 'feed');
  const react = await Promise.all([1, 2, 3].map(() => community(B, 'react', { space: 'public', postId: p1.json.id, enabled: true }, rid())));
  const post = await community(A, 'post', { space: 'public', postId: p1.json.id });
  ok(react.every((r) => r.status === 200) && post.json.post.likes === 1, 'react song song chỉ tính 1 (SERIALIZABLE)', `${react.map((r) => r.status)} likes=${post.json.post.likes}`);
  const del = await community(B, 'deletePost', { space: 'public', postId: p1.json.id }, rid());
  ok(del.status === 403, 'không xoá bài người khác');
  // Nhóm riêng
  const g = await community(A, 'createGroup', { name: 'Riêng', description: '' }, rid());
  const gp = await community(A, 'createPost', { space: g.json.id, text: 'bí mật', mood: '', intent: '' }, rid());
  const peek = await community(B, 'feed', { space: g.json.id });
  const peekPost = await community(B, 'post', { space: g.json.id, postId: gp.json.id });
  ok(peek.status === 403 && peekPost.status === 403, 'người ngoài không đọc được nhóm riêng');
  const bp = await community(B, 'profile', { target: A.id });
  await community(A, 'invite', { space: g.json.id, target: B.id }, rid());
  const acc = await community(B, 'groupAction', { space: g.json.id, kind: 'accept' }, rid());
  const peek2 = await community(B, 'feed', { space: g.json.id });
  ok(acc.status === 200 && peek2.json.items.length === 1, 'được mời + chấp nhận → đọc được');
  // Kết bạn, chặn, nhắn tin
  const msgBefore = await community(B, 'sendMessage', { target: A.id, text: 'hi' }, rid());
  ok(msgBefore.status === 403, 'chưa kết bạn không nhắn tin được');
  await community(B, 'friendship', { target: A.id, kind: 'request' }, rid());
  const bootA = await community(A, 'bootstrap');
  ok(bootA.json.pending === 1, 'bootstrap đếm lời mời kết bạn');
  await community(A, 'friendship', { target: B.id, kind: 'accept' }, rid());
  const msg = await community(B, 'sendMessage', { target: A.id, text: 'chào' }, rid());
  const conns = await community(A, 'connections');
  ok(msg.status === 200 && conns.json.items[0].unread === true && conns.json.items[0].preview === 'chào', 'nhắn tin + unread');
  const msgs = await community(A, 'messages', { target: B.id });
  const conns2 = await community(A, 'connections');
  ok(msgs.json.items.length === 1 && conns2.json.items[0].unread === false, 'đọc tin → hết unread');
  await community(A, 'friendship', { target: B.id, kind: 'block' }, rid());
  const blockedMsg = await community(B, 'sendMessage', { target: A.id, text: 'alo' }, rid());
  const feedA = await community(A, 'feed', { space: 'public' });
  ok(blockedMsg.status === 403, 'bị chặn → không nhắn được');
  // Báo cáo & kiểm duyệt
  const rep = await community(B, 'report', { space: 'public', postId: p1.json.id, reason: 'spam' }, rid());
  ok(rep.status === 403 || rep.status === 200, 'báo cáo (B đã bị A chặn)', rep.status);
  const rep2 = await community(C, 'report', { space: 'public', postId: p1.json.id, reason: 'spam' }, rid());
  const self = await community(A, 'report', { space: 'public', postId: p1.json.id, reason: 'x' }, rid());
  ok(rep2.status === 200 && self.status === 403, 'báo cáo; không tự báo cáo mình');
  const notAdmin = await community(C, 'reports');
  ok(notAdmin.status === 403, 'người thường không xem báo cáo');
  // Rate limit đọc: 240/phút
  let limited = false;
  for (let i = 0; i < 260 && !limited; i++) limited = (await community(C, 'bootstrap')).status === 429;
  ok(limited, 'rate limit 240 lượt đọc/phút');
}

console.log(`\n${pass} pass, ${failN} fail`);
process.exit(failN ? 1 : 0);
