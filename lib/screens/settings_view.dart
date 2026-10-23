import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/shadows.dart';
import '../core/theme/typography.dart';
import '../state/mindra_state.dart';
import '../widgets/crisis_support.dart';

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
            'Quản lý trải nghiệm và dữ liệu được đồng bộ trên tài khoản của bạn.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          // 0. Tài khoản người dùng (S01.5 / S19)
          _buildAccountSection(context),
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
            'Moodi v1.0.0 (MVP+)',
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
    final syncOk =
        state.failedEntryCount == 0 &&
        state.pendingEntryCount == 0 &&
        state.sessionEntryCount == 0;
    final syncLabel = state.failedEntryCount > 0
        ? 'Có ghi chép chưa đồng bộ được'
        : state.pendingEntryCount > 0
        ? 'Đang đồng bộ…'
        : state.sessionEntryCount > 0
        ? 'Có ghi chép chưa được lưu lâu dài'
        : 'Đã đồng bộ với tài khoản';
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
                        decoration: BoxDecoration(
                          color: syncOk ? AppColors.mint : AppColors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          syncLabel,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
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
          state.isGuest ? 'Thoát chế độ khách?' : 'Đăng xuất khỏi Moodi?',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          state.isGuest
              ? 'Bạn đang dùng chế độ khách. Nếu đăng xuất, toàn bộ ghi chép và khu vườn sẽ mất vĩnh viễn, không thể khôi phục.'
              : 'Bạn sẽ cần đăng nhập lại để truy cập không gian cá nhân và các tính năng đồng bộ.',
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
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await state.logout();
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chưa đăng xuất được. Hãy thử lại.'),
                  ),
                );
              }
            },
            child: Text(state.isGuest ? 'Vẫn đăng xuất' : 'Đăng xuất'),
          ),
        ],
      ),
    );
  }

  // 1. Nhắc nhở nhẹ nhàng
  // 2. Mục tiêu cá nhân (S02 / S19)
  Widget _buildGoalsSection(BuildContext context) {
    const allGoals = [
      'Hiểu cảm xúc của tôi',
      'Giảm căng thẳng hằng ngày',
      'Phản hồi bình tĩnh hơn',
      'Xây dựng khả năng nhận biết cảm xúc',
    ];

    return _buildSectionCard(
      title: 'MỤC TIÊU ĐỒNG HÀNH',
      icon: Icons.track_changes_rounded,
      children: [
        Text(
          'Chọn các điều bạn muốn hướng tới cùng Moodi:',
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
            'Hiện gợi ý phản tư',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Gợi ý hiện dựa trên mẫu có sẵn trong ứng dụng. Bạn có thể chỉnh sửa hoặc bỏ qua nội dung chưa phù hợp.',
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
        // Demo PIN only; hidden from release builds until real Face ID/PIN.
        if (kDebugMode) ...[
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
        ],
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
            'Hiển thị Khu vườn Moodi',
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
          'Ghi chép được đồng bộ với tài khoản của bạn. Bạn có thể xuất bản sao bất cứ lúc nào.',
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
                    'Xóa nhật ký & hoa',
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
            'Moodi là công cụ tự phản tư nhẹ nhàng, không thay thế chăm sóc y tế hay cấp cứu tâm lý. Nếu bạn đang cảm thấy quá tải hoặc có ý nghĩ làm hại bản thân, xin hãy kết nối ngay với nguồn lực hỗ trợ:',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.ink,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          const CrisisHotlines(),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    // Background lives on Material so ListTile ink and tile colors stay visible.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
        ),
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
    final box = context.findRenderObject() as RenderBox?;
    final date = DateTime.now().toIso8601String().substring(0, 10);
    // Share sheet instead of clipboard: other apps can read the clipboard.
    SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(jsonStr)),
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: ['moodi-nhat-ky-$date.json'],
        subject: 'Nhật ký Moodi',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
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
          'Xóa nhật ký và hoa?',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.red.shade700,
          ),
        ),
        content: Text(
          'Hành động này sẽ xóa vĩnh viễn mọi ghi chép cảm xúc và hoa trong vườn của bạn khỏi tài khoản và thiết bị. Những bông hoa bạn đã gửi vào vườn sẻ chia hiện tại cũng được gỡ. Bài cộng đồng và tin nhắn không thuộc thao tác này. Không thể hoàn tác.',
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
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await state.deleteAllUserData();
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Chưa xóa được dữ liệu. Kiểm tra kết nối và thử lại.',
                    ),
                  ),
                );
                return;
              }
              messenger.showSnackBar(
                SnackBar(
                  content: const Text('Đã xóa nhật ký và hoa của bạn'),
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
