import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/colors.dart';
import '../core/theme/typography.dart';

const _hotlines = [
  (
    name: 'Tổng đài Quốc gia 111',
    number: '111',
    desc: 'Hỗ trợ bảo vệ và tâm lý miễn phí 24/7',
  ),
  (
    name: 'Đường dây nóng Ngày Mai',
    number: '0963061414',
    desc: 'Hỗ trợ người khủng hoảng tâm lý & trầm cảm (13:00 - 20:30)',
  ),
  (
    name: 'Cấp cứu Y tế Khẩn cấp',
    number: '115',
    desc: 'Dịch vụ cấp cứu y tế toàn quốc 24/7',
  ),
];

/// Danh sách đường dây nóng dùng chung (Cài đặt, Cộng đồng).
class CrisisHotlines extends StatelessWidget {
  const CrisisHotlines({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, h) in _hotlines.indexed) ...[
          if (i > 0) const Divider(height: 18),
          _HotlineRow(name: h.name, number: h.number, desc: h.desc),
        ],
      ],
    );
  }
}

class _HotlineRow extends StatelessWidget {
  const _HotlineRow({
    required this.name,
    required this.number,
    required this.desc,
  });
  final String name, number, desc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Text(
                desc,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44, // Touch target >= 44pt
          child: TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.line),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: number));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã sao chép số điện thoại $number'),
                  backgroundColor: AppColors.ink,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.copy_rounded,
              size: 16,
              color: AppColors.ink,
            ),
            label: Text(
              number,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hiện khi nội dung người dùng viết có tín hiệu khủng hoảng: thay vì chỉ báo
/// lỗi, nhẹ nhàng mời họ kết nối với nguồn hỗ trợ.
Future<void> showCrisisSupportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFFFF7ED),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_rounded,
              size: 28,
              color: AppColors.orange,
            ),
            const SizedBox(height: 10),
            Text(
              'Bạn không phải một mình',
              style: AppTypography.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Có vẻ bạn đang trải qua một điều rất nặng nề. Bài viết chưa được đăng công khai để bảo vệ bạn, và bản nháp vẫn được giữ nguyên. Nếu bạn đang có ý nghĩ làm hại bản thân, hãy liên hệ ngay một trong các số dưới đây hoặc nói chuyện với người bạn tin tưởng.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.ink,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            const CrisisHotlines(),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mình hiểu rồi'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
