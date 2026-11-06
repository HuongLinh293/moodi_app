import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/shadows.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../state/mindra_state.dart';
import 'mood_face.dart';

class WeekTrackerCard extends StatelessWidget {
  final MindraState state;
  final VoidCallback? onOpenJournal;

  const WeekTrackerCard({super.key, required this.state, this.onOpenJournal});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysVi = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

    final List<Map<String, dynamic>> days = [];
    int activeCount = 0;

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final isToday = i == 0;

      // Tìm xem có entry nào trong ngày này không
      final entry = state.entries.where((e) {
        return e.timestamp.year == date.year &&
            e.timestamp.month == date.month &&
            e.timestamp.day == date.day;
      }).firstOrNull;

      final isActive = entry != null;
      if (isActive) activeCount++;

      days.add({
        'label': daysVi[date.weekday % 7],
        'date': date.day.toString(),
        'entry': entry,
        'active': isActive,
        'today': isToday,
      });
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NHÌN LẠI NHẸ NHÀNG', style: AppTypography.kicker),
                  const SizedBox(height: 4),
                  Text(
                    'Tuần này của bạn',
                    style: AppTypography.headlineMedium.copyWith(
                      fontSize: 22,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              );
              final journalButton = TextButton(
                onPressed: onOpenJournal,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  'Xem nhật ký',
                  style: AppTypography.button.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              );

              if (constraints.maxWidth < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    Align(
                      alignment: Alignment.centerRight,
                      child: journalButton,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: title),
                  Semantics(
                    button: true,
                    label: 'Mở lịch và nhật ký',
                    child: journalButton,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((d) {
              final isToday = d['today'] as bool;
              final isActive = d['active'] as bool;
              final entry = d['entry'];
              final emotion = isActive
                  ? MindraEmotions.get(entry.emotionKey)
                  : null;

              return Expanded(
                child: Semantics(
                  button: true,
                  label: isActive
                      ? '${d['label']} ngày ${d['date']}: ${emotion!.vi}. Mở nhật ký.'
                      : '${d['label']} ngày ${d['date']}: chưa có check-in. Mở nhật ký.',
                  child: GestureDetector(
                    onTap: onOpenJournal,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        Text(
                          d['label'] as String,
                          style: AppTypography.kicker.copyWith(
                            fontSize: 10,
                            color: isToday
                                ? AppColors.orange
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder: (context, dayConstraints) {
                            final faceSize = dayConstraints.maxWidth.clamp(
                              22.0,
                              36.0,
                            );
                            return SizedBox(
                              height: faceSize,
                              child: Center(
                                child: isActive
                                    ? MoodFace(
                                        faceType: emotion!.face,
                                        size: faceSize,
                                      )
                                    : Container(
                                        width: faceSize * 0.86,
                                        height: faceSize * 0.86,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.textTertiary
                                                .withValues(alpha: 0.5),
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          d['date'] as String,
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isToday ? AppColors.orange : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 6,
              color: const Color(0xFFEBE5D8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: activeCount / 7,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              style: AppTypography.bodyMedium.copyWith(fontSize: 12),
              children: [
                TextSpan(
                  text: '$activeCount ngày ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const TextSpan(text: 'bạn đã dành một khoảng dừng cho mình.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
