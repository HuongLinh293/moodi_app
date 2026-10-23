# Hướng dẫn demo BTL

## Chuẩn bị

- Đọc `security-lab/README.md` và `test-results.md`.
- Dùng dữ liệu giả và chạy `./scripts/test_security.sh` trước buổi demo.
- Mở ba file rules cạnh nhau; không đăng nhập production để demo tấn công.
- Có terminal kết quả test, bảng JSON và sơ đồ kiến trúc sẵn để trình bày.

## Kịch bản 5–7 phút

1. **0:00–0:45 — Bài toán:** nhật ký riêng của A cần được bảo vệ trước tài khoản B đã đăng nhập.
2. **0:45–1:30 — Kiến trúc:** client có thể bị sửa; Auth xác định danh tính, Rules quyết định quyền đối tượng; Functions có kiểm tra riêng.
3. **1:30–2:45 — Thực nghiệm:** chạy script; chỉ ra AT-02/03 trong bản `vulnerable` nhận `allow`. Nêu rõ đây là fixture cố ý có lỗi, không đánh đồng với baseline.
4. **2:45–3:45 — Phòng chống:** chỉ ra `isOwner`, validator create/update và kết quả `hardened: deny`; AT-08 của owner vẫn `allow`.
5. **3:45–4:45 — Phát hiện thực tế:** baseline AT-04 cho phép payload sai, bản gia cố chặn; HTTP API mới từ chối không token và token giả.
6. **4:45–5:45 — Phiên và vườn:** minh họa test rời vườn, chăm sóc nguyên tử và Flutter test phản hồi muộn A → B → A.
7. **5:45–6:30 — Kết luận:** phạm vi đạt, hạn chế, chưa deploy production, không khẳng định an toàn tuyệt đối.

## Những câu hỏi cần trả lời được

- Tại sao có Firebase Auth vẫn có thể vượt quyền? Danh tính và quyền đối tượng là hai kiểm tra khác nhau.
- Tại sao không kiểm tra UID chỉ ở Flutter? Client có thể gọi trực tiếp SDK/HTTP.
- Tại sao kiểm tra create chưa đủ? Có thể tạo hợp lệ rồi update thành dữ liệu không hợp lệ.
- Tại sao cần test thao tác hợp lệ? Rules chặn tất cả cũng làm test tấn công “an toàn” nhưng app không hoạt động.
- Vì sao revision phiên ngoài UID? Cùng UID có thể đăng nhập lại trong khi request của phiên cũ còn chạy.
- Rời vườn có thu hồi được nội dung đã xem không? Chỉ chặn yêu cầu mới, không xóa bản sao người khác đã lưu.

Video và slide trình chiếu là đầu ra tiếp theo; tài liệu này là kịch bản, chưa phải video đã quay.
