# Moodi

Ứng dụng di động giúp người dùng **nhận biết cảm xúc, ghi nhật ký và chủ động chọn cách phản hồi**. Moodi là công cụ tự phản tư nhẹ nhàng, không thay thế chăm sóc y tế hay hỗ trợ khủng hoảng chuyên nghiệp.

- **App:** Flutter (iOS, Android)
- **Backend:** NestJS + TypeORM + PostgreSQL, xác thực JWT (access token + refresh token xoay vòng)
- **Đăng nhập:** email/mật khẩu (có khôi phục mật khẩu qua email), Google, Apple (tùy cấu hình)

## Tính năng

| Tab | Tính năng chính |
|---|---|
| **Hôm nay** | Check-in nhanh hoặc đầy đủ (10 cảm xúc, mức độ 1–5, tác nhân, suy nghĩ); phản tư theo mẫu CBT hoặc bằng Gemini nếu người dùng đồng ý; tiện ích thư giãn (Nghỉ 30 giây, Vò giấy xả giận, Bưu thiếp tuần, bài tập ngắn) |
| **Góc riêng** | Nhật ký dạng lịch tháng, ghi bù ngày cũ, sửa/xóa ghi chép; khu vườn origami theo tháng |
| **Cộng đồng** | Bảng tin lọc theo cảm xúc, đăng bài kèm ảnh, "Đồng cảm", bình luận, nhóm, bạn bè, tin nhắn riêng, thông báo, chặn và báo cáo; admin xử lý báo cáo |
| **Khám phá** | Tiến trình tuần, xu hướng 7/30 ngày, khám phá mẫu hình (tác nhân, thời điểm, hiệu quả bài tập), huy hiệu, nhìn lại tuần; bài thực hành (thở 4-7-8, thở hộp, neo 5-4-3-2-1, nhìn lại suy nghĩ, quét cơ thể…) |
| **Cài đặt** | Nhắc check-in hằng ngày, mục tiêu cá nhân, chế độ giảm kích thích, khóa app bằng Face ID/vân tay/mã máy, đồng ý dùng AI, xuất và xóa toàn bộ dữ liệu, đường dây nóng |

### An toàn và riêng tư
- **Phát hiện khủng hoảng:** chạy cả trên app lẫn server, nhận diện từ khóa có dấu và không dấu. Khi phát hiện, nội dung **không được gửi cho AI**; app hiện đường dây nóng (111, Ngày Mai, 115). Bài và bình luận công khai có tín hiệu khủng hoảng bị chặn.
- **AI là tùy chọn:** mặc định tắt. Gemini quá tải thì thử lại, rồi chuyển sang model dự phòng, cuối cùng dùng mẫu CBT có sẵn.
- **Dữ liệu trên máy:** nhật ký được lưu mã hóa trong Keychain/Keystore và tự đồng bộ lại khi có mạng.
- **Server:** giới hạn số yêu cầu, đình chỉ tài khoản cộng đồng, xác minh token Google/Apple bằng khóa công khai của nhà cung cấp. Mã khôi phục mật khẩu chỉ lưu dạng hash và không làm lộ email nào đã đăng ký.

## Cấu trúc thư mục

```
lib/
├── screens/        # Màn hình theo tab, đăng nhập, khóa app, khôi phục mật khẩu
├── community/      # Toàn bộ tab Cộng đồng
├── widgets/        # Thành phần UI dùng chung
├── state/          # MindraState (Provider): trạng thái, đồng bộ, cache
├── repositories/   # Gọi REST API, cache nhật ký mã hóa
├── models/         # Data models
└── core/           # HTTP client, cấu hình API, theme, đăng nhập MXH, nhắc nhở, xác thực thiết bị
backend/src/
├── auth/           # Đăng ký, đăng nhập, refresh, Google/Apple, khôi phục mật khẩu
├── entries/        # Ghi chép cảm xúc
├── practice/       # Buổi thực hành
├── moments/        # Khoảnh khắc trong khu vườn
├── reflections/    # Phản tư (mẫu CBT + Gemini), phát hiện khủng hoảng
├── community/      # API cộng đồng: một endpoint POST /api/community, chia theo action
├── shared-gardens/ # Vườn chung 2 người (chỉ có API, chưa có giao diện)
├── database/       # Migration và seed
└── users, storage, notifications, config, common
test/               # Test Flutter
```

## Chạy dự án

### Yêu cầu
- Flutter 3.47+ (Dart 3.13+)
- Node.js 18+ và Docker
- Xcode (iOS) và/hoặc Android SDK (Android)

### 1. Backend

```bash
cd backend
npm install
cp .env.example .env        # giá trị mặc định chạy được ngay với Docker
docker compose up -d        # PostgreSQL, Redis, Adminer
npm run start:dev           # API: http://localhost:3000/api · Swagger: /docs
npm run seed                # (tùy chọn) tạo tài khoản test
```

