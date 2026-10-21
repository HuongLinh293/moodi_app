#!/usr/bin/env bash
# Chạy ma trận kiểm soát truy cập của backend NestJS trên server dev tạm thời.
# Yêu cầu: Postgres của backend/docker-compose.yml đang chạy, Node >= 20.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${SECURITY_LAB_PORT:-3100}"
export BASE="http://localhost:${PORT}/api"

if curl -s -o /dev/null "http://localhost:${PORT}"; then
  echo "Cổng ${PORT} đang bận. Đặt SECURITY_LAB_PORT khác hoặc dừng tiến trình đó." >&2
  exit 1
fi

(cd "$ROOT/backend" && npm run build >/dev/null)

LOG="$(mktemp)"
# Nâng giới hạn chung để bộ test không tự chạm trần; giới hạn đăng nhập (10/phút)
# và hạn mức Community vẫn giữ nguyên vì chúng là đối tượng kiểm thử.
# Tắt AI để nội dung test không rời máy.
(cd "$ROOT/backend" && NODE_ENV=development THROTTLE_LIMIT=5000 REFLECTION_AI_DISABLED=true \
  PORT="$PORT" exec node dist/main >"$LOG" 2>&1) &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true; rm -f "$LOG"' EXIT

for _ in $(seq 1 30); do
  curl -s -o /dev/null "$BASE/auth/providers" && break
  sleep 1
done

node "$ROOT/security-lab/nest/access-control.mjs"
node "$ROOT/security-lab/nest/moderation.mjs"
