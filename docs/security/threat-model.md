# Mô hình đe dọa và phát hiện ban đầu

## Tài sản và tác nhân

- Tài sản: nhật ký, dữ liệu vườn riêng, bản sao chia sẻ, membership, token phiên, cache và chi phí API.
- Tác nhân thử nghiệm: chưa đăng nhập; tài khoản B đã đăng nhập; thành viên hiện tại; thành viên đã rời vườn; client sửa đổi trực tiếp request.
- Điểm vào: Firestore SDK/REST, callable HTTP, dữ liệu trong client, callback/stream sau đổi phiên.
- Giả định: Firebase xác minh token đúng, dịch vụ Google và thiết bị không bị chiếm quyền; không mô phỏng trộm thông tin đăng nhập thật.

## Phát hiện dựa trên code và thực nghiệm

| Phát hiện | Mức độ trong phạm vi | Bằng chứng / khắc phục |
|---|---|---|
| Rules gốc không kiểm tra schema khi owner ghi nhật ký | Trung bình | Matrix baseline cho phép giả `userId`, thêm `role`, dữ liệu sai kiểu/quá dài. Gia cố bằng validator dùng cho create và update |
| API phản tư gốc không bắt buộc auth | Cao về lạm dụng tài nguyên | Chạy handler snapshot trong VM cô lập không token vẫn nhận phản hồi; endpoint mới trả 401 |
| Cache riêng và route có thể tồn tại qua đổi phiên | Cao nếu dữ liệu hiển thị sang tài khoản khác | Test session mới xác nhận dọn cache, đóng route, bỏ phản hồi muộn; không gán kết quả before động nếu chưa chạy baseline tương ứng |
| Repo fallback sang collection cấp gốc khi thiếu UID | Rủi ro thiết kế | Nay từ chối trước khi truy cập Firestore; collection cũ default deny |
| Biên nhận chăm sóc lặp đồng thời | Tính toàn vẹn/khả dụng | Rules cho phép replay chính xác không thay đổi dữ liệu, cấm tăng giả và reset biên nhận |

**Không được kết luận rằng app gốc cho phép B đọc nhật ký A:** matrix baseline xác nhận kiểm tra chủ sở hữu ở đường dẫn đã chặn hành vi này. Kịch bản B đọc A thành công sử dụng fixture cố ý có lỗ hổng riêng và phải nói rõ khi thuyết trình.

Trường `role` chèn vào nhật ký không được app dùng để cấp quyền; đây là schema pollution, không phải bằng chứng leo thang quyền admin thành công.

## Giới hạn và rủi ro còn lại

- Emulator không chứng minh rules/functions đang chạy trên Firebase production đúng phiên bản. Chưa deploy trong lượt triển khai này.
- Chưa thực hiện pentest độc lập, kiểm tra thiết bị bị root/jailbreak hoặc thu hồi token bị đánh cắp.
- Cache bộ nhớ ứng dụng được dọn theo phiên; chưa chứng minh xóa sạch cache trên đĩa, screenshot/app switcher hay dữ liệu đã được người nhận sao chép.
- Khóa PIN demo không được coi là biện pháp bảo mật. Thay bằng xác thực thiết bị là phần mở rộng, chưa thuộc bằng chứng hoàn thành của đợt này.
- Giới hạn tần suất API/App Check và chính sách tài khoản vẫn là phần mở rộng. Auth không chặn mọi hành vi lạm dụng từ tài khoản hợp lệ.
- Mã mời có độ ngẫu nhiên và được xoay khi rời vườn nhưng chưa có TTL; người đang giữ mã mới có thể tham gia theo thiết kế.
- Client ghi timestamp; không dùng timestamp này làm bằng chứng chống chối bỏ.
- Không có mã hóa đầu cuối; quản trị viên backend có quyền phù hợp vẫn có thể đọc dữ liệu.
- Rules là prototype đã kiểm thử theo các tình huống ghi nhận, không phải cam kết không còn lỗ hổng.
