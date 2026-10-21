// Chỉ nhận ảnh https hoặc file do /api/storage quản lý; chặn javascript:, data:, http:.
export const SAFE_MEDIA_URL = /^(https:\/\/[^\s"'<>]{1,480}|\/api\/storage\/[0-9a-f-]{36}\/content)$/;
