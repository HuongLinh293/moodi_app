import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../models/journal_entry.dart';
import '../state/mindra_state.dart';
import '../widgets/mood_face.dart';
import '../widgets/unsaved_changes_guard.dart';
import 'ai_reflection_view.dart';
import 'paper_release_sheet.dart';

class CheckinResult {
  const CheckinResult(
    this.entry, {
    this.showReflection = false,
    this.openJournal = false,
  });
  final JournalEntry entry;
  final bool showReflection;
  final bool openJournal;
}

class CheckinView extends StatefulWidget {
  final MindraState state;
  final VoidCallback onOpenJournal;
  final VoidCallback? onClose;
  final ValueChanged<CheckinResult>? onSaved;

  const CheckinView({
    super.key,
    required this.state,
    required this.onOpenJournal,
    this.onClose,
    this.onSaved,
  });

  @override
  State<CheckinView> createState() => _CheckinViewState();
}

class _TriggerOption {
  final String id;
  final String label;

  const _TriggerOption({required this.id, required this.label});
}

class _CheckinViewState extends State<CheckinView> {
  final TextEditingController _situationController = TextEditingController();
  final TextEditingController _thoughtController = TextEditingController();
  final TextEditingController _responseController = TextEditingController();
  late int _intensity;
  bool _isFullCheckin = false;
  bool _isSaving = false;
  String? _selectedTriggerId;

  final List<_TriggerOption> _triggers = const [
    _TriggerOption(id: 'work', label: 'Công việc'),
    _TriggerOption(id: 'family', label: 'Gia đình'),
    _TriggerOption(id: 'friends', label: 'Bạn bè'),
    _TriggerOption(id: 'relationship', label: 'Tình cảm'),
    _TriggerOption(id: 'self_care', label: 'Bản thân'),
    _TriggerOption(id: 'health', label: 'Sức khỏe'),
    _TriggerOption(id: 'rest', label: 'Nghỉ ngơi'),
    _TriggerOption(id: 'finance', label: 'Tài chính'),
    _TriggerOption(id: 'study', label: 'Học tập'),
  ];

  @override
  void initState() {
    super.initState();
    _intensity = widget.state.currentIntensity;
    for (final controller in [
      _situationController,
      _thoughtController,
      _responseController,
    ]) {
      controller.addListener(_draftChanged);
    }
  }

  void _draftChanged() {
    if (mounted) setState(() {});
  }

  bool get _dirty =>
      !_isSaving &&
      (_situationController.text.isNotEmpty ||
          _thoughtController.text.isNotEmpty ||
          _responseController.text.isNotEmpty ||
          _selectedTriggerId != null);

