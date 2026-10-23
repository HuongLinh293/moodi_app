// Đọc lười để giá trị luôn lấy sau khi .env đã được nạp (xem main.ts).
// Production bắt buộc cấu hình secret; môi trường dev dùng giá trị mặc định cố định.
function secret(name: string, devFallback: string): string {
  const value = process.env[name];
  if (value) return value;
  if (process.env.NODE_ENV === 'production') {
    throw new Error(`${name} phải được cấu hình trong production`);
  }
  return devFallback;
}

export const jwtAccessSecret = () => secret('JWT_SECRET', 'moodi-dev-access-secret');
export const jwtRefreshSecret = () =>
  secret('JWT_REFRESH_SECRET', 'moodi-dev-refresh-secret');
export const jwtAccessTtl = () => parseInt(process.env.JWT_EXPIRATION || '3600', 10);
export const jwtRefreshTtl = () =>
  parseInt(process.env.JWT_REFRESH_EXPIRATION || '604800', 10);
