# Khôi phục build Flutter sau chuyển sang Nest API

Ngày: 2026-10-21. Phạm vi: sửa lỗi biên dịch, giữ giao diện hiện có và bổ sung API dữ liệu cá nhân trên NestJS. Chưa tuyên bố đã hoàn tất chuyển backend.

## Nguyên nhân

- Gói Firebase đã bị gỡ nhưng Community và garden_actions còn import các kiểu Firebase.
- MindraState bị thay bằng state dành cho bảng tin, mất hợp đồng mà onboarding, nhật ký, vườn và các bài tập sử dụng.
- Một lượt sửa đồng thời đã vô hiệu hóa màn hình và xóa test để tránh lỗi. Các màn hình và test đã được khôi phục.

## Đã xử lý

- Khôi phục bốn tab, onboarding, màn cá nhân và các hành vi local; dùng AuthUser/ApiException thay kiểu Firebase.
- Nối đăng nhập API qua stream trạng thái; xử lý expiresAt dạng Unix seconds của NestJS, gửi username/displayName khi đăng ký.
- Bỏ điều hướng tới route /home không được khai báo; root app điều hướng theo phiên đăng nhập.
- Giữ kiểm tra phiên để phản hồi cũ không ghi vào tài khoản mới; chờ các lệnh ghi đang chạy trước xóa dữ liệu.
- Khôi phục repository API cho dữ liệu cá nhân, báo lỗi đồng bộ thay vì trả danh sách trống khi API lỗi.
- Không ghi request body (mật khẩu/nội dung riêng tư) vào debug log HTTP.
- API_BASE_URL có thể cấu hình bằng --dart-define, mặc định http://localhost:3000 cho iOS Simulator.

## Đợt 2: server khởi động được và có API dữ liệu cá nhân

Backend trước đó build được nhưng không chạy được:

- `main.ts` import `express` (không phải dependency trực tiếp) nên crash ngay khi khởi động. Đã chuyển sang `app.useBodyParser`.
- `User.groups` (`@ManyToMany` + `@JoinTable('group_members')`) chiếm cùng bảng với entity `GroupMember`, làm TypeORM synchronize lỗi và không kết nối được DB. Đã gỡ quan hệ thừa, vì code không dùng tới.
- ChatGateway dùng socket.io nhưng thiếu `@nestjs/platform-socket.io`. Đã cài bản 10.x, cùng major với Nest.
- `PostsModule` không đăng ký controller/service nên `/posts` trả 404. Đã đăng ký.
- Secret JWT bị lệch: Auth ký bằng `'your-secret-key'`, Chat xác thực bằng `'secret'`, còn JwtStrategy là `undefined` khi thiếu `.env`. Ngoài ra decorator `@Module` đọc `process.env` trước khi `.env` được nạp. Hiện dùng chung `config/jwt.config.ts`, nạp `dotenv/config` đầu tiên, và production bắt buộc phải cấu hình secret.
- Refresh token được lưu bằng bcrypt mà không bao giờ được kiểm tra. bcrypt chỉ băm 72 byte đầu, mà các JWT của cùng một user trùng nhau ở đoạn đó. Đã đổi sang SHA-256 và so sánh khi refresh. Thêm `POST /auth/logout` (thu hồi refresh token) mà Flutter vẫn gọi.
- Flutter gọi `/auth/...` trong khi server có global prefix `api`. Đã đặt `ApiConfig.apiVersion = '/api'`.

Module mới (đều yêu cầu JWT; mọi truy vấn lấy user từ token, `userId` client gửi lên chỉ để đối chiếu và bị từ chối nếu khác):

- `entries`, `moments`: CRUD/upsert theo `PUT /:id`, lọc theo ngày/tháng/luống, `DELETE /` cần header `X-Delete-All: true`. Khóa chính `(userId, id)` để id do client sinh không đè dữ liệu người khác. Xóa một ghi chép thì gỡ luôn bông hoa đã chia sẻ trong vườn chung.
- `shared-gardens`: port ràng buộc từ firestore.rules cũ. Mỗi vườn tối đa 2 thành viên, mỗi user chỉ ở một vườn, mã mời `MD-` + 32 hex, cấp vị trí trồng tuần tự bằng khóa hàng, chỉ trồng được ghi chép của chính mình đã đồng bộ, caption chỉ gửi khi `includeCaption`, mỗi người tưới/sưởi một bông tối đa một lần, chỉ người trồng được gỡ, mã mời được xoay khi có người rời, vườn trống thì bị xóa.

Sửa phía Flutter:

- Gửi `timestamp`/`plantedAt` dạng UTC. Trước đó Dart gửi giờ local không kèm múi giờ, nên server UTC sẽ lệch 7 giờ. Model đổi giờ về local khi đọc.
- `HttpClient` hiển thị lỗi validation NestJS, vốn trả `message` dạng mảng.

## Đợt 3: vá lỗ hổng module cũ, reflections, Community, Google/Apple, lưu token an toàn

