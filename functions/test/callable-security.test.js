const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {authorizeReflection} = require('../security');
const project = process.env.GCLOUD_PROJECT;
if (project !== 'demo-moodi-security' || process.env.FUNCTIONS_TEST_ORIGIN !== 'http://127.0.0.1:5101' ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9199') {
  throw Error('Callable tests require the isolated Auth/Functions demo emulators.');
}
const call = async (data, token) => {
  const response = await fetch(`http://127.0.0.1:5101/${project}/asia-southeast1/generateReflection`, {
    method: 'POST', headers: {'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {})},
    body: JSON.stringify({data}),
  });
  return {status: response.status, body: await response.json()};
};
test('AT-07 baseline handler accepts missing auth (isolated snapshot, no external calls)', async () => {
  const source = fs.readFileSync(path.join(__dirname, '../../security-lab/baseline/reflection-handler.js.txt'), 'utf8');
  const sandbox = {exports: {}, process: {env: {}}, require: name => {
    if (name === 'firebase-functions/v2/https') return {onCall: handler => handler};
    if (name === 'firebase-functions/v2') return {setGlobalOptions: () => {}};
    if (name === 'firebase-functions/logger') return {info() {}, warn() {}, error() {}};
    if (name === '@google/genai') return {GoogleGenAI: class {constructor() {throw Error('External provider forbidden in lab');}}};
    throw Error('Unexpected dependency in baseline snapshot');
  }};
  vm.runInNewContext(source, sandbox, {timeout: 1000});
  const result = await sandbox.exports.generateReflection({data: {emotionKey: 'calm'}});
  assert.equal(typeof result.balancedThought, 'string');
});
test('AT-07 hardened HTTP endpoint rejects no token and forged token', async () => {
  for (const token of [undefined, 'forged-token']) {
    const result = await call({emotionKey: 'calm'}, token);
    assert.equal(result.status, 401);
    assert.equal(result.body.error.status, 'UNAUTHENTICATED');
  }
});
test('AT-07 authenticated endpoint rejects injected owner and malformed payload; legitimate call works', async () => {
  const response = await fetch('http://127.0.0.1:9199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key', {
    method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({returnSecureToken: true}),
  });
  assert.equal(response.status, 200);
  const {idToken} = await response.json();
  for (const data of [{emotionKey: 'calm', userId: 'alice'}, {emotionKey: 'calm', intensity: 99},
    {emotionKey: 'calm', situation: 'x'.repeat(4001)}, {emotionKey: 'calm', thought: []}]) {
    const result = await call(data, idToken);
    assert.equal(result.status, 400);
    assert.equal(result.body.error.status, 'INVALID_ARGUMENT');
  }
  const result = await call({emotionKey: 'calm', intensity: 3}, idToken);
  assert.equal(result.status, 200);
  assert.equal(typeof result.body.result.balancedThought, 'string');
});
test('AT-07 handler validation rejects unknown enums, null and array payloads', () => {
  for (const data of [null, [], {emotionKey: 'unknown'}, {emotionKey: 'calm', intensity: 2.5}]) {
    assert.throws(() => authorizeReflection({auth: {uid: 'bob'}, data}), {code: 'invalid-argument'});
  }
});
