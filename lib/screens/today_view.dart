import '../widgets/entry_sync_notice.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/shadows.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../models/micro_goal.dart';
import '../state/mindra_state.dart';
import '../widgets/mood_face.dart';
import '../widgets/origami_garden.dart';
import '../widgets/week_tracker.dart';
import '../widgets/weekly_postcard_sheet.dart';
import 'paper_release_sheet.dart';

class TodayView extends StatelessWidget {
  final MindraState state;
  final VoidCallback onOpenCheckin;
  final VoidCallback onOpenJournal;
  final VoidCallback onOpenPause;
  final VoidCallback onOpenPractice;
  final VoidCallback onOpenGarden;

  const TodayView({
    super.key,
    required this.state,
    required this.onOpenCheckin,
    required this.onOpenJournal,
    required this.onOpenPause,
    required this.onOpenPractice,
    required this.onOpenGarden,
  });

  @override
  Widget build(BuildContext context) {
    final selectedKey = state.selectedEmotionKey;
    final selectedEmotion = state.selectedEmotion;
    final toneColor = selectedEmotion.tone;
    final isDarkTone = toneColor.computeLuminance() < 0.42;
    final contentTextColor = isDarkTone ? Colors.white : AppColors.ink;
    // Khung check-in: Màu nền đậm hơn, màu icon nhạt hơn cùng 1 tone màu (như Bình yên)
    final facePaletteColors =
        AppColors.facePalette[selectedEmotion.face] ??
        AppColors.facePalette['calm']!;
    final faceBackground = facePaletteColors[0];
    final faceStroke = facePaletteColors[1];
    final quickEmotionKeys = const [
      'calm',
      'happy',
      'stressed',
      'sad',
      'anxious',
      'tired',
    ];
    final suggestion = _suggestionFor(selectedKey);
    final motion = MindraMotion.of(state.lowStimulationMode);

    return SingleChildScrollView(
      physics: motion.scrollPhysics,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EntrySyncNotice(state: state),
          // 1. Intro Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getFormattedDate(), style: AppTypography.kicker),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: AppTypography.displayLarge.copyWith(
                          fontSize: 38,
                        ),
                        children: [
                          const TextSpan(text: 'Một khoảng nhỏ\n'),
                          TextSpan(
                            text: 'cho cảm xúc.',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: AppColors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Không cần phải giải thích tất cả. Hãy bắt đầu bằng điều bạn đang cảm thấy.',
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Main Check-in Zone
          AnimatedContainer(
            duration: motion.mediumDuration,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: toneColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppShadows.card,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final compactCopy =
                    constraints.maxWidth < 280 || textScale > 1.2;
                final showInlineFace =
                    constraints.maxWidth >= 240 && textScale <= 1.4;
                final faceSize = compactCopy ? 56.0 : 88.0;

                Widget buildFace() {
                  return IgnorePointer(
                    child: Transform.rotate(
                      angle: 0.08,
                      child: MoodFace(
                        faceType: selectedEmotion.face,
                        size: faceSize,
                        backgroundColor: faceBackground,
                        strokeColor: faceStroke,
                      ),
                    ),
                  );
                }

                final copyColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BÂY GIỜ BẠN ĐANG',
                      style: AppTypography.kicker.copyWith(
                        fontSize: 12,
                        color: contentTextColor.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedEmotion.promptTitle,
                      style: AppTypography.headlineLarge.copyWith(
                        fontSize: compactCopy ? 24 : 30,
                        color: contentTextColor,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedEmotion.promptSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: compactCopy ? 12 : 13,
                        color: contentTextColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showInlineFace)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: copyColumn),
                          const SizedBox(width: 12),
                          buildFace(),
                        ],
                      )
                    else ...[
                      copyColumn,
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: buildFace(),
                      ),
                    ],
                    const SizedBox(height: 16),

                    if (state.checkedInToday)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: contentTextColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Đã check-in lúc ${DateFormat('HH:mm').format(state.todayEntry!.timestamp)} · Bạn có thể ghi nhận thêm nếu cần.',
                          style: AppTypography.caption.copyWith(
                            color: contentTextColor.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: quickEmotionKeys.map((key) {
                          final emo = MindraEmotions.get(key);
                          final isSelected = key == selectedKey;
                          return Semantics(
                            button: true,
                            selected: isSelected,
                            label:
                                'Cảm xúc ${emo.vi}${isSelected ? ', đang được chọn' : ''}',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () {
                                  motion.medium();
                                  state.selectEmotion(key);
                                },
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth,
                                  ),
                                  child: AnimatedContainer(
                                    duration: motion.duration,
                                    constraints: const BoxConstraints(
                                      minHeight: 44,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDarkTone
                                                ? Colors.white.withValues(
                                                    alpha: 0.95,
                                                  )
                                                : AppColors.ink)
                                          : (isDarkTone
                                                ? AppColors.ink.withValues(
                                                    alpha: 0.18,
                                                  )
                                                : AppColors.ink.withValues(
                                                    alpha: 0.08,
                                                  )),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: isSelected
                                            ? (isDarkTone
                                                  ? Colors.white
                                                  : AppColors.ink)
                                            : (isDarkTone
                                                  ? Colors.white.withValues(
                                                      alpha: 0.45,
                                                    )
                                                  : AppColors.ink.withValues(
                                                      alpha: 0.15,
                                                    )),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        MoodFace(faceType: emo.face, size: 16),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            emo.vi,
                                            style: AppTypography.button
                                                .copyWith(
                                                  fontSize: 11,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  color: isSelected
                                                      ? (isDarkTone
                                                            ? AppColors.ink
                                                            : Colors.white)
                                                      : contentTextColor,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    if (selectedKey == 'angry' || selectedKey == 'stressed') ...[
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            motion.light();
                            PaperReleaseSheet.show(
                              context: context,
                              state: state,
                              initialEmotionKey: selectedKey,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkTone
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDarkTone
                                    ? Colors.white.withValues(alpha: 0.3)
                                    : AppColors.orange.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text('🔥', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cảm xúc đang quá tải?',
                                        style: AppTypography.caption.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isDarkTone
                                              ? Colors.white
                                              : AppColors.ink,
                                        ),
                                      ),
                                      Text(
                                        'Viết trút giận & vò nát ném đi ngay.',
                                        style: AppTypography.caption.copyWith(
                                          color: isDarkTone
                                              ? Colors.white.withValues(
                                                  alpha: 0.8,
                                                )
                                              : AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.orange,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Vò giấy ➔',
                                    style: AppTypography.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDarkTone
                                ? Colors.white.withValues(alpha: 0.16)
                                : AppColors.ink.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: TextButton.icon(
                            onPressed: onOpenPause,
                            style: TextButton.styleFrom(
                              foregroundColor: contentTextColor,
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            icon: const Icon(
                              Icons.pause_circle_outline_rounded,
                              size: 16,
                            ),
                            label: Text(
                              'Nghỉ 30 giây',
                              style: AppTypography.button.copyWith(
                                color: contentTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: isDarkTone
                                ? Colors.white.withValues(alpha: 0.16)
                                : AppColors.ink.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: TextButton.icon(
                            onPressed: () =>
                                WeeklyPostcardSheet.show(context, state),
                            style: TextButton.styleFrom(
                              foregroundColor: contentTextColor,
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            icon: const Text(
                              '💌',
                              style: TextStyle(fontSize: 14),
                            ),
                            label: Text(
                              'Bưu thiếp tuần',
                              style: AppTypography.button.copyWith(
                                color: contentTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Action buttons
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (state.checkedInToday) ...[
                              ElevatedButton(
                                onPressed: onOpenJournal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDarkTone
                                      ? Colors.white
                                      : AppColors.ink,
                                  foregroundColor: isDarkTone
                                      ? AppColors.ink
                                      : AppColors.yellow,
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Xem lại hôm nay',
                                        style: AppTypography.button.copyWith(
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 15,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: onOpenCheckin,
                                style: TextButton.styleFrom(
                                  foregroundColor: contentTextColor,
                                  minimumSize: const Size(44, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                label: Text(
                                  'Ghi nhận thêm',
                                  style: AppTypography.button.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ] else
                              ElevatedButton(
                                onPressed: onOpenCheckin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDarkTone
                                      ? Colors.white
                                      : AppColors.ink,
                                  foregroundColor: isDarkTone
                                      ? AppColors.ink
                                      : AppColors.yellow,
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Bắt đầu check-in',
                                      style: AppTypography.button.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 15,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          _buildPaperReleaseCard(context),

          // 4. Active Micro-Goals (S05 & S11-G)
          if (state.microGoals.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMicroGoalsCard(context, state),
          ],
          // 5. Week Tracker
          const SizedBox(height: 16),
          WeekTrackerCard(state: state, onOpenJournal: onOpenJournal),
          if (state.gardenVisible) ...[
            const SizedBox(height: 16),
            _buildGardenPreview(state),
          ],

          const SizedBox(height: 16),
          // Tailored practice suggestion
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.line),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 280;
                final illustration = Container(
                  width: stacked ? double.infinity : 80,
                  height: stacked ? 88 : 130,
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 10,
                        child: Transform.rotate(
                          angle: -0.4,
                          child: Container(
                            width: 35,
                            height: 65,
                            decoration: const BoxDecoration(
                              color: AppColors.orange,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(30),
                                bottomRight: Radius.circular(30),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 24,
                        child: Transform.rotate(
                          angle: 0.35,
                          child: Container(
                            width: 25,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: AppColors.mint,
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        right: 6,
                        top: 6,
                        child: Text(
                          '✦',
                          style: TextStyle(color: AppColors.blue, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.eyebrow,
                      style: AppTypography.kicker.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suggestion.title,
                      style: AppTypography.headlineMedium.copyWith(
                        fontSize: 18,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      suggestion.description,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: onOpenPractice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.ink,
                        elevation: 0,
                        minimumSize: const Size(44, 44),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('Chọn bài tập'),
                    ),
                  ],
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [copy, const SizedBox(height: 12), illustration],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    illustration,
                    const SizedBox(width: 14),
                    Expanded(child: copy),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPaperReleaseCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 280;
          final illustration = ExcludeSemantics(
            child: Container(
              width: stacked ? double.infinity : 80,
              height: stacked ? 88 : 130,
              decoration: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: SizedBox(
                  width: 76,
                  height: 88,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: -.18,
                        child: Container(
                          width: 46,
                          height: 62,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cream,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.line,
                                offset: Offset(3, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(
                              3,
                              (index) => Container(
                                width: index == 2 ? 16 : 28,
                                height: 2,
                                margin: const EdgeInsets.only(bottom: 7),
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        right: 0,
                        bottom: 3,
                        child: Icon(
                          Icons.gesture_rounded,
                          color: AppColors.blue,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VÒ GIẤY',
                style: AppTypography.kicker.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Có điều gì muốn trút ra?',
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 18,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Viết ra, vò lại rồi ném đi. Một tờ giấy, không cần giữ lại.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                key: const ValueKey('today-paper-release'),
                onPressed: () =>
                    PaperReleaseSheet.show(context: context, state: state),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.ink,
                  elevation: 0,
                  minimumSize: const Size(44, 44),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Viết ra ngay'),
              ),
            ],
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 12), illustration],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              illustration,
              const SizedBox(width: 14),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGardenPreview(MindraState state) {
    final monthKey = state.currentGardenMonthKey();
    final moments = state.momentsInMonth(monthKey);
    final previewBed = state.bedsInMonth(monthKey).first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.card,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MOODI GARDEN',
                style: AppTypography.kicker.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                moments.isEmpty
                    ? 'Những bông hoa đầu tiên đang chờ'
                    : '${moments.length} khoảnh khắc tháng này',
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Hoa vẫn ở đây khi bạn nghỉ.',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: onOpenGarden,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.ink,
                  elevation: 0,
                  minimumSize: const Size(44, 44),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Mở khu vườn'),
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              const SizedBox(height: 12),
              GardenBedView(
                state: state,
                bed: previewBed,
                compact: true,
                interactive: false,
                reducedMotion: true,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMicroGoalsCard(BuildContext context, MindraState state) {
    final motion = MindraMotion.of(state.lowStimulationMode);
    final goal = state.microGoals.first;
    final wasAttempted = goal.status == MicroGoalStatus.attempted;
    final wasSkipped = goal.status == MicroGoalStatus.skipped;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 18, color: AppColors.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'BƯỚC NHỎ CỦA BẠN',
                  style: AppTypography.kicker.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (wasAttempted || wasSkipped)
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: wasAttempted
                            ? AppColors.mint.withValues(alpha: 0.18)
                            : AppColors.creamDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        wasAttempted ? 'Đã thử' : 'Chưa thử lần này',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            goal.prompt,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          if (!wasAttempted && !wasSkipped) ...[
            const SizedBox(height: 12),
            Text(
              'Bạn đã thử bước nhỏ này chưa?',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    motion.selection();
                    state.updateMicroGoalFollowUp(
                      goal.id,
                      status: MicroGoalStatus.attempted,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size(44, 44),
                    side: const BorderSide(color: AppColors.line),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Đã thử'),
                ),
                TextButton(
                  onPressed: () {
                    motion.selection();
                    state.updateMicroGoalFollowUp(
                      goal.id,
                      status: MicroGoalStatus.skipped,
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Text('Chưa thử lần này'),
                ),
              ],
            ),
          ] else if (wasAttempted) ...[
            const SizedBox(height: 8),
            Text(
              'Cảm ơn bạn đã ghi nhận, dù kết quả thế nào.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (goal.followUpNote?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                goal.followUpNote!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.ink),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _editMicroGoalNote(context, state, goal),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: Text(
                  goal.followUpNote?.isNotEmpty == true
                      ? 'Sửa ghi chú'
                      : 'Ghi chú tùy chọn',
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Không sao. Bạn có thể quay lại bước này khi thấy phù hợp.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  state.updateMicroGoalFollowUp(
                    goal.id,
                    status: MicroGoalStatus.open,
                  );
                },
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Text('Thử lại sau'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editMicroGoalNote(
    BuildContext context,
    MindraState state,
    MicroGoal goal,
  ) async {
    var noteValue = goal.followUpNote ?? '';
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Ghi nhận bước nhỏ',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextFormField(
          initialValue: noteValue,
          autofocus: true,
          maxLines: 3,
          onChanged: (value) => noteValue = value,
          decoration: const InputDecoration(
            hintText: 'Điều gì đã xảy ra? (không bắt buộc)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, noteValue.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (note != null) {
      state.updateMicroGoalFollowUp(
        goal.id,
        status: MicroGoalStatus.attempted,
        note: note,
      );
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final daysVi = [
      'THỨ HAI',
      'THỨ BA',
      'THỨ TƯ',
      'THỨ NĂM',
      'THỨ SÁU',
      'THỨ BẢY',
      'CHỦ NHẬT',
    ];
    final weekday = daysVi[now.weekday - 1];
    final dateStr = DateFormat('dd \'THÁNG\' MM, yyyy').format(now);
    return '$weekday · $dateStr';
  }

  _PracticeSuggestion _suggestionFor(String emotionKey) {
    switch (emotionKey) {
      case 'stressed':
      case 'angry':
        return const _PracticeSuggestion(
          eyebrow: 'GỢI Ý 01 PHÚT',
          title: 'Khoảng dừng trước khi trả lời',
          description:
              'Hạ nhẹ bờ vai, thở chậm và chọn bước tiếp theo khi đã dịu hơn.',
        );
      case 'anxious':
      case 'sad':
        return const _PracticeSuggestion(
          eyebrow: 'GỢI Ý 02 PHÚT',
          title: 'Trở về với hơi thở',
          description:
              'Một nhịp thở chậm có thể giúp bạn chạm lại vào hiện tại.',
        );
      case 'tired':
      case 'numb':
        return const _PracticeSuggestion(
          eyebrow: 'GỢI Ý 03 PHÚT',
          title: 'Lắng nghe cơ thể',
          description:
              'Thử quét nhẹ cơ thể để nhận ra nơi đang cần được nghỉ ngơi.',
        );
      default:
        return const _PracticeSuggestion(
          eyebrow: 'GỢI Ý 02 PHÚT',
          title: 'Giữ lại khoảng sáng này',
          description: 'Dành một nhịp chậm để ghi nhớ điều đang giúp ngày hôm nay dịu hơn.',
        );
    }
  }
}

class _PracticeSuggestion {
  final String eyebrow;
  final String title;
  final String description;

  const _PracticeSuggestion({
    required this.eyebrow,
    required this.title,
    required this.description,
  });
}