- Khi không chạy production, schema tự đồng bộ và migration tự chạy lúc server khởi động.
- **Backend phải đang chạy** thì app mới đăng nhập được. Nếu app báo "Không thể kết nối dịch vụ đăng nhập", hãy kiểm tra bước `npm run start:dev`.
- Tài khoản seed: `alice@moodi.com`, `bob@moodi.com`, `charlie@moodi.com`, `diana@moodi.com`, mật khẩu `password123`.

**Biến môi trường tùy chọn** (để trống thì tính năng tương ứng tắt):

| Biến | Dùng cho |
|---|---|
| `GEMINI_API_KEY` | Phản tư bằng AI; để trống thì dùng mẫu CBT. Có thể đổi model bằng `GEMINI_MODEL`, `GEMINI_FALLBACK_MODEL` |
| `GOOGLE_CLIENT_IDS`, `APPLE_CLIENT_IDS` | Đăng nhập Google/Apple; để trống thì app ẩn nút |
| `RESEND_API_KEY`, `PASSWORD_RESET_FROM` | Gửi mã khôi phục mật khẩu qua [Resend](https://resend.com); cần xác minh domain người gửi |

### 2. App

```bash
flutter pub get
flutter run                                                        # iOS Simulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000        # Android Emulator
flutter run --dart-define=API_BASE_URL=http://<IP-máy-tính>:3000   # Điện thoại/iPad thật
```

`API_BASE_URL` mặc định là `http://localhost:3000`. Trên thiết bị thật, `localhost` là chính thiết bị đó, nên phải truyền IP LAN của máy chạy backend (máy và điện thoại cùng Wi-Fi). Xem IP trên macOS bằng `ipconfig getifaddr en0`. Lần đầu, iOS sẽ hỏi quyền truy cập mạng cục bộ: chọn Cho phép.

### 3. Đăng nhập Google (tùy chọn)
- **iOS:** đã cấu hình sẵn (client ID và URL scheme trong `ios/Runner`).
- **Android:** thêm SHA-1 của keystore vào app `com.mindra.mindra` trên Firebase Console, rồi tải lại `android/app/google-services.json`.
- **Server:** `GOOGLE_CLIENT_IDS` phải chứa cả iOS client ID và Web client ID, cách nhau bằng dấu phẩy.

## Xem dữ liệu và cấp quyền admin

**Adminer** (đi kèm `docker compose`): mở http://localhost:8080 và đăng nhập:

| System | Server | Username | Password | Database |
|---|---|---|---|---|
| PostgreSQL | `postgres` | `postgres` | `postgres` | `moodi_db` |

Server là `postgres` (tên service trong Docker), **không phải** `localhost`. Đây là mật khẩu cho môi trường dev, không dùng khi deploy.

**Admin cộng đồng:** không có tài khoản admin mặc định. Quyền chỉ được cấp thủ công trong DB, bằng cách đổi cột `communityAdmin` của user thành `true`:

```bash
docker exec moodi_postgres psql -U postgres -d moodi_db \
  -c "UPDATE users SET \"communityAdmin\" = true WHERE email = 'alice@moodi.com';"
```

Admin thấy mục **"Xử lý báo cáo"** trong menu tab Cộng đồng. Ở đó admin có thể bỏ qua báo cáo, gỡ bài/bình luận, đình chỉ hoặc khôi phục người dùng. Không có admin cho dữ liệu cá nhân: nhật ký, phản tư và khu vườn chỉ chủ tài khoản xem được.

## Kiểm thử

```bash
flutter analyze
flutter test              # test Flutter, gồm test bố cục ở 320px với chữ 200%
cd backend && npm test    # test backend
```

## Giới hạn đã biết
- Tin nhắn và thông báo cộng đồng tải lại định kỳ qua HTTP, chưa có thời gian thực.
- Vườn chung 2 người mới có API, chưa có giao diện.
- Khôi phục mật khẩu chỉ hoạt động khi đã cấu hình Resend.
- Gemini hay quá tải. Khi cả model chính lẫn model dự phòng đều lỗi, phản tư dùng mẫu CBT, và app ghi rõ nguồn.
- Cache nhật ký trên máy được ghi lại toàn bộ mỗi lần thay đổi, nên có thể chậm khi có hàng trăm ghi chép.

## Tài liệu khác
- [CHECKLIST.md](CHECKLIST.md): những gì đã xong và còn lại
- [plan.md](plan.md): kế hoạch tới ngày nộp
- [backend/README.md](backend/README.md): chi tiết backend
- [docs/uiux-review-2026-11-06.md](docs/uiux-review-2026-11-06.md) và [ma trận kiểm thử luồng](docs/uiux-flow-test-matrix-2026-11-06.md): review UI/UX ngày 06/11 (nhiều lỗi trong đó đã được sửa sau đó)
- [docs/api-migration-build-status.md](docs/api-migration-build-status.md): nhật ký chuyển từ Firebase sang NestJS

Thư mục `functions/` là Cloud Functions của giai đoạn Firebase cũ, app hiện không còn dùng.
