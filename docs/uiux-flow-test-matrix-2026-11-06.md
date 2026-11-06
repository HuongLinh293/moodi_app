# Ma trận kiểm thử luồng thực tế Moodi

Ngày lập: 06/11/2026. Đi cùng [báo cáo review](uiux-review-2026-11-06.md).

**Đây là kế hoạch kiểm thử tích hợp, không phải danh sách test đã pass.** Các lỗi đã tái hiện bằng probe được ghi trong cột Ghi chú; các dòng còn lại chưa chạy end-to-end với backend thật trong lần review này.

## Chuẩn bị

- Dùng backend test, DB test và hai tài khoản A/B; không thử xóa dữ liệu người dùng thật.
- Ghi commit app/backend, phiên bản OS, loại thiết bị, timezone, trạng thái quyền notification, cấu hình Google/Apple/Gemini và điều kiện mạng.
- Có dữ liệu: tài khoản rỗng; một entry hôm nay; nhiều entry cùng ngày; chỉ có entry cũ; hơn 50 phản tư; nhiều bài thực hành; nhóm với A chủ nhóm/B thành viên.
- Mỗi case ghi: Pass/Fail/Blocked, ảnh/video hoặc log, kết quả server, trạng thái sau restart. Dữ liệu xuất/ghi chú test chỉ dùng nội dung giả.
- Ma trận thiết bị tối thiểu: iOS và Android; màn hẹp, màn thường; text 100/150/200%; có/không bàn phím; VoiceOver/TalkBack; Reduce Motion; airplane mode; background/resume.

## A. Mở app và tài khoản

| ID | Thao tác | Kỳ vọng | Ghi chú review |
|---|---|---|---|
| A01 | Cài mới, mở app | Splash rồi onboarding, không chớp màn khác | Có test widget nền |
| A02 | Đi hết 3 trang, back, chọn mục tiêu | Lưu lựa chọn, chuyển login, không tự xác thực | Chưa chạy thiết bị thật |
| A03 | Onboarding ở text 200%, 320×568 | Nội dung và CTA đọc/bấm được | Probe trang 1 đang overflow F10 |
| A04 | Đăng ký với tên rỗng, email hợp lệ, password đủ | Tạo tài khoản, tên fallback dễ hiểu, đi Home | Cần backend |
| A05 | Email sai, password ngắn, xác nhận khác | Lỗi gắn đúng field, không mất các field đã nhập | Cần manual keyboard/focus |
| A06 | Email trùng, spam submit, mạng timeout | Thông báo phù hợp, không tạo trùng | Cần backend |
| A07 | Login thành công rồi kill/reopen | Khôi phục đúng tài khoản, dữ liệu tải rõ trạng thái | Chưa E2E |
| A08 | Refresh token hết hạn/bị thu hồi | Về login có giải thích, không lộ nội dung cũ | Có unit test token, chưa UI thật |
| A09 | Mở app offline khi có phiên đã lưu | Không đánh đồng lỗi mạng với mất tài khoản; nội dung local theo thiết kế | F03/F11 |
| A10 | Google/Apple bật/tắt đúng cấu hình, hủy popup | Chỉ xuất hiện phương thức hỗ trợ; hủy không báo lỗi sai | Cần native provider |
| A11 | Password manager, paste, autofill, Next/Done | Nhập thuận tiện, submit một lần, focus hợp lý | F28 |
| A12 | A logout, B login rồi A login lại | Route/nháp/cảm xúc/dữ liệu không lẫn nhau | F16; có test session nền |
| A13 | Quên password | Có đường phục hồi hoạt động và xử lý retry | Chưa có flow F28 |

## B. Check-in và lưu dữ liệu

