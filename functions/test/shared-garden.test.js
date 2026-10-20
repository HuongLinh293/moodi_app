const {test, before, after, beforeEach} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, getDoc, getDocFromServer, getDocs, setDoc, updateDoc, deleteDoc, collection, query, where, limit, writeBatch, runTransaction, arrayUnion} = require('firebase/firestore');
const {getFirestore} = require('firebase-admin/firestore');
const {initializeApp} = require('firebase-admin/app');
const {randomBytes} = require('node:crypto');
initializeApp();
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.GCLOUD_PROJECT?.startsWith('demo-')) {
  throw Error('These tests require a demo project and Firestore Emulator.');
}
let env;
const db = getFirestore();
const clients = new Map();
const client = uid => {
  if (!clients.has(uid)) clients.set(uid, uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore());
  return clients.get(uid);
};
const newCode = () => 'MD-' + randomBytes(16).toString('hex').toUpperCase();
const create = async uid => {
  const store = client(uid);
  const ref = doc(collection(store, 'shared_gardens'));
  const garden = {code: newCode(), name: 'Vườn', members: [uid], memberNames: {[uid]: uid}, createdAt: new Date().toISOString(), nextSlot: 0, lastPlantId: '', joinProof: ''};
  const batch = writeBatch(store);
  batch.set(ref, garden);
  batch.set(doc(store, 'shared_garden_invites', garden.code), {gardenId: ref.id});
  await batch.commit();
  return {id: ref.id, ...garden};
};
const join = async (uid, code) => {
  const store = client(uid);
  const invite = await getDocFromServer(doc(store, 'shared_garden_invites', code));
  if (!invite.exists()) throw {code: 'not-found'};
  const ref = doc(store, 'shared_gardens', invite.data().gardenId);
  await updateDoc(ref, {members: arrayUnion(uid), [`memberNames.${uid}`]: uid, joinProof: code});
  return {id: ref.id, ...(await getDocFromServer(ref)).data()};
};
const call = async (uid, data) => {
  if (data.action === 'create') return create(uid);
  const store = client(uid);
  const ref = doc(store, 'shared_gardens', data.gardenId);
  if (data.action === 'leave' || data.action === 'refreshInvite') {
    const code = newCode();
    return runTransaction(store, async tx => {
      const garden = (await tx.get(ref)).data();
      const members = data.action === 'leave' ? garden.members.filter(x => x !== uid) : garden.members;
      const names = {...garden.memberNames};
      if (data.action === 'leave') delete names[uid];
      tx.update(ref, data.action === 'leave' ? {members, memberNames: names, code, joinProof: ''} : {code, joinProof: ''});
      if (garden.code.length === 35) tx.delete(doc(store, 'shared_garden_invites', garden.code));
      if (members.length) tx.set(doc(store, 'shared_garden_invites', code), {gardenId: ref.id});
      return {code};
    });
  }
  if (data.action === 'plant') {
    const momentRef = doc(collection(ref, 'moments'), uid + '_' + data.entryId);
    let legacyNext = 0;
    const previous = (await getDocFromServer(ref)).data();
    if (previous.nextSlot === undefined) {
      for (const snap of (await getDocs(collection(ref, 'moments'))).docs) {
        legacyNext = Math.max(legacyNext, (snap.data().bedIndex || 0) * 20 + snap.data().slotIndex + 1);
      }
    }
    let attemptedPosition;
    const execute = () => runTransaction(store, async tx => {
      const garden = (await tx.get(ref)).data();
      const old = await tx.get(momentRef);
      if (old.exists()) return {id: old.id, ...old.data()};
      const entrySnap = await tx.get(doc(store, 'users', uid, 'journal_entries', data.entryId));
      if (!entrySnap.exists()) throw {code: 'failed-precondition'};
      const entry = entrySnap.data();
      const position = garden.nextSlot ?? legacyNext;
      attemptedPosition = position;
      const moment = {gardenId: ref.id, entryId: data.entryId, authorId: uid, authorName: garden.memberNames[uid],
        emotionKey: entry.emotionKey, intensity: entry.intensity, caption: entry.situation,
        bedIndex: Math.floor(position / 20), slotIndex: position % 20, monthKey: '2026-10', plantedAt: entry.timestamp,
        waterCount: 0, sunCount: 0, lastInteraction: null};
      tx.set(momentRef, moment);
      tx.update(ref, {nextSlot: position + 1, lastPlantId: momentRef.id});
      return {id: momentRef.id, ...moment};
    });
    for (let attempt = 0; ; attempt++) {
      try {return await execute();} catch (error) {
        if (error.code !== 'permission-denied' || attempt >= 2 || attemptedPosition === undefined) throw error;
        const latest = (await getDocFromServer(ref)).data();
        if (!latest?.members.includes(uid) || (latest.nextSlot ?? 0) <= attemptedPosition) throw error;
      }
    }
  }
  const momentRef = doc(collection(ref, 'moments'), data.momentId);
  const careRef = doc(collection(momentRef, 'care'), uid);
  return runTransaction(store, async tx => {
    const garden = (await tx.get(ref)).data();
    const moment = (await tx.get(momentRef)).data();
    const receipt = (await tx.get(careRef)).data() || {water: false, sun: false};
    const kind = data.isWater ? 'water' : 'sun';
    if (receipt[kind]) return {id: momentRef.id, ...moment};
    const sentence = garden.memberNames[uid] + (data.isWater ? ' vừa tưới nước 💧' : ' vừa gửi tia nắng ấm ☀️');
    const change = {waterCount: moment.waterCount + (data.isWater ? 1 : 0), sunCount: moment.sunCount + (data.isWater ? 0 : 1), lastInteraction: data.text ?? sentence};
    tx.set(careRef, {...receipt, [kind]: true});
    tx.update(momentRef, change);
    return {id: momentRef.id, ...moment, ...change};
  });
};
const seedEntry = (uid, entryId) => db.doc(`users/${uid}/journal_entries/${entryId}`).set({
  emotionKey: 'calm', intensity: 3, situation: 'Riêng tư', thought: '', timestamp: '2026-10-17T09:00:00.000'});

