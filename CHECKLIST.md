# Checklist Moodi

**Cập nhật:** 24/10/2026 · **Hạn nộp:** ~03/11/2026 · **Nhánh:** `feat/nest-api`

Chú thích: ✅ đã xong · ⬜ chưa làm · ➖ không làm trong đồ án này

## Backend (NestJS)
- ✅ Cấu trúc NestJS, TypeORM, PostgreSQL (Docker), Swagger tại `/docs` (ngoài production)
- ✅ Xác thực JWT: đăng ký, đăng nhập, refresh token xoay vòng (lưu SHA-256), đăng xuất thu hồi token
- ✅ Đăng nhập Google/Apple: xác minh ID token bằng JWKS, kiểm tra nonce
- ✅ Dữ liệu cá nhân: `entries`, `moments`, `reflections` (mẫu CBT + Gemini tùy chọn)
- ✅ Cộng đồng (`POST /api/community`): bảng tin, bài viết, bình luận, đồng cảm, nhóm, bạn bè, tin nhắn, thông báo, báo cáo, kiểm duyệt, chặn
- ✅ An toàn: chặn bài công khai có từ khóa khủng hoảng, giới hạn số yêu cầu, khóa tài khoản, idempotency cho thao tác ghi
- ✅ Vườn chung 2 người (`shared-gardens`): chỉ có API
- ✅ Migration tự chạy khi khởi động, script seed tài khoản test
- ✅ Module users, posts, friends, groups, chat (có WebSocket gateway), storage
- ⬜ Deploy lên server cho buổi demo
- ⬜ Đặt biến môi trường production: `JWT_*`, `DB_*`, `GOOGLE_CLIENT_IDS` (cả iOS và Web client ID)

## App Flutter
- ✅ Đã gỡ hết Firebase, mọi dữ liệu đi qua REST API
- ✅ Lưu token an toàn (`flutter_secure_storage`), khôi phục phiên khi mở app
- ✅ Onboarding, đăng nhập email, Google, Apple, chế độ khách
- ✅ **Hôm nay:** check-in, phản tư, tiện ích thư giãn, xem trước khu vườn
- ✅ **Góc riêng:** nhật ký dạng lịch tháng, khu vườn theo tháng; giữ trạng thái khi chuyển mục
- ✅ **Cộng đồng:** đủ tính năng như backend; hiện đường dây nóng khi bài bị chặn vì tín hiệu khủng hoảng
- ✅ **Khám phá:** tiến trình tuần, biểu đồ xu hướng 7/30 ngày, 7 bài thực hành, khoảng dừng dùng chung với tab Hôm nay
- ✅ **Cài đặt:** nhắc check-in hằng ngày (thông báo cục bộ), mục tiêu, giảm kích thích, xuất dữ liệu, đường dây nóng
- ✅ Hỗ trợ chữ phóng to trên màn hình hẹp, nhãn đọc màn hình (Semantics)
- ➖ Chat thời gian thực qua WebSocket (hiện tải lại định kỳ qua HTTP)
- ➖ Giao diện vườn chung 2 người
- ➖ Face ID/PIN thật (hiện chỉ có PIN demo `0000` ở bản debug)
- ➖ Lưu các cài đặt khác ngoài nhắc nhở

## Kiểm thử
- ✅ `flutter analyze` sạch, 81 test Flutter đạt
- ✅ Test backend (`npm test`) đạt
- ✅ `flutter build ios --no-codesign` thành công
- ⬜ `flutter build apk` (máy hiện chưa cài Android SDK)
- ⬜ Chạy thử cả 5 tab trên điện thoại thật với backend thật
- ⬜ Thử nhắc nhở trên máy thật (đặt giờ cách hiện tại 2–3 phút)

## Chuẩn bị demo
- ⬜ Đăng ký SHA-1 cho Android trên Firebase, tải lại `google-services.json`
- ⬜ Build app với `--dart-define=API_BASE_URL=<server>`
- ⬜ Tài khoản demo có sẵn dữ liệu: 2–3 tuần ghi chép, vài bài cộng đồng, một nhóm
- ⬜ Kịch bản demo theo từng tab