  @override
  void dispose() {
    _situationController.dispose();
    _thoughtController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _enableReflection() async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dùng gợi ý phản tư?'),
        content: const SingleChildScrollView(
          child: Text(
            'Tình huống và suy nghĩ trong ghi chép này sẽ được gửi tới máy chủ Moodi và có thể chuyển tới Google Gemini để tạo gợi ý. Đây không phải chẩn đoán. Bạn có thể chỉ lưu nhật ký và thay đổi lựa chọn trong Cài đặt bất cứ lúc nào.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Chỉ lưu nhật ký'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đồng ý dùng gợi ý'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (consent == true) {
      widget.state.setAiConsent(true);
      await _handleSave(triggerAIReflection: true);
    } else if (consent == false) {
      await _handleSave();
    }
  }

  Future<void> _handleSave({
    bool navigateToJournal = false,
    bool triggerAIReflection = false,
  }) async {
    if (_isSaving || !widget.state.hasChosenEmotion) return;
    setState(() => _isSaving = true);
    MindraMotion.of(widget.state.lowStimulationMode).medium();

    final entry = JournalEntry(
      id: 'entry-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      emotionKey: widget.state.selectedEmotionKey,
      intensity: _intensity,
      trigger: _selectedTriggerId ?? 'other',
      situation: _isFullCheckin ? _situationController.text.trim() : '',
      thought: _isFullCheckin ? _thoughtController.text.trim() : '',
      response: _isFullCheckin ? _responseController.text.trim() : '',
    );

    widget.state.addEntry(entry);
    widget.state.setIntensity(_intensity);
    await Future<void>.delayed(
      widget.state.lowStimulationMode || !mounted
          ? Duration.zero
          : const Duration(milliseconds: 180),
    );
    if (!mounted) return;

    if (widget.onSaved != null) {
      widget.onSaved!(
        CheckinResult(
          entry,
          showReflection: triggerAIReflection && widget.state.aiConsent,
          openJournal: navigateToJournal,
        ),
      );
      return;
    }

    if (triggerAIReflection && widget.state.aiConsent) {
      final navigator = Navigator.of(context);
      if (widget.onClose != null) {
        widget.onClose!();
      }
      navigator.push(
        MaterialPageRoute(
          builder: (_) => AIReflectionView(
            entry: entry,
            state: widget.state,
            onOpenJournal: widget.state.openJournal,
          ),
        ),
      );
      return;
    }

    if (triggerAIReflection && !widget.state.aiConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gợi ý phản tư đang tắt. Bạn có thể kiểm tra trạng thái ghi chép trong Nhật ký.',
            style: AppTypography.caption.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // Chỉ báo trạng thái lưu. Lời mời "Giữ trong vườn" do HomeShell hiện bằng
    // sheet sau khi đóng check-in (hoặc nút trong Nhật ký), không hỏi hai lần.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.state.entrySaveMessage(entry.id)),
        duration: const Duration(seconds: 4),
        persist: false,
      ),
    );

    if (navigateToJournal) {
      widget.onOpenJournal();
    } else if (widget.onClose != null) {
      widget.onClose!();
    } else {
      widget.onOpenJournal();
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      dirty: _dirty,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => _buildCheckin(context),
      ),
    );
  }

  Widget _buildCheckin(BuildContext context) {
    final state = widget.state;
    final selectedKey = state.selectedEmotionKey;
    final selectedEmotion = state.selectedEmotion;
    // Opened from Garden/Explore/Pause before any pick: don't assume a feeling.
    final awaitingChoice = !state.hasChosenEmotion;
    final toneColor = awaitingChoice ? AppColors.cream : selectedEmotion.tone;
    final isDarkTone = AppColors.prefersLightText(toneColor);
    final contentTextColor = isDarkTone ? Colors.white : AppColors.ink;
    final facePaletteColors =
        AppColors.facePalette[selectedEmotion.face] ??
        AppColors.facePalette['calm']!;
    final faceBackground = facePaletteColors[0];
    final faceStroke = facePaletteColors[1];
    final canSave = !_isSaving && !awaitingChoice;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: MindraMotion.of(state.lowStimulationMode).scrollPhysics,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BẮT ĐẦU CHECK-IN', style: AppTypography.kicker),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<bool>(value: false, label: Text('Nhanh')),
                ButtonSegment<bool>(value: true, label: Text('Đầy đủ')),
              ],
              selected: {_isFullCheckin},
              onSelectionChanged: (selection) {
                MindraMotion.of(state.lowStimulationMode).selection();
                setState(() => _isFullCheckin = selection.first);
              },
            ),
            const SizedBox(height: 6),
            Text(
              _isFullCheckin
                  ? 'Thêm bối cảnh nếu bạn muốn hiểu rõ hơn.'
                  : 'Chọn cảm xúc và cường độ · khoảng 30 giây',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            // 1. Hero Selected Emotion Display
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: toneColor,
                borderRadius: BorderRadius.circular(22),
                border: awaitingChoice
                    ? Border.all(color: AppColors.line)
                    : null,
              ),
              child: Row(
                children: [
                  if (!awaitingChoice) ...[
                    Transform.rotate(
                      angle: 0.08,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: faceBackground,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: MoodFace(
                          faceType: selectedEmotion.face,
                          size: 44,
                          backgroundColor: faceBackground,
                          strokeColor: faceStroke,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CẢM XÚC HIỆN TẠI',
                          style: AppTypography.kicker.copyWith(
                            fontSize: 12,
                            color: contentTextColor.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          awaitingChoice
                              ? 'Chưa chọn cảm xúc'
                              : selectedEmotion.vi,
                          style: AppTypography.headlineMedium.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: contentTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          awaitingChoice
                              ? 'Chọn cảm xúc gần nhất bên dưới. Không cần chính xác.'
                              : selectedEmotion.promptSubtitle,
                          style: AppTypography.bodySmall.copyWith(
                            color: contentTextColor.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Thay đổi cảm xúc nhanh (Quick Emotion Switcher)
            Text(
              awaitingChoice ? 'CHỌN CẢM XÚC' : 'CHỌN CẢM XÚC KHÁC NẾU CẦN',
              style: AppTypography.kicker,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: MindraMotion.of(state.lowStimulationMode)
                    .scrollPhysics,
                itemCount: MindraEmotions.all.length,
                separatorBuilder: (context, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final key = MindraEmotions.all.keys.elementAt(index);
                  final emo = MindraEmotions.all[key]!;
                  final isSelected = !awaitingChoice && key == selectedKey;

                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label:
                        'Cảm xúc ${emo.vi}${isSelected ? ', đang được chọn' : ''}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        MindraMotion.of(state.lowStimulationMode).selection();
                        state.selectEmotion(key);
                      },
                      child: AnimatedContainer(
                        duration: MindraMotion.of(state.lowStimulationMode)
                            .duration,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.ink : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppColors.ink : AppColors.line,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.ink.withValues(
                                      alpha: 0.15,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MoodFace(faceType: emo.face, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              emo.vi,
                              style: AppTypography.button.copyWith(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // 3. Cường độ cảm xúc (1 - 5)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('MỨC ĐỘ CẢM NHẬN', style: AppTypography.kicker),
                ),
                Text(
                  _getIntensityLabel(_intensity),
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.orangeText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.creamDark,
                borderRadius: BorderRadius.circular(18),
              ),
              // 5 ô chia đều một hàng: không thừa khoảng trống, không rớt dòng.
              child: Row(
                children: List.generate(5, (index) {
                  final level = index + 1;
                  final isSelected = _intensity == level;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Semantics(
                    button: true,
                    selected: isSelected,
                    label:
                        'Mức độ cảm nhận $level trên 5${isSelected ? ', đang được chọn' : ''}',
                    child: GestureDetector(
                      onTap: () {
                        MindraMotion.of(state.lowStimulationMode).selection();
                        setState(() => _intensity = level);
                      },
                      child: AnimatedContainer(
                        duration: MindraMotion.of(state.lowStimulationMode)
                            .duration,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.ink : AppColors.cream,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.ink
                                : AppColors.lineLight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$level',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? AppColors.yellow
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            if (!awaitingChoice &&
                (selectedKey == 'angry' ||
                    selectedKey == 'stressed' ||
                    (selectedKey == 'anxious' && _intensity >= 4))) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('🔥', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cảm xúc đang quá tải?',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            'Viết trút giận lên giấy, vò nát và ném đi.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (widget.onClose != null) {
                          widget.onClose!();
                        } else {
                          Navigator.maybePop(context);
                        }
                        PaperReleaseSheet.show(
                          context: context,
                          state: widget.state,
                          initialEmotionKey: selectedKey,
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: AppColors.ink,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Vò giấy ➔',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_isFullCheckin) ...[
              Text('TÁC NHÂN (TÙY CHỌN)', style: AppTypography.kicker),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _triggers.map((trigger) {
                  final isSelected = _selectedTriggerId == trigger.id;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label:
                        'Tác nhân ${trigger.label}${isSelected ? ', đang được chọn' : ''}',
                    child: GestureDetector(
                      onTap: () {
                        MindraMotion.of(state.lowStimulationMode).selection();
                        setState(() {
                          _selectedTriggerId = isSelected ? null : trigger.id;
                        });
                      },
                      child: AnimatedContainer(
                        constraints: const BoxConstraints(minHeight: 44),
                        duration: MindraMotion.of(state.lowStimulationMode)
                            .duration,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.ink : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.ink : AppColors.line,
                          ),
                        ),
                        child: Text(
                          '# ${trigger.label}',
                          style: AppTypography.caption.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _buildTextInput(
                label: 'Tình huống',
                hint: 'Điều gì đã xảy ra?',
                controller: _situationController,
                quickChips: const [
                  'Áp lực công việc',
                  'Họp căng thẳng',
                  'Bất đồng quan điểm',
                  'Một mình suy nghĩ',
                  'Kẹt xe / Mệt mỏi',
                ],
              ),
              const SizedBox(height: 16),
              _buildTextInput(
                label: 'Suy nghĩ tự động',
                hint: 'Điều gì đã lướt qua tâm trí bạn?',
                controller: _thoughtController,
                quickChips: const [
                  'Mình chưa đủ tốt',
                  'Mọi thứ quá tải',
                  'Sợ làm thất vọng',
                  'Cần được nghỉ ngơi',
                  'Mọi chuyện rồi sẽ qua',
                ],
              ),
              const SizedBox(height: 16),
              _buildTextInput(
                label: 'Phản ứng',
                hint: 'Sau đó bạn đã làm gì?',
                controller: _responseController,
                quickChips: const [
                  'Im lặng né tránh',
                  'Thở dài một lúc',
                  'Trì hoãn công việc',
                  'Tự trách mình',
                  'Đi dạo hít thở',
                ],
              ),
              const SizedBox(height: 20),
              // 5.5 Garden Planting Reward Preview
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: toneColor.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('🌱', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Khoảnh khắc gieo mầm',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sau khi lưu, bạn có thể giữ khoảnh khắc này thành ${awaitingChoice ? 'một bông hoa' : 'hoa "${selectedEmotion.vi}"'} trong Khu vườn tháng ${DateTime.now().month}.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.eco_rounded,
                      size: 20,
                      color: AppColors.mint,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else
              const SizedBox(height: 28),

            // 6. Action Buttons
            if (!_isFullCheckin) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canSave ? () => _handleSave() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isSaving ? 'Đang lưu...' : 'Lưu check-in nhanh',
                    style: AppTypography.button.copyWith(
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ] else if (widget.state.aiConsent) ...[
              // Primary AI Reflection Action
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canSave
                      ? () => _handleSave(triggerAIReflection: true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _isSaving ? 'Đang lưu...' : 'Lưu & Xem gợi ý phản tư',
                          style: AppTypography.button.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: canSave
                      ? () => _handleSave(navigateToJournal: false)
                      : null,
                  child: Text(
                    'Chỉ lưu check-in này',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canSave
                      ? () => _handleSave(navigateToJournal: false)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: AppColors.yellow,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: AppColors.yellow,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _isSaving ? 'Đang lưu...' : 'Lưu check-in đầy đủ',
                          style: AppTypography.button.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: canSave
                      ? () => _handleSave(navigateToJournal: true)
                      : null,
                  child: Text(
                    'Lưu & Xem dòng thời gian nhật ký →',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            if (_isFullCheckin && !widget.state.aiConsent)
              TextButton.icon(
                onPressed: canSave ? _enableReflection : null,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Tìm hiểu và bật gợi ý phản tư'),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    List<String> quickChips = const [],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final hasText = value.text.isNotEmpty;
            return TextField(
              key: ValueKey<String>(label),
              controller: controller,
              maxLength: 4000,
              minLines: 2,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                suffixIcon: hasText
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: 'Xoá nhanh',
                        onPressed: () => controller.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: AppColors.ink,
                    width: 1.5,
                  ),
                ),
              ),
            );
          },
        ),
        if (quickChips.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: quickChips.map((chipText) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final current = controller.text.trim();
                        if (current.isEmpty) {
                          controller.text = chipText;
                        } else if (!current.contains(chipText)) {
                          controller.text = '$current, $chipText';
                        }
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: controller.text.length),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 32),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.creamDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              chipText,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  String _getIntensityLabel(int level) {
    switch (level) {
      case 1:
        return '1/5 · Thoang thoảng';
      case 2:
        return '2/5 · Nhẹ nhàng';
      case 3:
        return '3/5 · Rõ rệt';
      case 4:
        return '4/5 · Rất mạnh';
      case 5:
        return '5/5 · Choáng ngợp';
      default:
        return '3/5 · Rõ rệt';
    }
  }
}