| ID | Thao tác | Kỳ vọng | Ghi chú review |
|---|---|---|---|
| B01 | Chưa chọn gì → chọn Vui đầu tiên | UI đổi ngay, lưu khả dụng | Tái hiện thiếu notification F01 |
| B02 | Lần đầu chọn lần lượt các cảm xúc còn lại | Hiển thị, label, semantics và màu chính xác | Cần test đủ cảm xúc |
| B03 | Chưa chọn cảm xúc → chạm lưu | Không tạo entry mặc định | Đã có test nền một số nhánh |
| B04 | Quick check-in, mức 1 và mức 5 | Lưu đúng cảm xúc/cường độ/thời gian | Cần API thật |
| B05 | Full check-in có trigger và đủ 3 trường | Đọc lại đúng từng trường, không cắt mất | F17 |
| B06 | Chuyển Full → Nhanh → Full trước khi lưu | Nháp không mất, việc bỏ bối cảnh được nói rõ | Cần chốt UX |
| B07 | Thoát bằng X/back/swipe/tap ngoài sau khi viết | Giữ nháp hoặc confirm trước mất | Thiếu guard F18 |
| B08 | Lưu offline → force-close → reopen | Phục hồi entry chưa gửi, không báo synced giả | Chưa có outbox bền F03 |
| B09 | Retry cùng entry nhiều lần | Không trùng, trạng thái tiến tới synced | Có test fake, cần server |
| B10 | Đảo thứ tự request sửa A/B | Server và UI giữ B | Rủi ro F09, cần inject latency |
| B11 | Lưu rồi lập tức logout/đổi tài khoản | Pending có xử lý rõ; response cũ không rò/lẫn | Cần chạy thực tế |
| B12 | Cảnh báo đồng bộ rồi giữ hoa | Lời mời không che trạng thái chưa lưu bền | F03 |
| B13 | Mở check-in khi keyboard đang hiện, text 200% | Cuộn tới mọi field/CTA, không overflow | F10 |
| B14 | Check-in trước/sau nửa đêm theo timezone máy | Entry vào đúng ngày, không tự đổi ngày do UTC | Chưa chạy |

## C. Phản tư

| ID | Thao tác | Kỳ vọng | Ghi chú review |
|---|---|---|---|
| C01 | Lưu full rồi xem gợi ý | Mở đúng entry và nói rõ nguồn | Cần backend thật |
| C02 | Trong phản tư → Xem trong Lịch & Nhật ký | Đóng route hiện tại, chọn đúng nhật ký, không crash | Probe tái hiện exception F02 |
| C03 | Mở phản tư từ nhật ký rồi X/back | Trở về đúng ngày, giữ vị trí | Chưa E2E |
| C04 | Gemini tắt/key sai/timeout | Mẫu có sẵn rõ nguồn, không spinner vô hạn | Có backend unit tests |
| C05 | Nội dung safety giả lập có/không mạng | Hiện flow hỗ trợ đúng, không tạo gợi ý suy diễn | Không dùng dữ liệu cá nhân thật |
| C06 | Tắt AI trước khi bắt đầu và trong lúc chờ | Không có request mới ngoài lựa chọn, trạng thái rõ | Cần kiểm tra request đang chạy |
| C07 | Sửa journal A thành B sau khi có reflection | Phản tư B hoặc yêu cầu tạo lại rõ; không trả A âm thầm | F06 |
| C08 | Cần sửa → lưu → mở editor lần nữa | Thấy bản chỉnh cuối | F14 |
| C09 | Feedback Rất đúng/Chưa hợp, restart | Feedback và lựa chọn bỏ gợi ý giữ đúng | F14 |
| C10 | Đọc/chỉnh local fallback rồi server về muộn | Không ghi đè bản đang chỉnh; mở lại có quy ước | Cần latency thật |
| C11 | Xóa entry khi generate đang chạy | Kết quả muộn không hồi sinh reflection của entry đã xóa | F08 |
| C12 | Hơn 50 reflection, mở entry cũ | Có đường lấy phản tư cũ thay vì mất nút không giải thích | Cần dữ liệu lớn |

## D. Nhật ký và vườn

| ID | Thao tác | Kỳ vọng | Ghi chú review |
|---|---|---|---|
| D01 | Mở tài khoản có lịch sử khi mạng chậm/hỏng | Loading/error phân biệt empty | F11 |
| D02 | Nhiều entry cùng ngày, mở từng entry | Đủ trường, đúng thứ tự, không nhầm entry | F17 |
| D03 | Ghi bù ngày cũ và chạm ngày tương lai | Ngày cũ đúng thời gian; ngày tương lai bị chặn rõ | Có code/test nền |
| D04 | Sửa emotion/intensity/trigger/3 trường | Sửa được toàn bộ dữ liệu đã nhập | F17 |
| D05 | Xóa entry, hủy xóa, xóa khi offline | Chỉ xóa khi thành công, lỗi giữ dữ liệu | Có test nền, cần backend |
| D06 | Xóa entry có hoa và reflection | Dọn đúng tất cả liên quan theo scope | F08 |
| D07 | Giữ cùng entry vào vườn, double tap/retry | Một hoa, tháng đúng timestamp entry | Có test fake |
| D08 | Bỏ hoa, mở nhật ký | Entry vẫn còn, label nói đúng | Có logic hiện tại |
| D09 | Chạm hoa, mở danh sách, đọc screen reader | Có đường không phụ thuộc vị trí/màu/gesture | Cần thiết bị thật |
| D10 | Đổi tháng/ngày → sang tab khác → quay lại | Giữ vị trí đang xem | F12 |
| D11 | Tắt setting vườn | Hành vi đúng phạm vi mô tả | F25 |
| D12 | Lịch 320px, text 200%, tháng dài | Ô ngày không clip, ngày chọn còn rõ | Probe overflow F10 |

