#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Fixed demo project and loopback-only endpoints. No project argument accepted.
if [ "$#" -ne 0 ]; then
  printf 'This runner accepts no project override. Use the isolated demo environment.\n' >&2
  exit 2
fi
export FUNCTIONS_TEST_ORIGIN=http://127.0.0.1:5101
firebase emulators:exec --project demo-moodi-security \
  --config firebase.security-test.json --only auth,firestore,functions,storage \
  'npm --prefix functions run test:security'
