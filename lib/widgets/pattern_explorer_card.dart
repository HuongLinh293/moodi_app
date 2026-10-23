import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/shadows.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../models/journal_entry.dart';
import '../state/mindra_state.dart';
import 'mood_face.dart';

enum PatternTimeRange {
  sevenDays('7 ngày'),
  thirtyDays('30 ngày'),
  all('Tất cả');

  final String label;
  const PatternTimeRange(this.label);
}

enum PatternDimension {
  triggers('Tác nhân', Icons.bubble_chart_outlined),
  timeOfDay('Khung giờ', Icons.schedule_rounded),
  practices('Bài tập & Bước nhỏ', Icons.spa_outlined);

  final String label;
  final IconData icon;
  const PatternDimension(this.label, this.icon);
}

class PatternExplorerCard extends StatefulWidget {
  final MindraState state;

  const PatternExplorerCard({super.key, required this.state});

  @override
  State<PatternExplorerCard> createState() => _PatternExplorerCardState();
}

class _PatternExplorerCardState extends State<PatternExplorerCard> {
  PatternTimeRange _selectedRange = PatternTimeRange.thirtyDays;
  PatternDimension _selectedDimension = PatternDimension.triggers;

  List<JournalEntry> _getFilteredEntries() {
    final allEntries = widget.state.entries;
    if (_selectedRange == PatternTimeRange.all) return allEntries;

    final now = DateTime.now();
    final cutoffDays = _selectedRange == PatternTimeRange.sevenDays ? 7 : 30;
    final cutoff = now.subtract(Duration(days: cutoffDays));

    return allEntries.where((e) => e.timestamp.isAfter(cutoff)).toList();
  }

  String _formatTriggerVi(String trigger) {
    switch (trigger) {
      case 'work':
        return 'Công việc';
      case 'self_care':
        return 'Chăm sóc bản thân';
      case 'social':
        return 'Mối quan hệ';
      case 'uncertainty':
        return 'Những điều chưa rõ';
      case 'family':
        return 'Gia đình';
      case 'health':
        return 'Sức khỏe';
      default:
        return 'Khác / Hằng ngày';
    }
  }

