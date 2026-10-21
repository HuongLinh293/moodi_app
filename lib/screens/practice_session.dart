import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/theme/typography.dart';
import '../models/emotion.dart';
import '../state/mindra_state.dart';
import '../widgets/mood_face.dart';

enum PracticeKind { breath, steps, write }

class BreathPattern {
  final int inhaleSec;
  final int holdSec;
  final int exhaleSec;
  final int holdAfterExhaleSec;
  final int totalCycles;

  const BreathPattern({
    required this.inhaleSec,
    required this.holdSec,
    required this.exhaleSec,
    this.holdAfterExhaleSec = 0,
    required this.totalCycles,
  });
}

class PracticePrompt {
  final String title;
  final String body;
  final String? placeholder;

  const PracticePrompt({
    required this.title,
    required this.body,
    this.placeholder,
  });
}

class PracticeSessionConfig {
  final String id;
  final String title;
  final String purpose;
  final String durationLabel;
  final Color accent;
  final PracticeKind kind;
  final BreathPattern? breath;
  final List<PracticePrompt> prompts;

  const PracticeSessionConfig({
    required this.id,
    required this.title,
    required this.purpose,
    required this.durationLabel,
    required this.accent,
    required this.kind,
    this.breath,
    this.prompts = const [],
  });
}

enum _SessionPhase { intro, running, complete, afterCheckin }

class PracticeSessionSheet extends StatefulWidget {
  final MindraState state;
  final PracticeSessionConfig config;

  const PracticeSessionSheet({
    super.key,
    required this.state,
    required this.config,
  });

  @override
  State<PracticeSessionSheet> createState() => _PracticeSessionSheetState();
}

class _PracticeSessionSheetState extends State<PracticeSessionSheet> {
  _SessionPhase _phase = _SessionPhase.intro;
  int _stepIndex = 0;
  final Map<int, TextEditingController> _writers = {};
  String? _afterEmotionKey;
  int _afterIntensity = 3;
  int? _usefulnessRating;
  int? _easeRating;
  String? _repeatPreference;
  bool _saved = false;

  MindraState get _state => widget.state;
  PracticeSessionConfig get _config => widget.config;

  int get _totalSteps {
    switch (_config.kind) {
      case PracticeKind.breath:
        return _config.breath?.totalCycles ?? 1;
      case PracticeKind.steps:
      case PracticeKind.write:
        return _config.prompts.length;
    }
  }

