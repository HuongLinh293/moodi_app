import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/shadows.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../models/journal_entry.dart';
import 'mood_face.dart';

/// Xu hướng cảm xúc theo ngày: mỗi cột là cường độ trung bình của ngày,
/// tô màu theo cảm xúc xuất hiện nhiều nhất ngày đó.
class MoodTrendCard extends StatefulWidget {
  final List<JournalEntry> entries;
  final bool lowStimulation;

  const MoodTrendCard({
    super.key,
    required this.entries,
    this.lowStimulation = false,
  });

  @override
  State<MoodTrendCard> createState() => _MoodTrendCardState();
}

class _DayStat {
  final DateTime day;
  final double avgIntensity;
  final String? emotionKey;
  final int count;

  const _DayStat(this.day, this.avgIntensity, this.emotionKey, this.count);
}

class _MoodTrendCardState extends State<MoodTrendCard> {
  static const _maxIntensity = 5.0;
  static const _chartHeight = 120.0;
  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  int _days = 7;

  List<_DayStat> _buildStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final byDay = <DateTime, List<JournalEntry>>{};
    for (final e in widget.entries) {
      final t = e.timestamp.toLocal();
      byDay.putIfAbsent(DateTime(t.year, t.month, t.day), () => []).add(e);
    }
    return [
      for (var i = _days - 1; i >= 0; i--)
        () {
          final day = DateTime(today.year, today.month, today.day - i);
          final list = byDay[day] ?? const <JournalEntry>[];
          if (list.isEmpty) return _DayStat(day, 0, null, 0);
          final counts = <String, int>{};
          var sum = 0;
          for (final e in list) {
            counts[e.emotionKey] = (counts[e.emotionKey] ?? 0) + 1;
            sum += e.intensity;
          }
          final top = counts.entries
              .reduce((a, b) => b.value > a.value ? b : a)
              .key;
          return _DayStat(day, sum / list.length, top, list.length);
        }(),
    ];
  }

  String _label(_DayStat s, int index) {
    if (_days == 7) return _weekdays[s.day.weekday - 1];
    // 30 ngày: chỉ ghi ngày ở vài mốc để không chồng chữ.
    final isMark = index % 7 == 0 || index == _days - 1;
    return isMark ? '${s.day.day}/${s.day.month}' : '';
  }

  @override
  Widget build(BuildContext context) {
    final motion = MindraMotion.of(widget.lowStimulation);
    final stats = _buildStats();
    final active = stats.where((s) => s.count > 0).toList();
    final avg = active.isEmpty
        ? 0.0
        : active.map((s) => s.avgIntensity).reduce((a, b) => a + b) /
              active.length;

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
          // Wrap để chữ phóng to trên màn hẹp không tràn ngang.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text('XU HƯỚNG CẢM XÚC', style: AppTypography.kicker),
              SegmentedButton<int>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  selectedBackgroundColor: AppColors.ink,
                  selectedForegroundColor: AppColors.cream,
                ),
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 ngày')),
                  ButtonSegment(value: 30, label: Text('30 ngày')),
                ],
                selected: {_days},
                onSelectionChanged: (v) => setState(() => _days = v.first),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            active.isEmpty
                ? 'Chưa có ghi nhận nào trong $_days ngày qua.'
                : 'Có mặt ${active.length}/$_days ngày · cường độ trung bình ${avg.toStringAsFixed(1)}/5',
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: _chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final s in stats)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: _days == 7 ? 6 : 1.5,
                      ),
                      child: _buildBar(s, motion),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, s) in stats.indexed)
                Expanded(
                  child: Text(
                    _label(s, i),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
          if (_days == 7 && active.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (final s in stats)
                  Expanded(
                    child: Center(
                      child: s.emotionKey == null
                          ? const SizedBox(height: 20)
                          : MoodFace(
                              faceType: MindraEmotions.get(s.emotionKey).face,
                              size: 20,
                            ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBar(_DayStat s, MindraMotion motion) {
    final dateLabel = '${s.day.day}/${s.day.month}';
    if (s.count == 0) {
      return Semantics(
        label: '$dateLabel: chưa ghi nhận',
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      );
    }
    final emo = MindraEmotions.get(s.emotionKey);
    final palette = AppColors.facePalette[emo.face];
    final color = palette != null && palette.isNotEmpty
        ? palette[0]
        : AppColors.mint;
    final fraction = (s.avgIntensity / _maxIntensity).clamp(0.08, 1.0);
    final message =
        '$dateLabel · ${emo.vi} · cường độ ${s.avgIntensity.toStringAsFixed(1)}/5'
        '${s.count > 1 ? ' · ${s.count} lần' : ''}';

    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: message,
        child: AnimatedContainer(
          duration: motion.mediumDuration,
          curve: Curves.easeOutCubic,
          height: _chartHeight * fraction,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(_days == 7 ? 8 : 3),
            border: Border.all(
              color: (palette != null && palette.length > 1
                      ? palette[1]
                      : AppColors.ink)
                  .withValues(alpha: 0.15),
            ),
          ),
        ),
      ),
    );
  }
}
