# Moodi

Ứng dụng di động giúp người dùng **nhận biết cảm xúc, ghi nhật ký và chủ động chọn cách phản hồi**. Moodi là công cụ tự phản tư nhẹ nhàng, không thay thế chăm sóc y tế hay hỗ trợ khủng hoảng chuyên nghiệp.

- **App:** Flutter (iOS, Android)
- **Backend:** NestJS + TypeORM + PostgreSQL, xác thực JWT (access + refresh token xoay vòng)
- **Đăng nhập:** email/mật khẩu, Google, Apple (tùy cấu hình), chế độ khách

## Tính năng

| Tab | Tính năng chính |
|---|---|
| **Hôm nay** | Check-in cảm xúc (cảm xúc, cường độ, tác nhân, suy nghĩ), phản tư theo mẫu CBT hoặc Gemini (nếu có API key), tiện ích thư giãn (Nghỉ 30 giây, Vò giấy xả giận, Bưu thiếp tuần, Bài tập ngắn), xem trước khu vườn |
| **Góc riêng** | Nhật ký dạng lịch tháng, xem chi tiết ngày, ghi bù ngày cũ, sửa/xóa; Khu vườn origami theo tháng, giữ ghi chép thành "khoảnh khắc" |
| **Cộng đồng** | Bảng tin chung lọc theo cảm xúc, đăng bài kèm ảnh, "Đồng cảm", bình luận, nhóm riêng (mời, quản lý thành viên), bạn bè bằng mã, tin nhắn riêng, thông báo, báo cáo và kiểm duyệt cho admin |
| **Khám phá** | Tiến trình tuần (4 chỉ số, biểu đồ xu hướng 7/30 ngày, nhịp lặp lại, phân bố cảm xúc, huy hiệu, nhìn lại tuần); Thực hành (thở 4-7-8, thở hộp, neo 5-4-3-2-1, nhìn lại suy nghĩ, quét cơ thể…) |
| **Cài đặt** | Nhắc check-in hằng ngày, mục tiêu cá nhân, chế độ giảm kích thích, đồng ý dùng AI, xuất dữ liệu, đường dây nóng hỗ trợ |

**An toàn:** bài viết công khai có từ khóa khủng hoảng sẽ bị chặn và app hiện danh sách đường dây nóng (111, Ngày Mai, 115). Server giới hạn số yêu cầu, hỗ trợ khóa tài khoản, và xác minh token Google/Apple bằng khóa công khai của nhà cung cấp.

## Cấu trúc thư mục

```
lib/
├── screens/        # Màn hình theo tab
├── community/      # Toàn bộ tab Cộng đồng
├── widgets/        # Thành phần UI dùng chung
├── state/          # MindraState (Provider)
├── repositories/   # Gọi REST API
├── models/         # Data models
└── core/           # HTTP client, cấu hình API, theme, đăng nhập MXH, nhắc nhở
backend/src/
├── auth/           # Đăng ký, đăng nhập, refresh, Google/Apple
├── entries/        # Ghi chép cảm xúc
├── moments/        # Khoảnh khắc trong khu vườn
├── reflections/    # Phản tư (mẫu CBT + Gemini)
├── community/      # API cộng đồng (POST /api/community, theo action)
├── shared-gardens/ # Vườn chung 2 người (chỉ có API, chưa có giao diện)
└── users, posts, friends, groups, chat, storage, notifications
test/               # Test Flutter
```

## Chạy dự án

### Yêu cầu
- Flutter 3.47+ (Dart 3.13+)
- Node.js 18+ và Docker (để chạy PostgreSQL)
- Xcode (iOS) và/hoặc Android SDK (Android)

### 1. Backend

```bash
cd backend
npm install
cp .env.example .env        # điền DB_*, JWT_SECRET, JWT_REFRESH_SECRET
docker compose up -d postgres
npm run start:dev           # http://localhost:3000/api, Swagger tại /docs
npm run seed                # (tùy chọn) tạo tài khoản test
```

- Ngoài production, schema tự đồng bộ và migration tự chạy khi server khởi động, nên không cần chạy migration riêng.
- Tài khoản do seed tạo: `alice@moodi.com`, `bob@moodi.com`, `charlie@moodi.com`, `diana@moodi.com`, mật khẩu `password123`.
- Các biến tùy chọn: `GOOGLE_CLIENT_IDS`, `APPLE_CLIENT_IDS` (để trống thì app ẩn nút đăng nhập tương ứng), `GEMINI_API_KEY` (để trống thì phản tư dùng mẫu có sẵn).

### 2. App

```bash
flutter pub get
flutter run                                                        # iOS Simulator (localhost)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000        # Android Emulator
flutter run --dart-define=API_BASE_URL=http://<IP-máy-tính>:3000   # Điện thoại thật cùng Wi-Fi
```

`API_BASE_URL` mặc định là `http://localhost:3000`. Trên điện thoại thật, địa chỉ này không gọi được, nên phải truyền IP máy chạy backend hoặc URL server đã deploy.

### 3. Đăng nhập Google (tùy chọn)
- **iOS:** đã cấu hình sẵn (client ID và URL scheme trong `ios/Runner`).
- **Android:** thêm SHA-1 của keystore vào app `com.mindra.mindra` trên Firebase Console, rồi tải lại `android/app/google-services.json`.
- **Server:** `GOOGLE_CLIENT_IDS` phải chứa cả iOS client ID và Web client ID, cách nhau bằng dấu phẩy.

## Kiểm thử

```bash
flutter analyze
flutter test              # test Flutter
cd backend && npm test    # test backend
```

## Giới hạn đã biết
- Chat dùng HTTP (tải lại định kỳ). Backend đã có WebSocket gateway nhưng app chưa dùng.
- Vườn chung 2 người mới có API, chưa có giao diện.
- Khóa ứng dụng chỉ là bản demo PIN `0000`, chỉ hiện ở bản debug.
- Phần lớn cài đặt (trừ nhắc nhở) chưa được lưu lại sau khi tắt app.

## Tài liệu khác
- [CHECKLIST.md](CHECKLIST.md): những gì đã xong và còn lại
- [plan.md](plan.md): kế hoạch tới ngày nộp
- [docs/api-migration-build-status.md](docs/api-migration-build-status.md): nhật ký chuyển từ Firebase sang NestJS
- [backend/README.md](backend/README.md): chi tiết backend

Thư mục `functions/` là Cloud Functions của giai đoạn Firebase cũ, app hiện không còn dùng.