### Lỗ hổng đã vá trong các module có sẵn

| Module | Lỗ hổng | Cách sửa |
|---|---|---|
| storage | Path traversal: `filename` (`/../../x`) được ghép thẳng vào đường dẫn ghi file | Tên trên đĩa do server sinh (UUID), tên gốc chỉ làm nhãn; đường dẫn đọc/xoá bị ép nằm trong thư mục uploads |
| storage | Không kiểm tra loại file; giới hạn 50MB | Chỉ nhận JPEG/PNG/GIF/WebP/PDF, `mimeType` phải khớp magic bytes; tối đa `MAX_FILE_SIZE` (10MB) |
| storage | Route đọc không có guard nên chủ file không đọc được file private của mình; trả lỗi 403 khác 404 nên dò được id | `OptionalJwtGuard`; file private của người khác trả 404 giống file không tồn tại; không trả đường dẫn trên đĩa |
| users | `GET /users/:id` và tìm kiếm không cần đăng nhập, trả email (lộ PII, dò tài khoản); tìm theo email; `%` trong LIKE quét toàn bảng | Bắt buộc JWT; email chỉ trả cho chính chủ (`/users/me`); tìm theo username/tên, thoát ký tự LIKE, tối đa 20 |
| users | Sửa hồ sơ người khác ném `Error` thường, trả 500 | `ForbiddenException` (403) |
| users, groups, posts, chat | Ảnh/avatar nhận chuỗi tuỳ ý (`javascript:`, `data:`, theo dõi qua ảnh ngoài) | Avatar phải là file public của chính mình; ảnh khác chỉ nhận `https://` hoặc `/api/storage/<id>/content` |
| groups | Ai cũng xem được chi tiết và danh sách thành viên của mọi nhóm | Bắt buộc JWT; danh sách thành viên chỉ cho thành viên |
| posts | Bảng tin không cần đăng nhập; like song song bị tính nhiều lần (đọc rồi `++`) | Bắt buộc JWT; `INSERT … ON CONFLICT DO NOTHING` và tăng/giảm nguyên tử |
| chat | Kéo bất kỳ ai vào cuộc trò chuyện; mảng người tham gia không giới hạn | Chỉ bạn bè, tối đa 50 người; trò chuyện trực tiếp chỉ 2 người |
| chat (WebSocket) | Payload không được validate (pipe toàn cục không áp dụng cho WS); trạng thái online phát cho mọi user; CORS `*` | `ValidationPipe` riêng cho gateway; trạng thái online chỉ gửi bạn bè; CORS theo `CORS_ORIGIN` |
| chat | Tạo trò chuyện trực tiếp luôn lỗi 500 (truy vấn quan hệ `participants` không tồn tại) | Sửa truy vấn qua bảng tham gia |
| friends | Người gửi không tự huỷ được lời mời | Cho phép người gửi huỷ |
| auth | Đo thời gian phản hồi dò được email đã đăng ký; email phân biệt hoa/thường; mật khẩu > 72 byte bị bcrypt cắt | So với hash giả khi không có user; chuẩn hoá email; giới hạn 72 byte; username chỉ `[a-zA-Z0-9_.]` |
| auth | Access token vẫn dùng được sau logout | `tokenVersion` trong JWT, tăng khi logout; refresh token xoay vòng có `jti` |
| toàn cục | Không có rate limit, header bảo mật; Swagger mở ở production; `page=abc`/`limit=1e9`/id sai định dạng gây 500 hoặc truy vấn khổng lồ | `@nestjs/throttler` (300/phút/IP, đăng nhập/đăng ký 10/phút), `helmet`, tắt Swagger ở production, `pageParams` chặn biên, `ParseUUIDPipe` |

### Tính năng mới

- **`/reflections`**: port từ Cloud Function cũ. Có tín hiệu khủng hoảng thì chuyển sang luồng an toàn và không gửi nội dung ra ngoài. Nếu có `GEMINI_API_KEY` thì gọi Gemini, với nội dung người dùng được bọc trong JSON và kết quả được kiểm tra/cắt lại; nếu không có thì dùng template CBT. Mã bài tập được chuẩn hoá về 4 mã app hiểu, vì mã lạ như `box_breathing` làm dropdown sửa phản tư bị crash. Có thêm lịch sử, feedback (chỉ chủ sở hữu), gợi ý bài tập, safety-check và insights từ nhật ký. Generate giới hạn 20 lần/phút.
- **Community (`POST /api/community`)**: port đủ 27 action của `functions/community.js` sang Postgres, giữ nguyên hợp đồng nên UI không đổi:
  - Danh sách trường cho phép theo từng action.
  - Idempotency theo `requestId` (cùng id mà khác nội dung thì trả 409).
  - Hạn mức 40 lượt ghi và 240 lượt đọc mỗi phút cho mỗi user.
  - Ảnh được sharp mã hoá lại (bỏ EXIF/GPS, giới hạn pixel) và chỉ đọc được qua action sau khi kiểm tra quyền.
  - Nhóm riêng, chặn, kết bạn/nhắn tin, báo cáo, kiểm duyệt có audit log.
  - Transaction `SERIALIZABLE` có retry, tương đương transaction Firestore.
  - Quyền admin là cột `users.communityAdmin`, chỉ đặt thủ công trong DB.
