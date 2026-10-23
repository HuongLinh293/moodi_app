# Phòng thực nghiệm bảo mật Moodi

## Backend NestJS (kiến trúc hiện tại)

App đã chuyển từ Firebase sang NestJS + Postgres. Phần dưới đây kiểm thử đúng hệ thống app đang dùng.

```bash
docker compose -f backend/docker-compose.yml up -d postgres
./scripts/test_security_nest.sh
```

- `nest/access-control.mjs`: 56 kịch bản. Mỗi lỗ hổng đã vá (path traversal, lộ email, IDOR, ảnh `javascript:`, đếm like trùng, token còn hiệu lực sau logout, dò email qua thời gian phản hồi…) được thử tấn công lại, cùng các quy tắc phân quyền của nhật ký, vườn chung, reflections và Community (nhóm riêng, chặn, idempotency, rate limit).
- `nest/moderation.mjs`: cấp quyền admin trong DB, rồi xem báo cáo, gỡ nội dung, khoá tài khoản và kiểm tra audit log.

Script khởi động server tạm ở cổng 3100 (đổi bằng `SECURITY_LAB_PORT`), tắt AI để dữ liệu test không rời máy, và chỉ tạo tài khoản giả với email `@t.vn`. Bảng tổng hợp lỗ hổng và cách sửa nằm trong `docs/api-migration-build-status.md`.

## Firestore (lưu trữ, kiến trúc cũ)

Phần dưới đây thuộc bản Firebase trước khi chuyển đổi, giữ lại để đối chiếu trong báo cáo.

**Chỉ dùng Firebase Emulator, dữ liệu giả. Không deploy các file trong thư mục này.**

Ba phiên bản độc lập:

1. `baseline/firestore.rules`: snapshot nguyên trạng trước thay đổi ngày 19/10/2026. Đã có kiểm tra owner nhưng thiếu schema.
2. `firestore.vulnerable.rules`: fixture cố ý chỉ kiểm tra đăng nhập, bỏ kiểm tra quyền đối tượng. Không phải bản app gốc.
3. `../firestore.rules`: rules đã gia cố dùng cho code app.

`baseline/reflection-handler.js.txt` được thực thi trong VM thử nghiệm với dependency giả, không có khóa API, không network ra nhà cung cấp. Đây là kiểm thử handler của bản gốc, không phải tuyên bố đã gọi endpoint production.

## Chạy

Yêu cầu: Node phù hợp `functions/package.json`, Java phù hợp Firebase Emulator, Firebase CLI, dependencies Node đã cài. Khi thiếu dependencies, chạy `npm --prefix functions ci` từ gốc repo.

```bash
./scripts/test_security.sh
flutter analyze
flutter test
```

Runner cố định `demo-moodi-security`, chỉ bind loopback: Auth 9199, Firestore 8180, Functions 5101. Không nhận project override. Nếu cổng bận, dừng đúng Emulator của phòng lab trước khi chạy; không tự giết tiến trình khác.

`firebase.security-test.json` nằm ở gốc để đường dẫn Functions và rules rõ ràng. Script nạp rules lỗi bằng Rules Unit Testing vào Emulator trong lúc test, không sửa cấu hình deploy mặc định. Các file test chạy tuần tự để tránh xóa dữ liệu của nhau.

Kết quả chi tiết của matrix được tạo tại `results/access-control.json`. File kết quả/log được bỏ qua bởi git; có thể lưu bản tổng hợp đã rà soát vào báo cáo. Test dọn dữ liệu và script dừng Emulator sau khi kết thúc.

Một test “pass” ở bản vulnerable có thể có nghĩa **tấn công thành công đúng dự kiến**, không có nghĩa bản đó an toàn. Luôn đọc cột `actual: allow/deny` trong JSON.