  double get _progress {
    if (_phase == _SessionPhase.intro) return 0;
    if (_phase == _SessionPhase.complete ||
        _phase == _SessionPhase.afterCheckin) {
      return 1;
    }
    if (_totalSteps == 0) return 0;
    return ((_stepIndex + 1) / _totalSteps).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    for (final controller in _writers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _writerFor(int index) {
    return _writers.putIfAbsent(index, TextEditingController.new);
  }

  String _collectedNote() {
    if (_config.kind != PracticeKind.write) return '';
    final parts = <String>[];
    for (var i = 0; i < _config.prompts.length; i++) {
      final text = _writers[i]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      parts.add('${_config.prompts[i].title}: $text');
    }
    return parts.join('\n');
  }

  void _start() {
    MindraMotion.of(_state.lowStimulationMode).light();
    setState(() {
      _phase = _SessionPhase.running;
      _stepIndex = 0;
    });
  }

  void _exit() {
    MindraMotion.of(_state.lowStimulationMode).selection();
    Navigator.pop(context);
  }

  void _nextStep() {
    MindraMotion.of(_state.lowStimulationMode).selection();
    if (_stepIndex >= _totalSteps - 1) {
      _finishSession();
      return;
    }
    setState(() => _stepIndex++);
  }

  void _finishSession({bool fromBreath = false}) {
    if (!fromBreath) MindraMotion.of(_state.lowStimulationMode).medium();
    setState(() => _phase = _SessionPhase.complete);
  }

  void _saveSession({
    String? afterEmotionKey,
    int? afterIntensity,
    int? usefulnessRating,
    int? easeRating,
    String? repeatPreference,
  }) {
    if (_saved && afterEmotionKey == null) return;
    _state.completeExercise(
      exerciseId: _config.id,
      note: _collectedNote(),
      afterEmotionKey: afterEmotionKey,
      afterIntensity: afterIntensity,
      usefulnessRating: usefulnessRating,
      easeRating: easeRating,
      repeatPreference: repeatPreference,
    );
    _saved = true;
  }

  void _completeWithoutAfter() {
    _saveSession();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã ghi nhận bài thực hành vừa hoàn thành.'),
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _saveAfterCheckin() {
    MindraMotion.of(_state.lowStimulationMode).medium();
    _saveSession(
      afterEmotionKey: _afterEmotionKey ?? _state.selectedEmotionKey,
      afterIntensity: _afterIntensity,
      usefulnessRating: _usefulnessRating,
      easeRating: _easeRating,
      repeatPreference: _repeatPreference,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã ghi nhận cảm xúc sau bài thực hành.'),
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.92;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _exit,
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textTertiary,
                    ),
                    Expanded(
                      child: Text(
                        _config.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        _phase == _SessionPhase.running
                            ? '${_stepIndex + 1}/$_totalSteps'
                            : _config.durationLabel,
                        style: AppTypography.kicker.copyWith(
                          color: _config.accent,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 4,
                    backgroundColor: AppColors.creamDark,
                    color: _config.accent,
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: MindraMotion.of(_state.lowStimulationMode)
                      .mediumDuration,
                  child: KeyedSubtree(
                    key: ValueKey(_phase),
                    child: switch (_phase) {
                      _SessionPhase.intro => _buildIntro(),
                      _SessionPhase.running => _buildRunning(),
                      _SessionPhase.complete => _buildComplete(),
                      _SessionPhase.afterCheckin => _buildAfterCheckin(),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _config.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _config.durationLabel.toUpperCase(),
              style: AppTypography.kicker.copyWith(
                color: AppColors.ink,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _config.title,
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 28,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _config.purpose,
            style: AppTypography.bodyMedium.copyWith(height: 1.5),
          ),
          const Spacer(),
          Text(
            'Bạn có thể dừng bất cứ lúc nào. Không cần làm hoàn hảo.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _start,
              child: const Text('Bắt đầu'),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: _exit,
              child: Text(
                'Không phải lúc này',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunning() {
    switch (_config.kind) {
      case PracticeKind.breath:
        return _BreathGuide(
          pattern: _config.breath!,
          accent: _config.accent,
          reducedMotion: _state.lowStimulationMode,
          onCycleChanged: (cycle) => setState(() => _stepIndex = cycle - 1),
          onCompleted: () => _finishSession(fromBreath: true),
        );
      case PracticeKind.steps:
        return _buildPromptStep(writable: false);
      case PracticeKind.write:
        return _buildPromptStep(writable: true);
    }
  }

  Widget _buildPromptStep({required bool writable}) {
    final prompt = _config.prompts[_stepIndex];
    final isLast = _stepIndex == _totalSteps - 1;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BƯỚC ${_stepIndex + 1}',
            style: AppTypography.kicker.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 10),
          Text(
            prompt.title,
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            prompt.body,
            style: AppTypography.bodyMedium.copyWith(height: 1.5),
          ),
          if (writable) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _writerFor(_stepIndex),
              maxLines: 4,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: prompt.placeholder ?? 'Viết vài từ, nếu muốn…',
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Có thể bỏ qua nếu chưa muốn viết.',
              style: AppTypography.caption,
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _nextStep,
              child: Text(isLast ? 'Hoàn thành bài tập' : 'Tiếp tục'),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildComplete() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _config.accent.withValues(alpha: 0.18),
            ),
            child: Icon(Icons.check_rounded, color: _config.accent, size: 28),
          ),
          const SizedBox(height: 18),
          Text(
            'Bạn đã dành ${_config.durationLabel.toLowerCase()} cho mình.',
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Không cần bài tập nào chữa khỏi cảm xúc. Chỉ cần ghi nhận bạn đã dừng lại.',
            style: AppTypography.bodyMedium.copyWith(height: 1.5),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                MindraMotion.of(_state.lowStimulationMode).light();
                _saveSession();
                setState(() {
                  _afterEmotionKey = _state.selectedEmotionKey;
                  _afterIntensity = _state.currentIntensity;
                  _phase = _SessionPhase.afterCheckin;
                });
              },
              child: const Text('Check-in lại cảm xúc'),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: _completeWithoutAfter,
              child: Text(
                'Xong',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackScale({
    required Key key,
    required String label,
    required int? value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          key: key,
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: List.generate(
            5,
            (index) => ButtonSegment<int>(
              value: index + 1,
              label: Text('${index + 1}'),
            ),
          ),
          selected: value == null ? <int>{} : <int>{value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }

  Widget _buildAfterCheckin() {
    final before = _state.selectedEmotion;
    final keys = const ['calm', 'happy', 'stressed', 'sad', 'anxious', 'tired'];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SAU BÀI TẬP',
            style: AppTypography.kicker.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 8),
          Text(
            'Bây giờ bạn đang cảm thấy thế nào?',
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Trước: ${before.vi} ${_state.currentIntensity}/5',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keys.map((key) {
              final emo = MindraEmotions.get(key);
              final selected = (_afterEmotionKey ?? before.key) == key;
              return Semantics(
                button: true,
                selected: selected,
                label: 'Cảm xúc ${emo.vi}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    MindraMotion.of(_state.lowStimulationMode).selection();
                    setState(() => _afterEmotionKey = key);
                  },
                  child: AnimatedContainer(
                    duration: MindraMotion.of(_state.lowStimulationMode)
                        .duration,
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.ink : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? AppColors.ink : AppColors.line,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MoodFace(faceType: emo.face, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          emo.vi,
                          style: AppTypography.button.copyWith(
                            fontSize: 11,
                            color: selected ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          Text(
            'MỨC ĐỘ 1–5',
            style: AppTypography.kicker.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final level = index + 1;
              final selected = _afterIntensity == level;
              return Semantics(
                button: true,
                selected: selected,
                label: 'Mức độ $level trên 5',
                child: GestureDetector(
                  onTap: () {
                    MindraMotion.of(_state.lowStimulationMode).selection();
                    setState(() => _afterIntensity = level);
                  },
                  child: AnimatedContainer(
                    duration: MindraMotion.of(_state.lowStimulationMode)
                        .duration,
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.ink : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.ink : AppColors.line,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$level',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: selected ? AppColors.yellow : AppColors.ink,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Text(
            'Một thay đổi nhỏ cũng đáng ghi nhận.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          Text(
            'PHẢN HỒI TÙY CHỌN',
            style: AppTypography.kicker.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            'Bạn có thể bỏ qua. Câu trả lời giúp chọn bài tập phù hợp hơn.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          _buildFeedbackScale(
            key: const ValueKey('exercise-usefulness'),
            label: 'Bài tập hữu ích đến đâu? (1: không, 5: rất)',
            value: _usefulnessRating,
            onChanged: (value) => setState(() => _usefulnessRating = value),
          ),
          const SizedBox(height: 12),
          _buildFeedbackScale(
            key: const ValueKey('exercise-ease'),
            label: 'Bài tập dễ thực hiện đến đâu? (1: khó, 5: dễ)',
            value: _easeRating,
            onChanged: (value) => setState(() => _easeRating = value),
          ),
          const SizedBox(height: 14),
          Text(
            'Bạn muốn dùng lại bài tập này?',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            key: const ValueKey('exercise-repeat'),
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<String>(value: 'yes', label: Text('Có')),
              ButtonSegment<String>(value: 'maybe', label: Text('Chưa chắc')),
              ButtonSegment<String>(value: 'no', label: Text('Không')),
            ],
            selected: _repeatPreference == null
                ? <String>{}
                : <String>{_repeatPreference!},
            onSelectionChanged: (selection) =>
                setState(() => _repeatPreference = selection.first),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _saveAfterCheckin,
              child: const Text('Lưu cảm xúc sau bài tập'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BreathPhase { inhale, hold, exhale, holdAfterExhale, completed }

class _BreathGuide extends StatefulWidget {
  final BreathPattern pattern;
  final Color accent;
  final bool reducedMotion;
  final ValueChanged<int> onCycleChanged;
  final VoidCallback onCompleted;

  const _BreathGuide({
    required this.pattern,
    required this.accent,
    required this.reducedMotion,
    required this.onCycleChanged,
    required this.onCompleted,
  });

  @override
  State<_BreathGuide> createState() => _BreathGuideState();
}

class _BreathGuideState extends State<_BreathGuide> {
  _BreathPhase _phase = _BreathPhase.inhale;
  int _secondsLeft = 0;
  int _cycle = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPhase(_BreathPhase.inhale);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPhase(_BreathPhase phase) {
    if (!mounted) return;
    _phase = phase;
    final duration = switch (phase) {
      _BreathPhase.inhale => widget.pattern.inhaleSec,
      _BreathPhase.hold => widget.pattern.holdSec,
      _BreathPhase.exhale => widget.pattern.exhaleSec,
      _BreathPhase.holdAfterExhale => widget.pattern.holdAfterExhaleSec,
      _BreathPhase.completed => 0,
    };
    if (phase == _BreathPhase.inhale || phase == _BreathPhase.exhale) {
      MindraMotion(widget.reducedMotion).light();
    } else if (phase != _BreathPhase.completed) {
      MindraMotion(widget.reducedMotion).selection();
    } else {
      MindraMotion(widget.reducedMotion).medium();
    }
    _secondsLeft = duration;
    _timer?.cancel();
    if (phase == _BreathPhase.completed) {
      setState(() {});
      widget.onCompleted();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        _nextPhase();
      }
    });
    setState(() {});
  }

  void _nextPhase() {
    switch (_phase) {
      case _BreathPhase.inhale:
        _startPhase(
          widget.pattern.holdSec > 0 ? _BreathPhase.hold : _BreathPhase.exhale,
        );
      case _BreathPhase.hold:
        _startPhase(_BreathPhase.exhale);
      case _BreathPhase.exhale:
        if (widget.pattern.holdAfterExhaleSec > 0) {
          _startPhase(_BreathPhase.holdAfterExhale);
        } else {
          _advanceCycle();
        }
      case _BreathPhase.holdAfterExhale:
        _advanceCycle();
      case _BreathPhase.completed:
        break;
    }
  }

  void _advanceCycle() {
    if (_cycle < widget.pattern.totalCycles) {
      _cycle++;
      widget.onCycleChanged(_cycle);
      _startPhase(_BreathPhase.inhale);
    } else {
      _startPhase(_BreathPhase.completed);
    }
  }

  String get _title => switch (_phase) {
    _BreathPhase.inhale => 'Hít vào chậm…',
    _BreathPhase.hold || _BreathPhase.holdAfterExhale => 'Giữ hơi thở…',
    _BreathPhase.exhale => 'Thở ra nhẹ nhàng…',
    _BreathPhase.completed => 'Hoàn thành',
  };

  double get _scale => switch (_phase) {
    _BreathPhase.inhale || _BreathPhase.hold => 1.35,
    _BreathPhase.exhale || _BreathPhase.holdAfterExhale => 0.88,
    _BreathPhase.completed => 1,
  };

  Color get _color => switch (_phase) {
    _BreathPhase.inhale => AppColors.mint,
    _BreathPhase.hold || _BreathPhase.holdAfterExhale => AppColors.yellow,
    _BreathPhase.exhale => AppColors.blue,
    _BreathPhase.completed => AppColors.ink,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        children: [
          const Spacer(),
          Semantics(
            liveRegion: true,
            label:
                '$_title, $_secondsLeft giây, chu kỳ $_cycle trên ${widget.pattern.totalCycles}',
            child: SizedBox(
              height: 240,
              child: Center(
                child: RepaintBoundary(
                  child: AnimatedScale(
                    scale: _scale,
                    duration: Duration(
                      seconds: _phase == _BreathPhase.inhale
                          ? widget.pattern.inhaleSec
                          : (_phase == _BreathPhase.exhale
                                ? widget.pattern.exhaleSec
                                : 1),
                    ),
                    curve: Curves.easeInOutCubic,
                    child: Container(
                      width: 168,
                      height: 168,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _color.withValues(alpha: 0.16),
                        border: Border.all(
                          color: _color.withValues(alpha: 0.55),
                          width: 3,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$_secondsLeft',
                        style: AppTypography.displayLarge.copyWith(
                          fontSize: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            _title,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chu kỳ $_cycle / ${widget.pattern.totalCycles}',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const Spacer(),
          Text(
            'Theo vòng thở. Không cần thở sâu hơn mức dễ chịu.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
