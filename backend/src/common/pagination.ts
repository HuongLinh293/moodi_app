// Query string luôn là chuỗi; ép kiểu và chặn biên để `limit=1e9` hay `page=abc`
// không gây truy vấn quá lớn hoặc lỗi 500.
export function pageParams(
  page: unknown,
  limit: unknown,
  { defaultLimit = 10, maxLimit = 50 } = {},
): { page: number; limit: number; skip: number } {
  const p = Math.max(1, Math.min(10000, Math.trunc(Number(page)) || 1));
  const l = Math.max(1, Math.min(maxLimit, Math.trunc(Number(limit)) || defaultLimit));
  return { page: p, limit: l, skip: (p - 1) * l };
}

// Thoát ký tự đại diện của LIKE để người dùng không quét toàn bảng bằng '%'.
export function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (c) => `\\${c}`);
}
