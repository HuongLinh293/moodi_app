import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/shadows.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../state/mindra_state.dart';
import '../widgets/mood_face.dart';
import '../widgets/pattern_explorer_card.dart';
import '../widgets/weekly_postcard_sheet.dart';

class ProgressView extends StatelessWidget {
  final MindraState state;
  final VoidCallback onOpenCheckin;

  const ProgressView({
    super.key,
    required this.state,
    required this.onOpenCheckin,
  });

  String _formatTrigger(String trigger) {
    switch (trigger) {
      case 'work':
        return 'công việc';
      case 'self_care':
        return 'chăm sóc bản thân';
      case 'social':
      case 'friends':
        return 'mối quan hệ';
      case 'relationship':
        return 'tình cảm';
      case 'uncertainty':
        return 'những điều chưa rõ';
      case 'family':
        return 'gia đình';
      case 'health':
        return 'sức khỏe';
      case 'rest':
        return 'nghỉ ngơi';
      case 'finance':
        return 'tài chính';
      case 'study':
        return 'học tập';
      default:
        return 'hoàn cảnh thường nhật';
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = state.entries;
    final breakdown = state.emotionBreakdown;
    final dominantKey = state.dominantEmotionThisWeek;
    final dominantEmo = dominantKey != null
        ? MindraEmotions.get(dominantKey)
        : null;
    final dominantTrigger = state.dominantTriggerThisWeek;
    final latestExercise = state.latestExerciseWithFeedback;

    return SingleChildScrollView(
      physics: MindraMotion.of(state.lowStimulationMode).scrollPhysics,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề & Lời nhắn
          Text('TIẾN TRÌNH CỦA BẠN', style: AppTypography.kicker),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: AppTypography.displayMedium.copyWith(fontSize: 34),
              children: [
                const TextSpan(text: 'Nhìn lại để\n'),
                TextSpan(
                  text: 'hiểu mình hơn.',
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
            'Nhịp điệu tự nhiên trong tuần, ghi nhận nhẹ nhàng và không áp lực.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),

          if (entries.isEmpty)
            _buildEmptyState(context)
          else ...[
            // Metrics Grid (S17: 4 chỉ số cốt lõi tuần này)
            _buildWeeklyMetricsGrid(dominantEmo),
            const SizedBox(height: 16),

            // Pattern & Nhận diện thấu cảm (S17)
            _buildPatternCard(dominantEmo, dominantTrigger),
            const SizedBox(height: 16),

            // So sánh trước / sau bài tập (S17 - khi có dữ liệu)
            if (latestExercise != null) ...[
              _buildExerciseOutcomeCard(latestExercise),
              const SizedBox(height: 16),
            ],

            // Nhìn lại tuần (S17-W - Weekly Review)
            _buildWeeklyReviewCard(context),
            const SizedBox(height: 8),

            // Deeper analysis stays one tap away so the tab reads as a
            // short weekly summary first.
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey('progress-details'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                iconColor: AppColors.ink,
                collapsedIconColor: AppColors.ink,
                title: Text(
                  'Xem phân tích chi tiết',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Nhịp lặp lại, phân bố cảm xúc, huy hiệu',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                children: [
                  PatternExplorerCard(state: state),
                  const SizedBox(height: 16),
                  _buildEmotionBreakdownCard(breakdown),
                  const SizedBox(height: 16),
                  _buildBadgesSection(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // Weekly Review Card (S17-W)
  // ────────────────────────────────────────────
  Widget _buildWeeklyReviewCard(BuildContext context) {
    final review = state.weeklyReview;
    final hasReview = review != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue.withValues(alpha: 0.14),
                ),
                child: const Center(
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: 18,
                    color: AppColors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NHÌN LẠI TUẦN', style: AppTypography.kicker),
                    const SizedBox(height: 2),
                    Text(
                      hasReview
                          ? 'Bạn đã nhìn lại tuần này rồi'
                          : 'Dành 2 phút cho bản thân',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasReview) ...[
            const SizedBox(height: 16),
            _buildReviewSummaryItem(
              label: 'Xuất hiện nhiều nhất',
              value: review['mostFrequent'] ?? '',
            ),
            const SizedBox(height: 8),
            _buildReviewSummaryItem(
              label: 'Điều đã giúp bạn',
              value: review['helped'] ?? '',
            ),
            const SizedBox(height: 8),
            _buildReviewSummaryItem(
              label: 'Tuần tới muốn thử',
              value: review['nextWeek'] ?? '',
            ),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: BorderSide(
                        color: AppColors.ink.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      MindraMotion.of(state.lowStimulationMode).light();
                      _openWeeklyReviewSheet(context);
                    },
                    child: Text(
                      hasReview ? 'Xem lại & sửa' : 'Bắt đầu nhìn lại',
                      style: AppTypography.button.copyWith(fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      WeeklyPostcardSheet.show(context, state);
                    },
                    icon: const Text('💌', style: TextStyle(fontSize: 14)),
                    label: Text(
                      'Bưu thiếp tuần',
                      style: AppTypography.button.copyWith(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSummaryItem({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.creamDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.isEmpty ? '—' : value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _openWeeklyReviewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WeeklyReviewSheet(
        initialReview: state.weeklyReview,
        reducedMotion: state.lowStimulationMode,
        onSave: (mostFrequent, helped, nextWeek) {
          state.saveWeeklyReview(
            mostFrequent: mostFrequent,
            helped: helped,
            nextWeek: nextWeek,
          );
        },
      ),
    );
  }

  // Empty state khi người dùng chưa có entry nào
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.auto_graph_rounded,
                size: 28,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có dữ liệu tiến trình',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ghi lại cảm xúc hôm nay để mở khóa góc nhìn tuần và các mốc nhận biết.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 44, // Touch target >= 44pt
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onPressed: () {
                MindraMotion.of(state.lowStimulationMode).light();
                onOpenCheckin();
              },
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: Text(
                'Bắt đầu check-in',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4 thẻ chỉ số tuần theo S17
  Widget _buildWeeklyMetricsGrid(EmotionInfo? dominantEmo) {
    final daysThisWeek = state.checkinDaysThisWeek;
    final avgIntensity = state.averageIntensityThisWeek;
    final exercisesDone = state.exercisesCompleted;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                value: '$daysThisWeek/7',
                unit: 'ngày',
                label: 'CÓ MẶT TUẦN NÀY',
                semanticsLabel:
                    'Đã check-in $daysThisWeek trên 7 ngày tuần này',
                icon: Icons.calendar_today_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                value: dominantEmo != null ? dominantEmo.vi : '--',
                unit: '',
                label: 'CẢM XÚC NỔI BẬT',
                semanticsLabel: dominantEmo != null
                    ? 'Cảm xúc nổi bật tuần này: ${dominantEmo.vi}'
                    : 'Chưa đủ dữ liệu cảm xúc nổi bật',
                leadingFace: dominantEmo?.face,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                value: avgIntensity > 0
                    ? avgIntensity.toStringAsFixed(1)
                    : '--',
                unit: avgIntensity > 0 ? '/5' : '',
                label: 'CƯỜNG ĐỘ TUẦN',
                semanticsLabel: avgIntensity > 0
                    ? 'Cường độ trung bình: ${avgIntensity.toStringAsFixed(1)} trên 5'
                    : 'Chưa có cường độ trung bình',
                icon: Icons.speed_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                value: '$exercisesDone',
                unit: 'bài',
                label: 'BÀI THỰC HÀNH',
                semanticsLabel: 'Đã hoàn thành $exercisesDone bài thực hành',
                icon: Icons.self_improvement_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String value,
    required String unit,
    required String label,
    required String semanticsLabel,
    IconData? icon,
    String? leadingFace,
  }) {
    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leadingFace != null) ...[
                  MoodFace(faceType: leadingFace, size: 24),
                  const SizedBox(width: 6),
                ] else if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.ink),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      text: value,
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: 22,
                        letterSpacing: -0.5,
                        color: AppColors.ink,
                      ),
                      children: [
                        if (unit.isNotEmpty)
                          TextSpan(
                            text: ' $unit',
                            style: AppTypography.caption.copyWith(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.kicker.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Card Pattern nhận thấy (S17 - Ngôn ngữ thận trọng, phi lâm sàng)
  Widget _buildPatternCard(EmotionInfo? dominantEmo, String? dominantTrigger) {
    final patternText = dominantEmo != null && dominantTrigger != null
        ? 'Cảm xúc ${dominantEmo.vi.toLowerCase()} gắn với ${_formatTrigger(dominantTrigger)} xuất hiện nhiều hơn trong những ngày qua. Bạn có thể muốn quan sát thêm khi có dịp.'
        : dominantEmo != null
        ? 'Cảm xúc ${dominantEmo.vi.toLowerCase()} là gam màu chủ đạo gần đây. Dành chút thời gian lắng nghe xem cơ thể đang cần gì.'
        : 'Mỗi lần bạn ghi lại là một lần tâm trí có không gian để dịu lại.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.mint.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_twilight_rounded,
                size: 18,
                color: Color(0xFF245448),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'ĐIỀU MÌNH NHẬN THẤY',
                  style: AppTypography.kicker.copyWith(
                    color: const Color(0xFF245448),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            patternText,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.ink,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // Card so sánh trước/sau bài tập (S17)
  Widget _buildExerciseOutcomeCard(dynamic latestExercise) {
    final beforeIntensity = latestExercise.intensity as int;
    final afterIntensity = latestExercise.afterIntensity as int?;
    final afterEmoKey = latestExercise.afterEmotionKey as String?;
    final usefulnessRating = latestExercise.usefulnessRating as int?;
    final easeRating = latestExercise.easeRating as int?;
    final repeatPreference = latestExercise.repeatPreference as String?;
    final afterEmo = afterEmoKey != null
        ? MindraEmotions.get(afterEmoKey)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CHUYỂN BIẾN SAU THỰC HÀNH',
                  style: AppTypography.kicker.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.creamDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Trước: mức $beforeIntensity/5',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.mint.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  afterIntensity != null
                      ? 'Sau: mức $afterIntensity/5'
                      : 'Đã dịu hơn',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (afterEmo != null) ...[
                const SizedBox(width: 8),
                MoodFace(faceType: afterEmo.face, size: 20),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Thực hành chánh niệm giúp cơ thể kích hoạt hệ phó giao cảm tự nhiên.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          if (usefulnessRating != null ||
              easeRating != null ||
              repeatPreference != null) ...[
            const SizedBox(height: 12),
            Text('PHẢN HỒI CỦA BẠN', style: AppTypography.kicker),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (usefulnessRating != null)
                  _buildFeedbackBadge('Hữu ích $usefulnessRating/5'),
                if (easeRating != null)
                  _buildFeedbackBadge('Dễ thực hiện $easeRating/5'),
                if (repeatPreference != null)
                  _buildFeedbackBadge(switch (repeatPreference) {
                    'yes' => 'Muốn dùng lại',
                    'no' => 'Không muốn dùng lại',
                    _ => 'Chưa chắc có dùng lại',
                  }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedbackBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Phân bố cảm xúc thực tế (S17 - Dynamic Emotion Breakdown)
  Widget _buildEmotionBreakdownCard(Map<String, double> breakdown) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('PHÂN BỐ CẢM XÚC', style: AppTypography.kicker),
              Text(
                '${state.entries.length} ghi nhận',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (breakdown.isEmpty)
            Text(
              'Chưa có dữ liệu cảm xúc để thống kê.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            )
          else
            ...breakdown.entries.map((entry) {
              final emo = MindraEmotions.get(entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildEmotionBar(emo.face, emo.vi, entry.value),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmotionBar(String faceType, String label, double fraction) {
    final percentage = (fraction * 100).round();
    final palette = AppColors.facePalette[faceType];
    final barColor = palette != null && palette.isNotEmpty
        ? palette[0]
        : AppColors.mint;

    return Semantics(
      label: '$label: $percentage phần trăm',
      child: Row(
        children: [
          MoodFace(faceType: faceType, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: AppTypography.button.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: AppTypography.kicker.copyWith(
                        fontSize: 11,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    height: 6,
                    color: AppColors.line,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fraction.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Huy hiệu nhận biết (S18 - Dynamic Badges)
  Widget _buildBadgesSection(BuildContext context) {
    final hasFirstCheckin = state.entries.isNotEmpty;
    final hasThreeDays = state.uniqueCheckinDays >= 3;
    final hasOneWeek = state.uniqueCheckinDays >= 7;
    final hasTriedExercise = state.exercisesCompleted >= 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('HUY HIỆU NHẬN BIẾT', style: AppTypography.kicker),
              Text(
                'Phi cạnh tranh',
                style: AppTypography.caption.copyWith(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 8,
            runSpacing: 16,
            children: [
              _buildBadge(
                context: context,
                icon: '🌿',
                label: 'Phản tư\nđầu tiên',
                earned: hasFirstCheckin,
                desc: 'Hoàn thành check-in cảm xúc đầu tiên',
              ),
              _buildBadge(
                context: context,
                icon: '🌱',
                label: 'Ba ngày\nhiện diện',
                earned: hasThreeDays,
                desc:
                    'Có mặt check-in trong 3 ngày (${state.uniqueCheckinDays}/3 ngày)',
              ),
              _buildBadge(
                context: context,
                icon: '☀️',
                label: 'Một tuần\nnhận biết',
                earned: hasOneWeek,
                desc:
                    'Ghi nhận và đồng hành trong 7 ngày (${state.uniqueCheckinDays}/7 ngày)',
              ),
              _buildBadge(
                context: context,
                icon: '🧭',
                label: 'Thử công\ncụ mới',
                earned: hasTriedExercise,
                desc:
                    'Hoàn thành bài tập thực hành đầu tiên (${state.exercisesCompleted}/1 bài)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required BuildContext context,
    required String icon,
    required String label,
    required bool earned,
    required String desc,
  }) {
    final statusText = earned ? 'Đã mở khóa' : 'Chưa mở khóa';
    final tooltipText = '$label ($statusText): $desc';

    return Tooltip(
      message: tooltipText,
      preferBelow: false,
      child: Semantics(
        button: true,
        label: tooltipText,
        child: GestureDetector(
          onTap: () {
            MindraMotion.of(state.lowStimulationMode).selection();
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  earned ? '🎉 $label: $desc' : '🌱 $label: $desc',
                  style: AppTypography.bodySmall.copyWith(color: Colors.white),
                ),
                backgroundColor: AppColors.ink,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              AnimatedContainer(
                duration: MindraMotion.of(state.lowStimulationMode).duration,
                width: 52, // Touch target >= 44pt
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: earned ? Colors.white : AppColors.creamDark,
                  border: Border.all(
                    color: earned ? AppColors.ink : AppColors.lineLight,
                    width: earned ? 1.5 : 1.0,
                  ),
                  boxShadow: earned
                      ? [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: earned ? 1.0 : 0.35,
                  child: Text(icon, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.kicker.copyWith(
                  fontSize: 10,
                  color: earned ? AppColors.ink : AppColors.textTertiary,
                  fontWeight: earned ? FontWeight.w700 : FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// _WeeklyReviewSheet — 3-step modal (S17-W)
// ═══════════════════════════════════════════════════════════════════
class _WeeklyReviewSheet extends StatefulWidget {
  final Map<String, String>? initialReview;
  final bool reducedMotion;
  final void Function(String mostFrequent, String helped, String nextWeek)
  onSave;

  const _WeeklyReviewSheet({
    required this.initialReview,
    required this.onSave,
    this.reducedMotion = false,
  });

  @override
  State<_WeeklyReviewSheet> createState() => _WeeklyReviewSheetState();
}

class _WeeklyReviewSheetState extends State<_WeeklyReviewSheet> {
  int _step = 0;
  late final TextEditingController _c1;
  late final TextEditingController _c2;
  late final TextEditingController _c3;

  static const _prompts = [
    'Điều gì xuất hiện nhiều nhất trong bạn tuần qua?',
    'Điều gì đã giúp bạn, dù chỉ một chút?',
    'Tuần tới bạn muốn thử điều gì?',
  ];

  static const _hints = [
    'vd: lo lắng về công việc, cảm giác mệt mỏi…',
    'vd: đi bộ buổi sáng, tâm sự với bạn bè…',
    'vd: ngủ sớm hơn, thử bài hít thở…',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.initialReview;
    _c1 = TextEditingController(text: r?['mostFrequent'] ?? '');
    _c2 = TextEditingController(text: r?['helped'] ?? '');
    _c3 = TextEditingController(text: r?['nextWeek'] ?? '');
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  TextEditingController get _currentController => [_c1, _c2, _c3][_step];

  void _next() {
    MindraMotion(widget.reducedMotion).selection();
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _save();
    }
  }

  void _back() {
    MindraMotion(widget.reducedMotion).selection();
    if (_step > 0) setState(() => _step--);
  }

  void _save() {
    widget.onSave(_c1.text.trim(), _c2.text.trim(), _c3.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == 2;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.72,
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            16,
            22,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  if (_step > 0)
                    GestureDetector(
                      onTap: _back,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  Text(
                    'NHÌN LẠI TUẦN — ${_step + 1}/3',
                    style: AppTypography.kicker,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Step indicator
              Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: MindraMotion(widget.reducedMotion).duration,
                      height: 4,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i <= _step ? AppColors.ink : AppColors.lineLight,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),

              // Prompt
              Text(
                _prompts[_step],
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              // Text field
              Expanded(
                child: TextField(
                  controller: _currentController,
                  maxLines: null,
                  expands: true,
                  autofocus: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    hintText: _hints[_step],
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.ink.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                    filled: true,
                    fillColor: AppColors.cream,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _next,
                  child: Text(
                    isLast ? 'Lưu nhìn lại' : 'Tiếp theo',
                    style: AppTypography.button,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
