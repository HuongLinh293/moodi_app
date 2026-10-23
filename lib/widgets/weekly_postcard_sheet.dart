import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/colors.dart';
import '../core/theme/shadows.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../state/mindra_state.dart';
import 'mood_face.dart';

/// Modal sheet displaying an artistic 3D-flippable Weekly Emotion Postcard.
class WeeklyPostcardSheet extends StatefulWidget {
  final MindraState state;

  const WeeklyPostcardSheet({super.key, required this.state});

  static Future<void> show(BuildContext context, MindraState state) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WeeklyPostcardSheet(state: state),
    );
  }

  @override
  State<WeeklyPostcardSheet> createState() => _WeeklyPostcardSheetState();
}

class _WeeklyPostcardSheetState extends State<WeeklyPostcardSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _flipController.addListener(() {
      if (_flipAnimation.value >= 0.5 && !_showBack) {
        setState(() => _showBack = true);
      } else if (_flipAnimation.value < 0.5 && _showBack) {
        setState(() => _showBack = false);
      }
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    HapticFeedback.selectionClick();
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  String _getWeekTitle(EmotionInfo? dominant) {
    if (dominant == null) return 'Tuần của Những Khởi Đầu Mới';
    switch (dominant.key) {
      case 'calm':
        return 'Tuần của Sự An Nhiên & Tĩnh Lặng';
      case 'happy':
      case 'grateful':
        return 'Tuần của Lòng Biết Ơn & Nắng Ấm';
      case 'stressed':
      case 'angry':
        return 'Tuần của Bản Lĩnh & Sự Vượt Lên';
      case 'sad':
      case 'anxious':
        return 'Tuần của Lòng Trắc Ẩn & Khoảng Lặng';
      default:
        return 'Tuần của Sự Thấu Hiểu Nội Tâm';
    }
  }

  String _getWeekQuote(EmotionInfo? dominant, int daysCount) {
    if (dominant == null || daysCount == 0) {
      return 'Khu vườn tâm trí luôn rộng mở chào đón bạn quay về bất cứ khi nào bạn cần một khoảng dừng.';
    }
    switch (dominant.key) {
      case 'calm':
      case 'happy':
      case 'grateful':
        return 'Bạn đã gieo những hạt mầm bình an trong $daysCount ngày qua. Hãy mang theo hơi ấm này sang tuần mới nhé.';
      case 'stressed':
      case 'angry':
        return 'Áp lực và thử thách đã ghé thăm, nhưng bạn đã không bỏ rơi chính mình. Bạn mạnh mẽ và kiên cường hơn bạn nghĩ.';
      case 'sad':
      case 'anxious':
        return 'Có những ngày mây mù che lối, nhưng trái tim bạn vẫn nhịp nhàng. Cảm ơn bạn vì đã luôn kiên nhẫn với chính mình.';
      default:
        return 'Mỗi cảm xúc đều mang một thông điệp riêng. Cảm ơn bạn đã luôn có mặt và lắng nghe bản thân tuần qua.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dominantKey = widget.state.dominantEmotionThisWeek;
    final dominant = dominantKey != null
        ? MindraEmotions.all[dominantKey]
        : null;
    final daysCount = widget.state.checkinDaysThisWeek;
    final entriesCount = widget.state.thisWeekEntries.length;
    final review = widget.state.weeklyReview;
    final weekTitle = _getWeekTitle(dominant);
    final weekQuote = _getWeekQuote(dominant, daysCount);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Top action bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('💌', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        'BƯU THIẾP CẢM XÚC',
                        style: AppTypography.kicker.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: AppColors.textMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable postcard area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Text(
                      'Tấm thiệp đúc kết nhịp điệu cảm xúc tuần qua của bạn',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // 3D Flippable Postcard
                    AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, child) {
                        final angle = _flipAnimation.value * math.pi;
                        final transform = Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateY(angle);

                        return Transform(
                          transform: transform,
                          alignment: Alignment.center,
                          child: _showBack
                              ? Transform(
                                  transform: Matrix4.identity()
                                    ..rotateY(math.pi),
                                  alignment: Alignment.center,
                                  child: _buildBackCard(review),
                                )
                              : _buildFrontCard(
                                  dominant: dominant,
                                  weekTitle: weekTitle,
                                  weekQuote: weekQuote,
                                  daysCount: daysCount,
                                  entriesCount: entriesCount,
                                ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Actions row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              foregroundColor: AppColors.textPrimary,
                              side: BorderSide(
                                color: AppColors.ink.withValues(alpha: 0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _toggleFlip,
                            icon: const Icon(Icons.flip_rounded, size: 18),
                            label: Text(
                              _showBack ? 'Xem mặt trước' : 'Lật mặt sau',
                              style: AppTypography.button,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              backgroundColor: AppColors.ink,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Đã lưu bưu thiếp tuần vào bộ nhớ của bạn! 🌸',
                                  ),
                                  backgroundColor: AppColors.ink,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.bookmark_add_outlined,
                              size: 18,
                            ),
                            label: Text(
                              'Lưu bưu thiếp',
                              style: AppTypography.button.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Front Side of the Postcard
  Widget _buildFrontCard({
    required EmotionInfo? dominant,
    required String weekTitle,
    required String weekQuote,
    required int daysCount,
    required int entriesCount,
  }) {
    final themeColor = dominant?.tone ?? AppColors.mint;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7), // Warm authentic paper tone
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E2D5), width: 1.5),
        boxShadow: AppShadows.card,
      ),
      child: Stack(
        children: [
          // Background soft aura gradient
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    themeColor.withValues(alpha: 0.22),
                    themeColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header: Postmark & Postage Stamp
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MOODI POST',
                          style: AppTypography.kicker.copyWith(
                            letterSpacing: 2.0,
                            color: const Color(0xFF8C8270),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bản tổng kết nhịp điệu',
                          style: AppTypography.caption.copyWith(
                            color: const Color(0xFFA69D8D),
                          ),
                        ),
                      ],
                    ),
                    // Postage stamp
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFD4CBBB),
                          style: BorderStyle.solid,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MoodFace(
                            faceType: dominant?.face ?? 'calm',
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tuần này',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: const Color(0xFF7A6F5D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Centerpiece: Flower & Week Title
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themeColor.withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: MoodFace(
                            faceType: dominant?.face ?? 'calm',
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        weekTitle,
                        style: AppTypography.headlineMedium.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Emotional Aura Quote
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEDE7DC)),
                  ),
                  child: Text(
                    '“$weekQuote”',
                    style: AppTypography.bodySmall.copyWith(
                      color: const Color(0xFF4A4235),
                      fontStyle: FontStyle.italic,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 20),

                // 3 Mini stats in card
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStat(
                        icon: '📅',
                        value: '$daysCount/7',
                        label: 'Ngày có mặt',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: const Color(0xFFE8E2D5),
                    ),
                    Expanded(
                      child: _buildMiniStat(
                        icon: '🌸',
                        value: '$entriesCount',
                        label: 'Ghi chép',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: const Color(0xFFE8E2D5),
                    ),
                    Expanded(
                      child: _buildMiniStat(
                        icon: '🌿',
                        value: dominant?.vi ?? 'Bình an',
                        label: 'Chủ đạo',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Back Side of the Postcard
  Widget _buildBackCard(Map<String, String>? review) {
    final nextWeekAspiration = review?['nextWeek']?.isNotEmpty == true
        ? review!['nextWeek']!
        : 'Nuôi dưỡng sự kiên nhẫn và dành thêm 5 phút mỗi tối để tĩnh tâm.';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EE), // Vintage paper tone
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0D8C8), width: 1.5),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Postcard vintage divider line
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left half: Note to future self
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LỜI NHẮN TUẦN MỚI ✍️',
                      style: AppTypography.kicker.copyWith(
                        fontSize: 10,
                        color: const Color(0xFF7A6F5D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5DDD0)),
                      ),
                      child: Text(
                        nextWeekAspiration,
                        style: AppTypography.bodySmall.copyWith(
                          color: const Color(0xFF4A4235),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'ĐIỀU ĐÁNG TỰ HÀO 🌟',
                      style: AppTypography.kicker.copyWith(
                        fontSize: 10,
                        color: const Color(0xFF7A6F5D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bạn đã dũng cảm đón nhận mọi cảm xúc mà không vội vàng xua đuổi chúng.',
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFF6B6150),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Vertical dashed divider
              Container(width: 1, height: 180, color: const Color(0xFFD8CFBF)),

              const SizedBox(width: 16),

              // Right half: Postmark & Recipient Address
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Postmark circular stamp
                    Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFB3A895),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'MOODI\n★ ĐÃ GỬI ★',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF8C806D),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Destination lines
                    _buildAddressLine('Gửi: Bạn của ngày mai'),
                    _buildAddressLine('Nơi đến: Khu vườn bình an'),
                    _buildAddressLine('Ghi chú: Luôn có thể bắt đầu lại'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Center(
            child: Text(
              'Mỗi tuần là một chu kỳ lớn lên của khu vườn tâm hồn bạn 🌿',
              style: AppTypography.caption.copyWith(
                color: const Color(0xFF9E9382),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required String icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.ink,
          ),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            color: const Color(0xFF8C8270),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: AppTypography.caption.copyWith(
              fontSize: 9,
              color: const Color(0xFF6B6150),
            ),
          ),
          const SizedBox(height: 2),
          Container(height: 1, color: const Color(0xFFD8CFBF)),
        ],
      ),
    );
  }
}
