const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment} = require('@firebase/rules-unit-testing');
const {doc, getDocFromServer, getDocs, setDoc, updateDoc, deleteDoc, deleteField, collection, query, orderBy} = require('firebase/firestore');
const root = path.resolve(__dirname, '../..');
if (process.env.GCLOUD_PROJECT !== 'demo-moodi-security' || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8180') {
  throw Error('Security matrix is restricted to the isolated loopback demo emulator.');
}
const entry = extra => ({userId: 'alice', timestamp: '2026-10-19T10:00:00.000', emotionKey: 'calm', intensity: 3,
  trigger: 'other', situation: 'Synthetic test entry', thought: '', response: '', exerciseId: null,
  exerciseDone: false, afterIntensity: null, afterEmotionKey: null, usefulnessRating: null,
  easeRating: null, repeatPreference: null, ...extra});
const journalPath = 'users/alice/journal_entries/e1';
const gardenPath = 'shared_gardens/g1';
const code = 'MD-' + 'A'.repeat(32);
const versions = {baseline: 'security-lab/baseline/firestore.rules', vulnerable: 'security-lab/firestore.vulnerable.rules', hardened: 'firestore.rules'};
const report = [];

for (const [version, file] of Object.entries(versions)) {
  test(`Access-control matrix: ${version}`, async t => {
    const env = await initializeTestEnvironment({projectId: process.env.GCLOUD_PROJECT,
      firestore: {host: '127.0.0.1', port: 8180, rules: fs.readFileSync(path.join(root, file), 'utf8')}});
    const client = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
    const alice = client('alice'), bob = client('bob'), guest = client(null);
    const cases = [
      ['AT-01 get unauthenticated', false, false, () => getDocFromServer(doc(guest, journalPath))],
      ['AT-01 list unauthenticated', false, false, () => getDocs(collection(guest, 'users/alice/journal_entries'))],
      ['AT-02 read another owner', false, true, () => getDocFromServer(doc(bob, journalPath))],
      ['AT-02 enumerate another journal', false, true, () => getDocs(collection(bob, 'users/alice/journal_entries'))],
      ['AT-03 overwrite another journal', false, true, () => updateDoc(doc(bob, journalPath), {situation: 'Tampered'})],
      ['AT-03 delete another journal', false, true, () => deleteDoc(doc(bob, journalPath))],
      ['AT-03 create under another owner', false, true, () => setDoc(doc(bob, 'users/alice/journal_entries/e2'), entry())],
      ['AT-04 forge owner on create', true, true, () => setDoc(doc(alice, 'users/alice/journal_entries/e2'), entry({userId: 'bob'}))],
      ['AT-04 forge owner on update', true, true, () => updateDoc(doc(alice, journalPath), {userId: 'bob'})],
      ['AT-04 inject role', true, true, () => updateDoc(doc(alice, journalPath), {role: 'admin'})],
      ['AT-04 overlong create', true, true, () => setDoc(doc(alice, 'users/alice/journal_entries/e2'), entry({situation: 'x'.repeat(4001)}))],
      ['AT-04 overlong update', true, true, () => updateDoc(doc(alice, journalPath), {thought: 'x'.repeat(4001)})],
      ['AT-04 wrong type', true, true, () => updateDoc(doc(alice, journalPath), {intensity: '3'})],
      ['AT-04 invalid range', true, true, () => updateDoc(doc(alice, journalPath), {intensity: 6})],
      ['AT-04 omit required field', true, true, () => updateDoc(doc(alice, journalPath), {emotionKey: deleteField()})],
      ['AT-04 rewrite timestamp', true, true, () => updateDoc(doc(alice, journalPath), {timestamp: '2027-01-01T00:00:00'})],
      ['AT-05 read garden as outsider', false, true, () => getDocFromServer(doc(bob, gardenPath))],
      ['AT-05 self-enroll without invitation', false, true, () => updateDoc(doc(bob, gardenPath), {members: ['alice', 'bob'], memberNames: {alice: 'Alice', bob: 'Bob'}, joinProof: 'invalid'})],
      ['AT-06 former member read', false, true, () => getDocFromServer(doc(bob, `${gardenPath}/moments/m1`))],
      ['AT-06 former member write', false, true, () => updateDoc(doc(bob, `${gardenPath}/moments/m1`), {waterCount: 1})],
      ['AT-08 owner read', true, true, () => getDocFromServer(doc(alice, journalPath)), true],
      ['AT-08 owner ordered list', true, true, () => getDocs(query(collection(alice, 'users/alice/journal_entries'), orderBy('timestamp', 'desc'))), true],
      ['AT-08 owner create', true, true, () => setDoc(doc(alice, 'users/alice/journal_entries/e2'), entry()), true],
      ['AT-08 owner edit', true, true, () => updateDoc(doc(alice, journalPath), {situation: 'Edited synthetic text'}), true],
      ['AT-08 owner delete', true, true, () => deleteDoc(doc(alice, journalPath)), true],
      ['AT-08 current garden member read', true, true, () => getDocFromServer(doc(alice, gardenPath)), true],
    ];
    try {
      for (const [name, baseline, vulnerable, action, hardened = false] of cases) {
        await t.test(name, async () => {
          await env.clearFirestore();
          await env.withSecurityRulesDisabled(async context => {
            const store = context.firestore();
            await setDoc(doc(store, journalPath), entry());
            // Bob was removed; Alice remains. Server state is the ACL authority.
            await setDoc(doc(store, gardenPath), {code, name: 'Synthetic garden', members: ['alice'], memberNames: {alice: 'Alice'},
              createdAt: '2026-10-19T10:00:00', nextSlot: 1, lastPlantId: 'm1', joinProof: ''});
            await setDoc(doc(store, `${gardenPath}/moments/m1`), {gardenId: 'g1', authorId: 'alice', waterCount: 0});
          });
          let allowed = true;
          try {await action();} catch (error) {
            if (error.code !== 'permission-denied') throw error;
            allowed = false;
          }
          const expected = {baseline, vulnerable, hardened}[version];
          report.push({version, test: name, expected: expected ? 'allow' : 'deny', actual: allowed ? 'allow' : 'deny'});
          assert.equal(allowed, expected, `${version}: ${name}`);
        });
      }
    } finally {
      await env.cleanup();
      fs.mkdirSync(path.join(root, 'security-lab/results'), {recursive: true});
      fs.writeFileSync(path.join(root, 'security-lab/results/access-control.json'), JSON.stringify({generatedAt: new Date().toISOString(), report}, null, 2));
    }
  });
}

