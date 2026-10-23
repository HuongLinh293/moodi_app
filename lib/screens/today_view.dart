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
    final awaitingChoice = !state.hasChosenEmotion;
    final toneColor = awaitingChoice ? AppColors.cream : selectedEmotion.tone;
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
      'angry',
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
                        style: AppTypography.displayMedium.copyWith(
                          fontSize: 26,
                        ),
                        children: [
                          const TextSpan(text: 'Một khoảng nhỏ '),
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Main Check-in Zone
          AnimatedContainer(
            duration: motion.mediumDuration,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: toneColor,
              borderRadius: BorderRadius.circular(24),
              border: awaitingChoice ? Border.all(color: AppColors.line) : null,
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
                      awaitingChoice ? 'BÂY GIỜ' : 'BÂY GIỜ BẠN ĐANG',
                      style: AppTypography.kicker.copyWith(
                        fontSize: 12,
                        color: contentTextColor.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      awaitingChoice
                          ? 'Bạn đang thấy thế nào?'
                          : selectedEmotion.promptTitle,
                      style: AppTypography.headlineLarge.copyWith(
                        fontSize: compactCopy ? 24 : 30,
                        color: contentTextColor,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      awaitingChoice
                          ? 'Chạm vào cảm xúc gần nhất. Không cần chính xác.'
                          : selectedEmotion.promptSubtitle,
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
                    if (awaitingChoice)
                      copyColumn
                    else if (showInlineFace)
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

                    if (awaitingChoice)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 14,
                              color: contentTextColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Chạm để bắt đầu',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: contentTextColor.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: quickEmotionKeys.map((key) {
                          final emo = MindraEmotions.get(key);
                          final isSelected =
                              !awaitingChoice && key == selectedKey;
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

                    const SizedBox(height: 16),

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
                            ] else if (!awaitingChoice)
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

          // 3. Quick Utilities Strip (Dải tiện ích thư giãn)
          _buildQuickUtilities(context, state, suggestion, motion),

          // 4. Active Micro-Goals (S05 & S11-G)
          if (state.microGoals.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildMicroGoalsCard(context, state),
          ],
          // 5. Week Tracker
          const SizedBox(height: 18),
          WeekTrackerCard(state: state, onOpenJournal: onOpenJournal),
          if (state.gardenVisible) ...[
            const SizedBox(height: 18),
            _buildGardenPreview(state),
          ],

          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildQuickUtilities(
    BuildContext context,
    MindraState state,
    _PracticeSuggestion suggestion,
    MindraMotion motion,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 12),
          child: Text(
            'TIỆN ÍCH THƯ GIÃN',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.kicker.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: motion.scrollPhysics,
          clipBehavior: Clip.none,
          // Padding phải nhỏ hơn width card để card cuối lộ ~20px → hint scroll
          padding: const EdgeInsets.only(right: 22),
          child: Row(
            children: [
              _UtilityCard(
                key: const ValueKey('today-paper-release'),
                onTap: () {
                  motion.light();
                  PaperReleaseSheet.show(context: context, state: state);
                },
                iconWidget: const Icon(
                  Icons.gesture_rounded,
                  color: AppColors.orange,
                  size: 20,
                ),
                iconBgColor: AppColors.orange.withValues(alpha: 0.16),
                title: 'Vò giấy xả giận',
                subtitle: 'Trút bỏ & ném đi',
              ),
              const SizedBox(width: 10),
              _UtilityCard(
                key: const ValueKey('today-pause-card'),
                onTap: onOpenPause,
                iconWidget: const Icon(
                  Icons.pause_circle_outline_rounded,
                  color: AppColors.mint,
                  size: 20,
                ),
                iconBgColor: AppColors.mint.withValues(alpha: 0.18),
                title: 'Nghỉ 30 giây',
                subtitle: 'Lắng lại một nhịp',
              ),
              const SizedBox(width: 10),
              _UtilityCard(
                key: const ValueKey('today-postcard-card'),
                onTap: () => WeeklyPostcardSheet.show(context, state),
                iconWidget: const Text('💌', style: TextStyle(fontSize: 16)),
                iconBgColor: AppColors.yellow.withValues(alpha: 0.35),
                title: 'Bưu thiếp tuần',
                subtitle: 'Nhìn lại 7 ngày',
              ),
              const SizedBox(width: 10),
              _UtilityCard(
                key: const ValueKey('today-practice-card'),
                onTap: onOpenPractice,
                iconWidget: const Icon(
                  Icons.spa_outlined,
                  color: AppColors.blue,
                  size: 20,
                ),
                iconBgColor: AppColors.blue.withValues(alpha: 0.15),
                title: suggestion.title,
                subtitle: suggestion.eyebrow,
                badgeText: 'Thực hành',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGardenPreview(MindraState state) {
    final monthKey = state.currentGardenMonthKey();
    final moments = state.momentsInMonth(monthKey);
    final beds = state.bedsInMonth(monthKey);
    if (beds.isEmpty) return const SizedBox.shrink();
    final previewBed = beds.first;

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
        content: GestureDetector(
          onTap: () => FocusScope.of(dialogContext).unfocus(),
          child: TextFormField(
          initialValue: noteValue,
          autofocus: true,
          maxLines: 3,
          onChanged: (value) => noteValue = value,
          decoration: const InputDecoration(
            hintText: 'Điều gì đã xảy ra? (không bắt buộc)',
          ),
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

class _UtilityCard extends StatelessWidget {
  final VoidCallback onTap;
  final Widget iconWidget;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String? badgeText;

  const _UtilityCard({
    super.key,
    required this.onTap,
    required this.iconWidget,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 156,
            maxWidth: 195,
            minHeight: 92,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: iconWidget,
                  ),
                  const SizedBox(width: 8),
                  if (badgeText != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