- **Google/Apple**:
  - Server xác minh ID token bằng JWKS của nhà cung cấp (chỉ RS256, kiểm tra audience/issuer, tuổi token ≤ 1 giờ) và đối chiếu nonce SHA-256.
  - Chỉ liên kết với tài khoản sẵn có khi email đã được nhà cung cấp xác minh.
  - App chỉ hiện nút khi cả app (`--dart-define`) và server (`GET /auth/providers`) đã cấu hình.
- **Lưu token an toàn**:
  - Chỉ refresh token và thông tin hiển thị được lưu trong Keychain/Keystore (`first_unlock_this_device`: không đồng bộ iCloud). Access token chỉ nằm trong bộ nhớ.
  - Mở app thì khôi phục phiên. Nếu server từ chối token thì xoá; lỗi mạng thì giữ lại.
  - `HttpClient` gặp 401 thì refresh một lần, dùng chung cho các request song song, rồi thử lại. Refresh không phát sự kiện đổi user nên dữ liệu đang hiển thị không bị xoá.

### Cấu hình Google/Apple (cần tài khoản của nhóm)

1. Google:
   - Tạo OAuth client iOS (và Web/Android nếu cần) trong Google Cloud.
   - Server: đặt `GOOGLE_CLIENT_IDS=<ios-client-id>,<web-client-id>`.
   - App: chạy với `--dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>` (Android dùng `GOOGLE_SERVER_CLIENT_ID`), và thêm reversed client ID vào `CFBundleURLTypes` trong `ios/Runner/Info.plist`. Thiếu URL scheme thì SDK Google sẽ crash.
2. Apple:
   - Cần tài khoản Apple Developer trả phí. Bật capability Sign in with Apple cho target Runner trong Xcode.
   - Server: đặt `APPLE_CLIENT_IDS=com.mindra.mindra`.
   - App: chạy với `--dart-define=APPLE_SIGN_IN=true`.
   - Mình không tự thêm entitlement, vì như vậy sẽ hỏng việc build lên máy thật nếu dùng team miễn phí.

## Còn thiếu, không được xem là hoạt động production

- Chưa có Google/Apple Client ID thật, nên luồng đăng nhập mạng xã hội mới được kiểm tra phía server (token giả mạo `alg=none`/HS256 bị từ chối), chưa chạy end-to-end với tài khoản thật.
- Nonce Google cố định trong mỗi lần chạy app (google_sign_in 7 chỉ cho `initialize` một lần). Apple dùng nonce mới cho mỗi lần đăng nhập.
- Trên iOS, Keychain còn giữ sau khi xoá app. Cài lại app có thể tự đăng nhập lại nếu refresh token còn hạn (7 ngày).
- Mỗi tài khoản chỉ có một refresh token hợp lệ: đăng nhập ở máy thứ hai sẽ làm máy đầu phải đăng nhập lại sau khi access token hết hạn.
- Schema được tạo bằng `synchronize` (dev). Migration chưa có các bảng mới (`journal_entries`, `garden_moments`, `shared_*`, `ai_reflections`, `community_*`, các cột mới của `users`), nên cần sinh migration trước khi chạy production.
- Dữ liệu Community lưu uid trong mảng, không có khoá ngoại: khi xoá tài khoản, hồ sơ cộng đồng bị xoá theo, còn bài/tin nhắn cũ vẫn còn (danh sách kết nối bỏ qua người đã xoá).
- `monthKey` của bông hoa trong vườn chung tính theo tháng UTC.
- Chưa triển khai backend lên môi trường production.

## Kiểm chứng

Flutter: chạy `flutter analyze`, `flutter test` (74 test) và `flutter build ios --simulator --debug` (có google_sign_in, sign_in_with_apple, flutter_secure_storage qua Swift Package Manager). Test mới bao gồm: lưu/xoá phiên, khôi phục và xoay refresh token, token bị từ chối thì xoá còn lỗi mạng thì giữ, nhiều request 401 song song chỉ refresh một lần, Community đi qua `/api/community` và giữ mã lỗi server.

Backend: `npm run build`; chạy server với Postgres trong docker-compose:
- Bộ e2e 56 kịch bản qua cả 56: mỗi lỗ hổng ở bảng trên được thử tấn công lại, cùng các luồng reflections và Community (idempotency, react song song, nhóm riêng, chặn, nhắn tin/unread, báo cáo, rate limit).
- Luồng kiểm duyệt với admin: xem báo cáo, gỡ nội dung, khoá tài khoản, audit log.
- Token Google/Apple giả mạo bị từ chối.
- Bộ 25 bước của đợt 2 vẫn đúng.
