import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/shadows.dart';
import '../core/theme/typography.dart';
import '../state/mindra_state.dart';

class SettingsView extends StatelessWidget {
  final MindraState state;

  const SettingsView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: MindraMotion.of(state.lowStimulationMode).scrollPhysics,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CÀI ĐẶT & BẢO MẬT', style: AppTypography.kicker),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: AppTypography.displayMedium.copyWith(fontSize: 34),
              children: [
                const TextSpan(text: 'Không gian riêng tư,\n'),
                TextSpan(
                  text: 'do bạn làm chủ.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mindra tôn trọng quyền riêng tư tuyệt đối. Dữ liệu của bạn luôn thuộc về bạn.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          // 0. Tài khoản người dùng (S01.5 / S19)
          _buildAccountSection(context),
          const SizedBox(height: 18),

          // 1. Nhắc nhở nhẹ nhàng (S19)
          _buildRemindersSection(context),
          const SizedBox(height: 18),

          // 2. Mục tiêu cá nhân (S02 / S19)
          _buildGoalsSection(context),
          const SizedBox(height: 18),

          // 3. Quyền riêng tư & AI minh bạch (S20)
          _buildPrivacyAndAiSection(context),
          const SizedBox(height: 18),

          // 4. Quản lý dữ liệu (S20)
          _buildDataManagementSection(context),
          const SizedBox(height: 18),

          // 5. Nguồn lực hỗ trợ an toàn (S21)
          _buildSafetyAndCrisisSection(context),
          const SizedBox(height: 24),

          // 6. Thông tin ứng dụng (About)
          _buildAboutSection(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'Mindra v1.0.0 (MVP+)',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hiểu cảm xúc. Chủ động chọn cách phản hồi.',
            style: AppTypography.caption.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // 0. Tài khoản người dùng
  Widget _buildAccountSection(BuildContext context) {
    return _buildSectionCard(
      title: 'TÀI KHOẢN & BẢO VỆ',
      icon: Icons.account_circle_outlined,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.ink,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.userEmail,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.mint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Đã đồng bộ & mã hóa an toàn',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              foregroundColor: AppColors.ink,
            ),
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(
              'Đăng xuất tài khoản',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    MindraMotion.of(state.lowStimulationMode).light();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Đăng xuất khỏi Mindra?',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Bạn sẽ cần đăng nhập lại để truy cập không gian cá nhân và các tính năng đồng bộ.',
          style: AppTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Ở lại',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx); // Đóng dialog xác nhận
              Navigator.of(context).pop(); // Đóng màn hình Cài đặt
              unawaited(state.logout());
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  // 1. Nhắc nhở nhẹ nhàng
  Widget _buildRemindersSection(BuildContext context) {
    return _buildSectionCard(
      title: 'NHẮC NHỞ NHẸ NHÀNG',
      icon: Icons.notifications_active_outlined,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeTrackColor: AppColors.ink,
          title: Text(
            'Nhắc nhở dừng lại mỗi ngày',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Thông báo bình tĩnh, không hối thúc hay phán xét',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          value: state.reminderEnabled,
          onChanged: (val) {
            MindraMotion.of(state.lowStimulationMode).selection();
            state.setReminderEnabled(val);
          },
        ),
        if (state.reminderEnabled) ...[
          const Divider(height: 20),
          Text(
            'Khung giờ thuận tiện cho bạn:',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTimeChip('08:00', 'Buổi sáng'),
              _buildTimeChip('14:00', 'Buổi chiều'),
              _buildTimeChip('21:00', 'Buổi tối'),
              ActionChip(
                avatar: const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppColors.ink,
                ),
                label: Text(
                  state.reminderTime,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                backgroundColor: AppColors.creamDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onPressed: () async {
                  MindraMotion.of(state.lowStimulationMode).selection();
                  final parts = state.reminderTime.split(':');
                  final initialHour = int.tryParse(parts[0]) ?? 21;
                  final initialMinute = parts.length > 1
                      ? (int.tryParse(parts[1]) ?? 0)
                      : 0;
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: initialHour,
                      minute: initialMinute,
                    ),
                  );
                  if (picked != null) {
                    final h = picked.hour.toString().padLeft(2, '0');
                    final m = picked.minute.toString().padLeft(2, '0');
                    state.setReminderTime('$h:$m');
                  }
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTimeChip(String time, String label) {
    final isSelected = state.reminderTime == time;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label lúc $time',
      child: ChoiceChip(
        label: Text('$label ($time)'),
        selected: isSelected,
        selectedColor: AppColors.ink,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isSelected ? AppColors.ink : AppColors.line),
        ),
        labelStyle: AppTypography.caption.copyWith(
          color: isSelected ? Colors.white : AppColors.ink,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
        onSelected: (val) {
          if (val) {
            MindraMotion.of(state.lowStimulationMode).selection();
            state.setReminderTime(time);
          }
        },
      ),
    );
  }

  // 2. Mục tiêu cá nhân (S02 / S19)
  Widget _buildGoalsSection(BuildContext context) {
    const allGoals = [
      'Hiểu cảm xúc của tôi',
      'Giảm căng thẳng hằng ngày',
      'Phản hồi bình tĩnh hơn',
      'Xây dựng sự kiên cường',
    ];

    return _buildSectionCard(
      title: 'MỤC TIÊU ĐỒNG HÀNH',
      icon: Icons.track_changes_rounded,
      children: [
        Text(
          'Chọn các điều bạn muốn hướng tới cùng Mindra:',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allGoals.map((goal) {
            final isSelected = state.userGoals.contains(goal);
            return FilterChip(
              label: Text(goal),
              selected: isSelected,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              selectedColor: AppColors.orange.withValues(alpha: 0.15),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? AppColors.orange : AppColors.line,
                  width: isSelected ? 1.4 : 1.0,
                ),
              ),
              labelStyle: AppTypography.bodySmall.copyWith(
                color: isSelected ? AppColors.ink : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              onSelected: (_) {
                MindraMotion.of(state.lowStimulationMode).selection();
                state.toggleGoal(goal);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // 3. Quyền riêng tư & AI minh bạch (S20)
  Widget _buildPrivacyAndAiSection(BuildContext context) {
    return _buildSectionCard(
      title: 'QUYỀN RIÊNG TƯ & TRẢI NGHIỆM',
      icon: Icons.shield_outlined,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeTrackColor: AppColors.mint,
          title: Text(
            'Đồng ý dùng AI phản tư',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Cho phép AI hỗ trợ tạo góc nhìn cân bằng. Chỉ xử lý văn bản check-in tối thiểu, không gửi dữ liệu định danh.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
          value: state.aiConsent,
          onChanged: (val) {
            MindraMotion.of(state.lowStimulationMode).selection();
            state.setAiConsent(val);
          },
        ),
        const Divider(height: 20),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeTrackColor: AppColors.ink,
          title: Text(
            'Khóa ứng dụng (bản thử nghiệm)',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Hiện màn khóa PIN demo 0000 khi mở app. Chưa dùng Face ID thật.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          value: state.appLockEnabled,
          onChanged: (val) {
            MindraMotion.of(state.lowStimulationMode).selection();
            state.setAppLockEnabled(val);
          },
        ),
        const Divider(height: 20),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeTrackColor: AppColors.ink,
          title: Text(
            'Chế độ giảm kích thích',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Giảm hoạt ảnh và giữ giao diện tối giản cho những lúc mệt mỏi',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          value: state.lowStimulationMode,
          onChanged: (val) {
            MindraMotion.of(state.lowStimulationMode).selection();
            state.setLowStimulationMode(val);
          },
        ),
        const Divider(height: 20),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeTrackColor: AppColors.ink,
          title: Text(
            'Hiển thị Khu vườn Mindra',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Lớp hình ảnh riêng tư origami phát triển theo nhịp ghé thăm',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          value: state.gardenVisible,
          onChanged: (val) {
            MindraMotion.of(state.lowStimulationMode).selection();
            state.setGardenVisible(val);
          },
        ),
      ],
    );
  }

  // 4. Quản lý dữ liệu (S20)
  Widget _buildDataManagementSection(BuildContext context) {
    return _buildSectionCard(
      title: 'DỮ LIỆU CỦA BẠN',
      icon: Icons.folder_open_rounded,
      children: [
        Text(
          'Dữ liệu check-in được lưu trữ an toàn trên thiết bị của bạn.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44, // Touch target >= 44pt
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.ink),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _exportData(context),
                  icon: const Icon(
                    Icons.download_rounded,
                    size: 18,
                    color: AppColors.ink,
                  ),
                  label: Text(
                    'Xuất dữ liệu',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _confirmDeleteAll(context),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.red.shade600,
                  ),
                  label: Text(
                    'Xóa tất cả',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 5. Nguồn lực hỗ trợ an toàn (S21)
  Widget _buildSafetyAndCrisisSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 20,
                color: AppColors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                'HỖ TRỢ AN TOÀN & KHỦNG HOẢNG',
                style: AppTypography.kicker.copyWith(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Mindra là công cụ tự phản tư nhẹ nhàng, không thay thế chăm sóc y tế hay cấp cứu tâm lý. Nếu bạn đang cảm thấy quá tải hoặc có ý nghĩ làm hại bản thân, xin hãy kết nối ngay với nguồn lực hỗ trợ:',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.ink,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _buildHotlineRow(
            context: context,
            name: 'Tổng đài Quốc gia 111',
            number: '111',
            desc: 'Hỗ trợ bảo vệ và tâm lý miễn phí 24/7',
          ),
          const Divider(height: 18),
          _buildHotlineRow(
            context: context,
            name: 'Đường dây nóng Ngày Mai',
            number: '0963061414',
            desc: 'Hỗ trợ người khủng hoảng tâm lý & trầm cảm (13:00 - 20:30)',
          ),
          const Divider(height: 18),
          _buildHotlineRow(
            context: context,
            name: 'Cấp cứu Y tế Khẩn cấp',
            number: '115',
            desc: 'Dịch vụ cấp cứu y tế toàn quốc 24/7',
          ),
        ],
      ),
    );
  }

  Widget _buildHotlineRow({
    required BuildContext context,
    required String name,
    required String number,
    required String desc,
  }) {
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.ink),
              const SizedBox(width: 8),
              Text(title, style: AppTypography.kicker),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // Xuất dữ liệu
  void _exportData(BuildContext context) {
    MindraMotion.of(state.lowStimulationMode).selection();
    final dataList = state.entries
        .map(
          (e) => {
            'id': e.id,
            'timestamp': e.timestamp.toIso8601String(),
            'emotionKey': e.emotionKey,
            'intensity': e.intensity,
            'trigger': e.trigger,
            'situation': e.situation,
            'thought': e.thought,
            'response': e.response,
            'exerciseDone': e.exerciseDone,
            'afterIntensity': e.afterIntensity,
          },
        )
        .toList();

    final jsonStr = const JsonEncoder.withIndent('  ').convert(dataList);
    Clipboard.setData(ClipboardData(text: jsonStr));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Xuất dữ liệu thành công',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Đây là bản thử nghiệm. ${dataList.length} lượt check-in đã được sao chép dưới dạng JSON. Chia sẻ file thật sẽ được thêm sau.',
          style: AppTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: AppColors.ink)),
          ),
        ],
      ),
    );
  }

  // Xóa toàn bộ dữ liệu
  void _confirmDeleteAll(BuildContext context) {
    MindraMotion.of(state.lowStimulationMode).medium();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Xóa toàn bộ dữ liệu?',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.red.shade700,
          ),
        ),
        content: Text(
          'Hành động này sẽ xóa vĩnh viễn tất cả các bản ghi cảm xúc và đánh giá tuần trên thiết bị. Không thể hoàn tác.',
          style: AppTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              state.clearAllData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Đã xóa toàn bộ dữ liệu trên thiết bị'),
                  backgroundColor: AppColors.ink,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
  }

}