test('Hardened private schemas: garden/goal queries, updates, references and immutable fields', async () => {
  const env = await initializeTestEnvironment({projectId: process.env.GCLOUD_PROJECT,
    firestore: {host: '127.0.0.1', port: 8180, rules: fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8')}});
  try {
    await env.clearFirestore();
    const alice = env.authenticatedContext('alice').firestore();
    const bob = env.authenticatedContext('bob').firestore();
    const deny = action => assert.rejects(action, {code: 'permission-denied'});
    await setDoc(doc(alice, journalPath), entry());
    const ref = doc(alice, 'users/alice/garden_moments/garden-e1');
    const flower = {userId: 'alice', entryId: 'e1', monthKey: '2026-10', bedIndex: 0, slotIndex: 0,
      plantedAt: '2026-10-19T10:00:00', appearanceVariant: 1};
    await setDoc(ref, flower);
    await updateDoc(ref, {slotIndex: 1});
    await getDocs(query(collection(alice, 'users/alice/garden_moments'), orderBy('plantedAt', 'desc')));
    for (const change of [{entryId: 'missing'}, {slotIndex: 20}, {userId: 'bob'}, {role: 'admin'}, {appearanceVariant: '1'}]) {
      await deny(setDoc(doc(alice, 'users/alice/garden_moments/invalid'), {...flower, ...change}));
      await deny(updateDoc(ref, change));
    }
    await deny(updateDoc(ref, {plantedAt: '2027-01-01T00:00:00'}));
    await deny(getDocFromServer(doc(bob, ref.path)));
    const goal = doc(alice, 'users/alice/micro_goals/g1');
    const validGoal = {prompt: 'Synthetic goal', createdAt: '2026-10-19T10:00:00', status: 'open'};
    await setDoc(goal, validGoal);
    await updateDoc(goal, {status: 'attempted', followUpNote: 'Synthetic'});
    for (const change of [{status: 'admin'}, {prompt: 'x'.repeat(2001)}, {followUpNote: []}, {role: 'admin'}]) {
      await deny(setDoc(doc(alice, 'users/alice/micro_goals/invalid'), {...validGoal, ...change}));
      await deny(updateDoc(goal, change));
    }
    await deny(updateDoc(goal, {createdAt: '2027-01-01T00:00:00'}));
    await deny(setDoc(doc(alice, 'users/alice'), {role: 'admin'}));
    await deny(setDoc(doc(alice, 'journal_entries/legacy'), entry()));
    await deny(getDocs(collection(bob, 'users')));
    await deleteDoc(goal);
    await deleteDoc(ref);
  } finally {await env.cleanup();}
});