## E. Tạm dừng, vò giấy và thực hành

| ID | Thao tác | Kỳ vọng | Ghi chú review |
|---|---|---|---|
| E01 | Đọc bước cơ thể lâu rồi mới tới thở | Nhịp bắt đầu khi tới bước thở | Hiện start ở init |
| E02 | Bỏ qua thở, chọn Tôi không chắc, lưu | Không tự ghi bình yên hay mức cải thiện | Probe sai dữ liệu F04 |
| E03 | Chọn từng hành động cuối Pause | Đúng đích, không pop hai route, không chồng sheet | Nhánh viết qua probe mở được; cần native |
| E04 | Bật reduced motion ở app và OS | Không có phóng to/flip/haptic ngoài ý muốn | F19 |
| E05 | Viết giấy rồi X/back; thả rồi Undo | Bảo vệ nháp và khôi phục đúng nội dung | Có test nền |
| E06 | Undo hết hạn, close/reopen Paper | Nội dung tạm được xử lý đúng cam kết | Cần background/device |
| E07 | Vò/thả bằng nút thay gesture | Hoàn thành được, screen reader có tên nút | Có code/test nền |
| E08 | Thực hành không có check-in trước đó | Không bịa cảm xúc trước; lưu phiên riêng hợp lý | F15/F16 |
| E09 | Thực hành xong → Xong, không after | Ghi session theo thiết kế, không ép after | Cần server |
| E10 | After: chọn 1–5, đổi và bỏ chọn | Không exception, null được xử lý đúng | Probe `.first` trên empty lỗi F05 |
| E11 | After không đổi/xấu hơn/không chắc | Lưu trung thực, lời phản hồi không phán xét | F04/F16 |
| E12 | Hai bài khác nhau trong ngày | Hai session và feedback riêng | Hiện ghi đè F15 |
| E13 | Bài tập từ phản tư entry cũ | Liên kết entry nguồn rõ, không sửa nhầm hôm nay | F15 |
| E14 | Viết nhiều bước rồi back/X | Giữ hoặc hỏi bỏ nháp; có quay bước phù hợp | F18 |
| E15 | Background rồi resume khi đang thở | Timer/phase rõ, không tự “hoàn thành” bất ngờ | Chưa chạy native |
| E16 | Session intro/complete với text 200% | Mọi nội dung/CTA cuộn được | Probe intro overflow F10 |

## F. Tiến trình và mục tiêu

| ID | Thao tác | Kỳ vọng | Ghi chú review |
|---|---|---|---|
| F01 | Chỉ có entry 40 ngày trước | Tuần hiện tại 0, không mượn cường độ/cảm xúc cũ | Probe sai F07 |
| F02 | So tuần lịch với 7/30 ngày | Nhãn và mẫu số giải thích khác biệt | Cần chốt UX |
| F03 | Cường độ cao ở vui và buồn | Không gán mặc định cao = xấu | Kiểm tra ngôn ngữ |
| F04 | Chart thiếu ngày, một entry, nhiều entry/ngày | Missing khác 0; tooltip và trung bình có nghĩa | Có test chart nền |
| F05 | Weekly review cuối tuần → tuần mới | Không báo tuần mới đã hoàn thành bằng bài cũ | F22 |
| F06 | Thêm micro-goal, theo dõi, đổi note, restart | Giữ đúng theo user, phạm vi sync rõ | Có local persistence |
| F07 | Khám phá/Thực hành → Hôm nay → Khám phá | Giữ section đang xem | Probe reset F12 |
| F08 | Lật postcard trong Reduce Motion | Nội dung vẫn đọc được, không flip gây khó chịu | F19 |

## G. Cộng đồng, nhóm, bạn bè và thông báo

