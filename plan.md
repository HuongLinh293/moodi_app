# Kế hoạch Moodi tới ngày nộp

**Cập nhật:** 24/10/2026 · **Hạn nộp:** ~03/11/2026

## Hiện trạng
Đã chuyển xong từ Firebase sang **NestJS + PostgreSQL**. App Flutter đã có đủ 5 phần (Hôm nay, Góc riêng, Cộng đồng, Khám phá, Cài đặt) và đều gọi API thật. Chi tiết từng hạng mục xem ở [CHECKLIST.md](CHECKLIST.md).

Nguyên tắc cho thời gian còn lại: **không thêm tính năng lớn**, chỉ làm cho bản demo chạy ổn định trên máy thật.

## Việc còn lại

| # | Việc | Ước lượng | Gợi ý thời điểm |
|---|---|---|---|
| 1 | Cài Android SDK, chạy `flutter build apk`, sửa lỗi nếu có | 1–2 giờ | 25–26/10 |
| 2 | Deploy backend (hoặc chốt dùng IP mạng LAN), đặt biến môi trường production | 2–3 giờ | 26–27/10 |
| 3 | Đăng ký SHA-1 Android trên Firebase, thêm Web client ID vào server | 30 phút | 27/10 |
| 4 | Chạy thử cả 5 tab trên điện thoại thật, ghi lại và sửa lỗi | 1 ngày | 28–29/10 |
| 5 | Tạo tài khoản demo có dữ liệu, viết kịch bản demo | 2–3 giờ | 30/10 |
| 6 | Báo cáo, slide, tập demo | 2 ngày | 31/10–02/11 |
| 7 | Dự phòng | 1 ngày | 03/11 |

## Không làm trong đồ án này
- Chat thời gian thực bằng WebSocket. Backend đã có gateway, nên ghi vào phần hướng phát triển.
- Giao diện vườn chung 2 người (API đã có).
- Face ID/PIN thật, lưu các cài đặt khác, dark mode, đa ngôn ngữ.

## Hướng phát triển (cho báo cáo)
- Chat thời gian thực, thông báo đẩy (FCM/APNs)
- Vườn chung với người thân
- Khóa ứng dụng bằng sinh trắc học
- Gợi ý bài thực hành dựa trên nhịp cảm xúc lặp lại
