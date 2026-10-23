# Hồ sơ BTL bảo mật Moodi

Đề tài: **Nghiên cứu tấn công vượt quyền truy cập và biện pháp phòng chống trên ứng dụng nhật ký cảm xúc Moodi.**

1. [Kế hoạch và checklist tiến độ](../../plan.md)
2. [Kiến trúc và luồng dữ liệu](architecture.md)
3. [Bảng phân quyền](access-control-matrix.md)
4. [Mô hình đe dọa và giới hạn](threat-model.md)
5. [Kết quả thực nghiệm](test-results.md)
6. [Hướng dẫn demo 5–7 phút](demo-guide.md)
7. [Môi trường thực nghiệm và lệnh chạy](../../security-lab/README.md)
8. [Đánh giá tĩnh rules](rules-audit.json)
9. [Bằng chứng kiểm thử và hash source](evidence-summary.json)

Ba bản phải được gọi tên đúng trong báo cáo: **baseline thật**, **fixture cố ý có lỗ hổng**, **bản gia cố**. Không lấy lỗ hổng tạo ra trong fixture để khẳng định app gốc có cùng lỗ hổng.