| ID | Thao tác | Kỳ vọng | Ghi chú review |
|---|---|---|---|
| G01 | Tạo biệt danh, quay lại app | Hồ sơ cộng đồng tách email/nhật ký riêng | Cần API thật |
| G02 | Đăng public/group với mood/intent/ảnh | Đích rõ trước submit, đúng quyền nhìn thấy | Có test fake, cần upload thật |
| G03 | Mất mạng sau submit rồi retry | Một bài, giữ draft và requestId đúng | Có test fake |
| G04 | Thoát composer đang có nháp | Confirm; hủy confirm giữ nguyên | Đã có guard |
| G05 | Lọc mood, load more, refresh gặp lỗi | Không lẫn kết quả cũ/sai filter; retry đúng trang | Có test nền |
| G06 | Bootstrap/feed polling lỗi tạm | Giữ nội dung đang xem + banner | F26 |
| G07 | A lấy mã, B nhập dạng có/không dấu cách | Tìm đúng người, request/accept/reject rõ | Có test normalize nền |
| G08 | A tạo nhóm → mời B → B nhận → đăng | Trọn luồng hoạt động và notification đúng đích | Chưa E2E |
| G09 | Chủ nhóm quản lý thành viên, rời/xóa nhóm | Có quyền đúng, confirm phù hợp, không màn mắc kẹt | Cần backend thật |
| G10 | Chặn/hủy kết bạn trong lúc đang chat | Quyền được cập nhật, không gửi tiếp trái phép | Có test fake quyền |
| G11 | Chat: gửi, retry, ảnh, tải lịch sử | Không trùng, đúng thứ tự, giữ vị trí | Cần hai thiết bị |
| G12 | Chat polling timeout | Lịch sử đã tải không biến mất vì mạng tạm | F26 |
| G13 | Report bài/bình luận/tin nhắn, retry | Một report, đúng đối tượng, feedback rõ | Cần quyền moderator |
| G14 | Mở notifications, mark-read lỗi | Danh sách vẫn xem được, badge đồng nhất | F27 |
| G15 | Mở notification tới bài/nhóm đã xóa | Trang unavailable rõ và có đường quay lại | Chưa E2E |
| G16 | Logout khi response community chưa về | Response cũ không hiện cho tài khoản sau | Có regression nền |

## H. Cài đặt, dữ liệu và accessibility toàn app

| ID | Thao tác | Kỳ vọng | Ghi chú review |
|---|---|---|---|
| H01 | Sửa tên, failure, restart | Loading/lỗi rõ, tên giữ đúng, scope auth/community rõ | Cần API |
| H02 | Bật/tắt AI, goals, low stimulation, vườn, restart | Lưu đúng cài đặt đã công bố | Có test local preference |
| H03 | Bật reminder khi chưa có quyền, từ chối | Không giả báo bật, có hướng xử lý | Cần native |
| H04 | Bật reminder rồi đổi giờ khi schedule lỗi | UI rollback hoặc báo chưa lưu; giờ OS khớp UI | F24 |
| H05 | Reminder sau logout/đổi tài khoản/timezone | Hành vi đúng phạm vi setting đã chọn | Chưa native |
| H06 | Export đầy đủ rồi đọc JSON UTF-8 | Đủ trường, phạm vi/schema rõ, không clipboard nhạy cảm | F23 |
| H07 | Hủy share hoặc share platform lỗi | Không thông báo thành công giả, không uncaught exception | F23 |
| H08 | Xóa nhật ký/hoa lúc có pending write | Hoàn tất theo scope, không hồi sinh; reflection được xử lý | F08/F09 |
| H09 | Xóa nhật ký không xóa bài cộng đồng/message | Đúng nội dung confirm và phạm vi sản phẩm | Cần backend |
| H10 | Debug lock, resume, release build | Không nhầm demo với khóa thật; release không lộ setting demo | F31 |
| H11 | VoiceOver/TalkBack đi qua mọi CTA | Tên, role, selected/disabled, thứ tự focus hợp lý | Chưa chạy |
| H12 | Tăng text/display scale, mở keyboard | Không clip/ẩn CTA, không scaleDown chữ mất ý nghĩa | F10/F21 |
| H13 | Kiểm tra contrast chữ/controls/error | Dùng semantic token phù hợp bề mặt | F20 |
| H14 | Lịch sử 1.000+ entries, đổi tab/scroll/resume | Không jank đáng kể, tải hợp lý, không poll thừa | F29; cần profiler |
| H15 | Nguồn hỗ trợ trong setting/safety/community | Nội dung nhất quán, được xác minh định kỳ, thao tác rõ | Chưa xác minh thông tin dịch vụ |

## Cách ghi kết quả

```text
Case:
Commit app/backend:
Thiết bị/OS/text scale/timezone:
Tài khoản test và dữ liệu tiền điều kiện:
Mạng/quyền/cấu hình provider:
Các bước đã làm:
Kết quả UI:
Kết quả API/DB:
Sau force-close/restart:
Pass / Fail / Blocked:
Ảnh hoặc log:
Finding liên quan:
```

Chỉ đóng một finding khi đã kiểm tra cả UI, dữ liệu và trạng thái sau mở lại app nếu hành vi đó có lưu trữ. Test với fake chứng minh một phần hợp đồng; không thay thế kiểm tra hệ điều hành và backend thật.