  IconData _triggerIcon(String trigger) {
    switch (trigger) {
      case 'work':
        return Icons.work_outline_rounded;
      case 'family':
        return Icons.people_outline_rounded;
      case 'social':
        return Icons.forum_outlined;
      case 'health':
        return Icons.favorite_border_rounded;
      case 'self_care':
        return Icons.spa_outlined;
      case 'uncertainty':
        return Icons.help_outline_rounded;
      default:
        return Icons.tag_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredEntries();
    final sampleSize = filtered.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.purple.withValues(alpha: 0.16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.insights_rounded,
                    size: 20,
                    color: AppColors.purple,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'NHỊP LẶP LẠI',
                          style: AppTypography.kicker.copyWith(
                            color: AppColors.purple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.ink.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$sampleSize ghi nhận',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Điều hay lặp lại',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            'Quan sát các mối tương quan lặp lại mà không vội vàng phán xét hay suy diễn nguyên nhân.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Time Range Filter Row
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  'Thời gian:',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ...PatternTimeRange.values.map((range) {
                final isSelected = _selectedRange == range;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(range.label),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        MindraMotion.of(widget.state.lowStimulationMode)
                            .selection();
                        setState(() => _selectedRange = range);
                      }
                    },
                    labelStyle: AppTypography.caption.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.ink,
                      fontSize: 11,
                    ),
                    showCheckmark: false,
                    selectedColor: AppColors.ink,
                    backgroundColor: AppColors.creamDark,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(48),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 0,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),

          // Dimension Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PatternDimension.values.map((dim) {
                final isSelected = _selectedDimension == dim;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      MindraMotion.of(widget.state.lowStimulationMode)
                          .selection();
                      setState(() => _selectedDimension = dim);
                    },
                    borderRadius: BorderRadius.circular(48),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.purple.withValues(alpha: 0.14)
                            : AppColors.creamDark,
                        borderRadius: BorderRadius.circular(48),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            dim.icon,
                            size: 15,
                            color: isSelected
                                ? AppColors.purple
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dim.label,
                            style: AppTypography.caption.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.purple
                                  : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Content based on dimension
          if (sampleSize < 2)
            _buildLowDataBanner(sampleSize)
          else ...[
            if (_selectedDimension == PatternDimension.triggers)
              _buildTriggersDimension(filtered),
            if (_selectedDimension == PatternDimension.timeOfDay)
              _buildTimeOfDayDimension(filtered),
            if (_selectedDimension == PatternDimension.practices)
              _buildPracticesDimension(filtered),
          ],

          const SizedBox(height: 16),
          // Cautious language footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.creamDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lưu ý: Mối tương quan không đồng nghĩa với quan hệ nhân quả. Dữ liệu giúp bạn tự quan sát nhẹ nhàng, không đưa ra kết luận chẩn đoán.',
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      height: 1.35,
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

  Widget _buildLowDataBanner(int sampleSize) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.creamDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.bubble_chart_outlined,
            size: 32,
            color: AppColors.gray,
          ),
          const SizedBox(height: 8),
          Text(
            'Chưa đủ dữ liệu ($sampleSize check-in)',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Moodi cần ít nhất 2 đến 3 check-in trong khoảng thời gian này để phản ánh các nhịp điệu tương đối tin cậy. Hãy ghi nhận tự nhiên khi bạn sẵn lòng.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriggersDimension(List<JournalEntry> entries) {
    // Group emotions by trigger
    final triggerMap = <String, Map<String, int>>{};
    for (final e in entries) {
      final t = e.trigger.isNotEmpty ? e.trigger : 'other';
      triggerMap.putIfAbsent(t, () => {});
      triggerMap[t]![e.emotionKey] = (triggerMap[t]![e.emotionKey] ?? 0) + 1;
    }

    final sortedTriggers = triggerMap.keys.toList()
      ..sort((a, b) {
        final sumA = triggerMap[a]!.values.fold(
          0,
          (prev, element) => prev + element,
        );
        final sumB = triggerMap[b]!.values.fold(
          0,
          (prev, element) => prev + element,
        );
        return sumB.compareTo(sumA);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mối liên hệ giữa hoàn cảnh và cảm xúc xuất hiện:',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        ...sortedTriggers.take(4).map((triggerKey) {
          final emotions = triggerMap[triggerKey]!;
          final totalForTrigger = emotions.values.fold(
            0,
            (prev, el) => prev + el,
          );
          final sortedEmotions = emotions.keys.toList()
            ..sort((a, b) => emotions[b]!.compareTo(emotions[a]!));

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.creamDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            _triggerIcon(triggerKey),
                            size: 16,
                            color: AppColors.ink,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _formatTriggerVi(triggerKey),
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$totalForTrigger lần',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: sortedEmotions.map((emoKey) {
                    final count = emotions[emoKey]!;
                    final emo = MindraEmotions.get(emoKey);
                    final emoTone =
                        AppColors.emotionTones[emoKey] ?? AppColors.mint;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: emoTone.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MoodFace(faceType: emoKey, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${emo.vi} ($count)',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTimeOfDayDimension(List<JournalEntry> entries) {
    // 4 periods: Morning (5-11), Afternoon (12-17), Evening (18-22), Night (23-4)
    final periods = {
      'Sáng (05:00 - 11:59)': <int>[],
      'Trưa / Chiều (12:00 - 17:59)': <int>[],
      'Tối (18:00 - 22:59)': <int>[],
      'Đêm muộn (23:00 - 04:59)': <int>[],
    };

    for (final e in entries) {
      final hour = e.timestamp.hour;
      if (hour >= 5 && hour < 12) {
        periods['Sáng (05:00 - 11:59)']!.add(e.intensity);
      } else if (hour >= 12 && hour < 18) {
        periods['Trưa / Chiều (12:00 - 17:59)']!.add(e.intensity);
      } else if (hour >= 18 && hour < 23) {
        periods['Tối (18:00 - 22:59)']!.add(e.intensity);
      } else {
        periods['Đêm muộn (23:00 - 04:59)']!.add(e.intensity);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cường độ cảm xúc trung bình theo khung giờ trong ngày:',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        ...periods.entries.map((item) {
          final count = item.value.length;
          final avg = count > 0
              ? (item.value.reduce((a, b) => a + b) / count)
              : 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.creamDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    item.key,
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: count > 0
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (avg / 5.0).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: AppColors.line,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              avg >= 3.5 ? AppColors.orange : AppColors.mint,
                            ),
                          ),
                        )
                      : Text(
                          'Chưa có dữ liệu',
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 60,
                  child: Text(
                    count > 0 ? '${avg.toStringAsFixed(1)}/5 ($count)' : '—',
                    textAlign: TextAlign.end,
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPracticesDimension(List<JournalEntry> entries) {
    final exercises = entries.where((e) => e.exerciseDone).toList();
    final withFeedback = exercises
        .where((e) => e.afterIntensity != null)
        .toList();

    int improvedCount = 0;
    for (final e in withFeedback) {
      if (e.afterIntensity! < e.intensity) {
        improvedCount++;
      }
    }

    final microGoals = widget.state.microGoals;
    final completedGoals = microGoals.where((g) => g.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Độ hữu ích của bài tập & micro-goals bạn đã thử:',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.creamDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bài tập thực hiện',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exercises.length}',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      withFeedback.isNotEmpty
                          ? '$improvedCount/${withFeedback.length} lần dịu lại'
                          : 'Chưa có đánh giá sau',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.mint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.creamDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Micro-goals (bước nhỏ)',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedGoals/${microGoals.length}',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      completedGoals > 0 ? 'Đã hoàn thành' : 'Đang thực hành',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
