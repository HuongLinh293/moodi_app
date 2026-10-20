# Kết quả kiểm thử bảo mật

Ngày thực hiện: 19/10/2026. Đây là kết quả trên workspace và Firebase Emulator, chưa phải kết quả production.

## Mốc ban đầu

- `flutter analyze`: sạch.
- `flutter test`: 38/38 đạt trước các thay đổi của đợt này.
- Rules gốc được giữ nguyên trong `security-lab/baseline/firestore.rules`.
- Snapshot handler gốc ở `security-lab/baseline/reflection-handler.js.txt`.

## Ma trận rules trước–sau

`functions/test/security.test.js` chạy 26 phép thử trên mỗi phiên bản, tổng 78 phép đối chiếu. Kết quả JSON được tạo tự động ở `security-lab/results/access-control.json` sau mỗi lần chạy.

| Nhóm | Baseline thực tế | Fixture cố ý có lỗ hổng | Bản gia cố |
|---|---|---|---|
| AT-01 chưa đăng nhập | Từ chối | Từ chối | Từ chối |
| AT-02 đọc/list nhật ký người khác | Từ chối | Cho phép — lỗ hổng minh họa | Từ chối |
| AT-03 tạo/sửa/xóa dưới owner khác | Từ chối | Cho phép — lỗ hổng minh họa | Từ chối |
| AT-04 sửa owner trong dữ liệu, trường quyền, schema | Cho phép — thiếu validator | Cho phép | Từ chối |
| AT-05 ngoài vườn đọc/tự thêm membership | Từ chối | Cho phép | Từ chối |
| AT-06 membership đã bị thu hồi | Từ chối | Cho phép | Từ chối |
| AT-08 owner và thành viên hợp lệ | Cho phép | Cho phép | Cho phép |

Tổng số kết quả `allow/deny` trong matrix:

- Baseline: 15 allow / 11 deny.
- Vulnerable: 24 allow / 2 deny.
- Hardened: 6 allow / 20 deny.

Không suy luận mức an toàn chỉ bằng số lần deny: 6 thao tác hợp lệ trong mỗi vòng cũng phải thành công.

## API và vườn chung

- Handler baseline chạy trong VM cô lập chấp nhận không có auth. Đây là test handler, không phải gọi endpoint production.
- HTTP callable trên Emulator trả 401 cho không token/token giả; trả 400 cho owner bị chèn, mức độ sai và nội dung quá dài/sai kiểu.
- Token thật do Auth Emulator phát hành + payload hợp lệ nhận phản hồi thành công; không gọi AI bên ngoài.
- Kiểm tra query vườn của thành viên, cấm liệt kê mã mời, giới hạn hai thành viên và xoay mã khi rời.
- Sau thao tác leave thật, yêu cầu đọc vườn, đọc khoảnh khắc và chăm sóc đều bị từ chối; mã cũ không thể dùng lại.
- Hai người gieo hoa đồng thời: vị trí không trùng; yêu cầu lặp không tạo thêm hoa.
- Chăm sóc đồng thời: chỉ tăng một lần; chặn tăng số giả, reset biên nhận hoặc ghi biên nhận của người khác.
- Private garden và goal có positive/negative tests cho schema, tham chiếu entry, ngày bất biến, query và delete.

Kết quả xác nhận cuối: **91/91 test backend đạt**, **44/44 test Flutter đạt**, `flutter analyze` sạch. Số backend bao gồm test cha của matrix. [Bản tổng hợp bằng chứng và hash source](evidence-summary.json) ghi lại kết quả của lần chạy này.

## Phiên Flutter

`test/session_security_test.dart` có 6 kiểm thử:

1. Đổi tài khoản dọn nhật ký, mục tiêu, phản tư, tổng kết tuần và trạng thái ghi chưa đồng bộ.
2. Phản tư trả về muộn không lọt vào phiên mới, kể cả A → B → A.
3. Kết quả tải vườn muộn không đưa dữ liệu cũ vào phiên mới.
4. Đăng xuất thất bại không giả báo thành công; thành công thì dọn cache.
5. Đăng xuất loại bỏ route chi tiết riêng tư đang nằm trên Navigator.
6. Repository từ chối thiếu UID thay vì chuyển sang collection chung cấp gốc.

## Giới hạn bằng chứng

- Chưa chạy thao tác thủ công trên bản iOS được build từ các thay đổi mới trong đợt này.
- Giao dịch Firestore được kiểm thử qua JS SDK có cùng cấu trúc request; đây không phải integration test trực tiếp của plugin Flutter trên iPhone.
- Bộ test không bao phủ mọi tổ hợp trạng thái, DoS, root/jailbreak, cache trên đĩa hoặc token bị đánh cắp.
- Chưa deploy rules/functions. Trước khi triển khai thật cần rà dữ liệu legacy và cấu hình production.

## Tài liệu kỹ thuật đối chiếu

- [Firebase: kiểm tra trường và diff trong Security Rules](https://firebase.google.com/docs/firestore/security/rules-fields).
- [Firebase: callable functions và ngữ cảnh xác thực](https://firebase.google.com/docs/functions/callable).

Prototype notice:

> I've set up prototype Security Rules to keep the data in Firestore safe. They are designed to be secure for owner-scoped private data, membership-scoped shared gardens, and validated create/update operations. However, you should review and verify them before broadly sharing your app. If you'd like, I can help you harden these rules.
