# Bảng phân quyền

| Tài nguyên / hành động | Chưa đăng nhập | Chủ sở hữu | Người khác | Thành viên vườn hiện tại | Đã rời vườn |
|---|---|---|---|---|---|
| Nhật ký, vườn riêng: đọc/list/create/update/delete | Từ chối | Cho phép nếu hợp lệ | Từ chối | Không tự có quyền nhật ký riêng | Không tự có quyền nhật ký riêng |
| Sửa `userId`, thêm trường ngoài schema | Từ chối | Từ chối | Từ chối | Từ chối | Từ chối |
| Hồ sơ `users/{uid}`: đọc | Từ chối | Cho phép | Từ chối | Chỉ hồ sơ của mình | Chỉ hồ sơ của mình |
| Hồ sơ: tự cấp `role`/`isAdmin` | Từ chối | Từ chối | Từ chối | Từ chối | Từ chối |
| Vườn chung và khoảnh khắc: đọc/list | Từ chối | Theo membership | Từ chối nếu ngoài vườn | Cho phép | Từ chối yêu cầu server mới |
| Vào vườn | Từ chối | Không tự thêm người khác | Cần mã mời hiện hành và còn chỗ | Không được vượt 2 người | Cần mã mời mới hợp lệ |
| Rời vườn | Từ chối | Chỉ rời với UID của mình | Từ chối | Chỉ xóa chính mình, xoay mã | Không được sửa ACL |
| Gieo khoảnh khắc | Từ chối | Cần là thành viên | Từ chối nếu ngoài vườn | Chỉ gắn entry riêng của mình; tác giả bị ràng buộc | Từ chối |
| Chăm sóc | Từ chối | Cần là thành viên | Từ chối nếu ngoài vườn | Biên nhận riêng + thay đổi bộ đếm nguyên tử | Từ chối |
| Đọc mã mời | Từ chối | GET đúng mã | GET đúng mã | GET đúng mã | GET đúng mã; mã cũ không cấp lại quyền |
| Liệt kê toàn bộ mã mời | Từ chối | Từ chối | Từ chối | Từ chối | Từ chối |
| API phản tư | Từ chối | Auth + payload hợp lệ | Chỉ xử lý payload mình gửi | Tương tự | Tương tự |

Mã mời là quyền truy cập dạng bí mật chia sẻ: ai có mã còn hiệu lực có thể tham gia khi còn chỗ. Đây là hành vi có chủ đích, không phải vượt quyền. Không được đưa mã thật vào báo cáo.

Ghi chép đã chia sẻ là bản sao nội dung; thành viên khác được đọc bản sao đó, không được đọc toàn bộ nhật ký gốc. Thu hồi quyền không xóa được nội dung người khác đã sao chép.