before(async () => {
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  env = await initializeTestEnvironment({projectId: process.env.GCLOUD_PROJECT,
    firestore: {host, port: Number(port), rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')}});
});
beforeEach(async () => { await env.clearFirestore(); });
after(async () => { fs.writeFileSync('/tmp/mindra-rules-coverage.json', await (await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${process.env.GCLOUD_PROJECT}:ruleCoverage`)).text()); await env.cleanup(); await db.terminate(); });

test('rules block outsiders, enumeration, forgery, arbitrary writes; member query works', async () => {
  const garden = await create('alice');
  await seedEntry('alice', 'e1');
  const flower = await call('alice', {action: 'plant', gardenId: garden.id, entryId: 'e1'});
  const outsider = env.authenticatedContext('eve').firestore();
  const alice = env.authenticatedContext('alice').firestore();
  const guest = env.unauthenticatedContext().firestore();
  const gardenPath = `shared_gardens/${garden.id}`;
  const momentPath = `${gardenPath}/moments/${flower.id}`;
  await assertFails(getDoc(doc(outsider, gardenPath)));
  await assertFails(getDocs(collection(outsider, 'shared_gardens')));
  await assertFails(getDoc(doc(outsider, momentPath)));
  await assertFails(getDoc(doc(guest, gardenPath)));
  await assertFails(updateDoc(doc(outsider, gardenPath), {members: ['eve']}));
  await assertFails(setDoc(doc(alice, momentPath), {...flower, authorId: 'eve'}));
  await assertFails(deleteDoc(doc(outsider, momentPath)));
  await assertFails(getDocs(collection(outsider, 'shared_garden_invites')));
  const invitation = await assertSucceeds(getDoc(doc(outsider, `shared_garden_invites/${garden.code}`)));
  assert.deepEqual(Object.keys(invitation.data()), ['gardenId']);
  await assertSucceeds(getDoc(doc(alice, momentPath)));
  const mine = await assertSucceeds(getDocs(query(collection(alice, 'shared_gardens'), where('members', 'array-contains', 'alice'), limit(1))));
  assert.equal(mine.docs[0].id, garden.id);
  await assert.rejects(call(null, {action: 'create'}), {code: 'permission-denied'});
  await assert.rejects(call('eve', {action: 'plant', gardenId: garden.id, entryId: 'e1'}), {code: 'permission-denied'});
  await assert.rejects(call('eve', {action: 'care', gardenId: garden.id, momentId: flower.id, isWater: true}), {code: 'permission-denied'});
});

test('concurrent joins enforce two members; leave revokes access and invitation', async () => {
  const garden = await create('alice');
  const results = await Promise.allSettled([join('bob', garden.code), join('carol', garden.code)]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  const saved = (await db.doc(`shared_gardens/${garden.id}`).get()).data();
  assert.equal(saved.members.length, 2);
  const joined = saved.members.find(uid => uid !== 'alice');
  await seedEntry('alice', 'e-leave');
  const flower = await call('alice', {action: 'plant', gardenId: garden.id, entryId: 'e-leave'});
  await assertSucceeds(getDocFromServer(doc(client(joined), `shared_gardens/${garden.id}/moments/${flower.id}`)));
  await call(joined, {action: 'leave', gardenId: garden.id});
  const updated = (await db.doc(`shared_gardens/${garden.id}`).get()).data();
  assert.deepEqual(updated.members, ['alice']);
  assert.notEqual(updated.code, garden.code);
  const departed = env.authenticatedContext(joined).firestore();
  await assertFails(getDocFromServer(doc(departed, `shared_gardens/${garden.id}`)));
  await assertFails(getDocFromServer(doc(departed, `shared_gardens/${garden.id}/moments/${flower.id}`)));
  await assert.rejects(call(joined, {action: 'care', gardenId: garden.id, momentId: flower.id, isWater: true}), {code: 'permission-denied'});
  await assert.rejects(join(joined, garden.code), {code: 'not-found'});
  assert.equal((await create(joined)).members[0], joined);
});

test('21+ flowers, concurrent writes and retries allocate unique beds and slots', async () => {
  const garden = await create('alice');
  await join('bob', garden.code);
  const flowers = [];
  for (let i = 0; i < 22; i += 2) {
    await Promise.all([seedEntry('alice', `e${i}`), seedEntry('bob', `e${i + 1}`)]);
    flowers.push(...await Promise.all([
      call('alice', {action: 'plant', gardenId: garden.id, entryId: `e${i}`}),
      call('bob', {action: 'plant', gardenId: garden.id, entryId: `e${i + 1}`}),
    ]));
  }
  assert.equal(new Set(flowers.map(m => `${m.bedIndex}-${m.slotIndex}`)).size, 22);
  assert.equal(flowers.filter(m => m.bedIndex === 1).length, 2);
  const retry = await call('alice', {action: 'plant', gardenId: garden.id, entryId: 'e0'});
  assert.equal(retry.id, flowers[0].id);
  assert.equal((await db.doc(`shared_gardens/${garden.id}`).get()).data().nextSlot, 22);
  await assert.rejects(call('bob', {action: 'plant', gardenId: garden.id, entryId: 'e0'}), {code: 'failed-precondition'});
});

test('care is atomic and cannot be replayed or forged', async () => {
  const garden = await create('alice');
  await join('bob', garden.code);
  await seedEntry('alice', 'e1');
  const flower = await call('alice', {action: 'plant', gardenId: garden.id, entryId: 'e1'});
  const data = {action: 'care', gardenId: garden.id, momentId: flower.id, isWater: true};
  await Promise.all([call('bob', data), call('bob', data)]);
  const saved = (await db.doc(`shared_gardens/${garden.id}/moments/${flower.id}`).get()).data();
  assert.equal(saved.waterCount, 1);
  assert.equal(saved.caption, 'Riêng tư');
  const store = client('bob');
  const ref = doc(store, `shared_gardens/${garden.id}/moments/${flower.id}`);
  const receipt = doc(store, `${ref.path}/care/bob`);
  await assertFails(updateDoc(ref, {waterCount: 999}));
  await assertFails(updateDoc(receipt, {water: false}));
  await assertFails(updateDoc(receipt, {sun: true}));
  await assertFails(setDoc(doc(store, `${ref.path}/care/alice`), {water: true, sun: true}));
  await call('bob', data);
  assert.equal((await db.doc(ref.path).get()).data().waterCount, 1);
  assert.equal((await db.doc(ref.path).get()).data().lastInteraction, 'bob vừa tưới nước 💧');
  // Care can't carry free text onto the partner's flower.
  await assert.rejects(call('bob', {...data, isWater: false, text: 'tin nhắn tuỳ ý'}), {code: 'permission-denied'});
  await call('bob', {...data, isWater: false});
  assert.equal((await db.doc(ref.path).get()).data().lastInteraction, 'bob vừa gửi tia nắng ấm ☀️');

});

test('legacy invitations require rotation; legacy slots remain occupied', async () => {
  await db.doc('shared_gardens/legacy').set({code: 'MD-AAAA', name: 'Old', members: ['alice'], memberNames: {alice: 'Alice'}, createdAt: '2026-10-01'});
  await db.doc('shared_gardens/legacy/moments/old').set({slotIndex: 19, plantedAt: '2026-10-01'});
  await assert.rejects(join('bob', 'MD-AAAA'), {code: 'not-found'});
  const {code} = await call('alice', {action: 'refreshInvite', gardenId: 'legacy'});
  await join('bob', code);
  await seedEntry('alice', 'e1');
  const flower = await call('alice', {action: 'plant', gardenId: 'legacy', entryId: 'e1'});
  assert.equal(flower.bedIndex, 1);
  assert.equal(flower.slotIndex, 0);
});

test('only the author can take back a flower, and only while a member', async () => {
  const garden = await create('alice');
  await join('bob', garden.code);
  await seedEntry('alice', 'e-mine');
  await seedEntry('alice', 'e-later');
  const flower = await call('alice', {action: 'plant', gardenId: garden.id, entryId: 'e-mine'});
  const later = await call('alice', {action: 'plant', gardenId: garden.id, entryId: 'e-later'});
  const momentPath = id => `shared_gardens/${garden.id}/moments/${id}`;
  await assertFails(deleteDoc(doc(client('bob'), momentPath(flower.id))));
  await assertFails(deleteDoc(doc(client('eve'), momentPath(flower.id))));
  await assertSucceeds(deleteDoc(doc(client('alice'), momentPath(flower.id))));
  assert.equal((await db.doc(momentPath(flower.id)).get()).exists, false);
  // The same entry can be shared again later; it takes a new slot.
  const again = await call('alice', {action: 'plant', gardenId: garden.id, entryId: 'e-mine'});
  assert.equal(again.id, flower.id);
  await call('alice', {action: 'leave', gardenId: garden.id});
  await assertFails(deleteDoc(doc(client('alice'), momentPath(later.id))));
});
